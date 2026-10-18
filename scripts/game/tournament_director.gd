class_name TournamentDirector
extends Node
## Runs a [Tournament] alongside the rounds: counts what each race awards, keeps the racers for
## the next round, pays the final podium bonus and words the chat lines and standings for it.
## The game calls it at each round step and does the flow side (auto mode, rejoins) itself.

## A line to say in chat.
signal chat_line(text: String)
## A short message for the overlay.
signal notice(text: String, seconds: float)
## Standings to show: a title and rows of {"name", "points"} plus an optional "bonus". An empty
## title hides them.
signal standings_changed(title: String, rows: Array[Dictionary])

## Seconds the final standings stay up before the next lobby.
const FINAL_SECONDS: float = 15.0
## Seconds from the end of one round's race to the start of the next round's countdown: the
## podium plus the join window of the lobby.
const BREAK_SECONDS: float = 20.0

## The scores the podium bonus is paid into. Set by the owner before a tournament starts.
var points: PointsStore = null

var _tournament: Tournament = null
## Final standings of the tournament that just ended, with "bonus" on every row. Shown on its
## last podium only.
var _final: Array[Dictionary] = []
## Racers of the last round, for the next round's lobby.
var _carry_over: Array[Contestant] = []


func is_running() -> bool:
	return _tournament != null


## Starts a tournament with one round per entry of [param maps] (map ids or
## TrackCatalog.RANDOM_ID, repeats allowed). False when the round count or a map is not valid.
func start(maps: PackedStringArray) -> bool:
	if not Tournament.is_valid_round_count(maps.size()):
		return false
	for id: String in maps:
		if id != TrackCatalog.RANDOM_ID and not TrackCatalog.has_map(id):
			return false
	_tournament = Tournament.new(maps)
	_final = []
	_carry_over = []
	chat_line.emit(
		(
			"Tournament! %d rounds, points add up, the top 3 earn a bonus. Type #join to race."
			% maps.size()
		)
	)
	return true


## Ends a running tournament without a bonus.
func cancel() -> void:
	if _tournament == null:
		return
	_tournament = null
	_carry_over = []
	notice.emit("Tournament cancelled", 4.0)


## The map choice for the coming race: the round's map, or [param fallback] outside a tournament.
func map_choice(fallback: String) -> String:
	return _tournament.current_map() if _tournament != null else fallback


## "round 2/3", or "" outside a tournament.
func round_text() -> String:
	if _tournament == null:
		return ""
	return "round %d/%d" % [_tournament.round_number(), _tournament.round_count()]


## ", tournament round 2/3" for the control panel status, or "" outside a tournament.
func status_text() -> String:
	return ", tournament " + round_text() if _tournament != null else ""


## Feed it the roster at the start of each race.
func on_race_started(contestants: Array[Contestant]) -> void:
	if _tournament == null:
		return
	_carry_over = contestants
	for contestant: Contestant in contestants:
		_tournament.add_racer(contestant.user_id, contestant.display_name)


## Feed it TreasureHaul.totals() right before the haul is paid.
func add_treasure(totals: Dictionary) -> void:
	if _tournament == null:
		return
	for user_id: String in totals:
		var entry: Dictionary = totals[user_id]
		_tournament.add_points(user_id, str(entry["name"]), int(entry["points"]))


## The last round's racers, once, for the lobby of the next round. Empty outside a tournament.
func take_carry_over() -> Array[Contestant]:
	var racers: Array[Contestant] = []
	if _tournament != null:
		racers = _carry_over
	_carry_over = []
	return racers


## Says which round the fresh lobby is for once the carried-over racers are back in.
func announce_round(map_name: String) -> void:
	if _tournament == null:
		return
	chat_line.emit(
		(
			"Tournament %s on %s: last round's racers are back in, #join to race too."
			% [round_text(), map_name]
		)
	)


## Feed it every race's payouts ({user_id, name, payout, kind}) when the podium shows. Counts all
## but bets, finishes the round and, after the last one, pays the podium bonus. [param rewards]
## are the per-race placement rewards. Returns true when this ended the tournament.
func score_round(payouts: Array[Dictionary], rewards: Array[int]) -> bool:
	if _tournament == null:
		return false
	for r: Dictionary in payouts:
		# Bets and the random participation prize never decide a tournament.
		if r.get("kind", "bet") in ["bet", "trophy"]:
			continue
		_tournament.add_points(str(r["user_id"]), str(r["name"]), int(r["payout"]))
	_tournament.finish_round()
	if _tournament.is_finished():
		_finish(rewards)
		return true
	var standings: String = _tournament.standings_text()
	if not standings.is_empty():
		chat_line.emit(
			(
				"Tournament after round %d/%d: %s"
				% [_tournament.rounds_done, _tournament.round_count(), standings]
			)
		)
	return false


## Shows the standings that fit [param state]: the running tournament between races, the final
## standings on its last podium, nothing otherwise. A fresh lobby or IDLE drops the final ones.
func refresh(state: GameFlow.State) -> void:
	if state == GameFlow.State.LOBBY or state == GameFlow.State.IDLE:
		_final = []
	if not _final.is_empty() and state == GameFlow.State.PODIUM:
		standings_changed.emit("TOURNAMENT FINAL", _final)
	elif _tournament != null and state != GameFlow.State.RACING and state != GameFlow.State.IDLE:
		var title: String = (
			"TOURNAMENT ROUND %d/%d" % [_tournament.round_number(), _tournament.round_count()]
		)
		if state == GameFlow.State.PODIUM:
			title = "TOURNAMENT AFTER %d/%d" % [_tournament.rounds_done, _tournament.round_count()]
		standings_changed.emit(title, _tournament.standings())
	else:
		standings_changed.emit("", [] as Array[Dictionary])


func _finish(rewards: Array[int]) -> void:
	var podium: Array[Dictionary] = _tournament.podium_bonuses(rewards)
	var bonuses: Dictionary = {}
	var parts: PackedStringArray = []
	for row: Dictionary in podium:
		var user_id: String = str(row["user_id"])
		points.add(user_id, int(row["bonus"]))
		points.set_name(user_id, str(row["name"]))
		bonuses[user_id] = int(row["bonus"])
		parts.append("@%s +%d" % [row["name"], row["bonus"]])
	points.save_to_disk()
	_final = _tournament.standings()
	for row: Dictionary in _final:
		row["bonus"] = int(bonuses.get(row["user_id"], 0))
	_tournament = null
	_carry_over = []
	if podium.is_empty():
		chat_line.emit("Tournament over, nobody scored.")
		return
	var champion: Dictionary = podium[0]
	chat_line.emit(
		(
			"Tournament over! @%s wins with %d points. Bonus: %s"
			% [champion["name"], champion["points"], ", ".join(parts)]
		)
	)
	notice.emit("@%s wins the tournament!" % champion["name"], 6.0)
