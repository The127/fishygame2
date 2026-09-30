class_name Betting
extends Node
## Viewers bet points on who wins. Bets are taken from the balance right away and
## paid out at the podium; the game scene feeds it the round events and chat commands.
##
## Rules: one bet per viewer per round, open during the lobby and the countdown, for
## anyone in chat (joined or not). Payouts are pool-style: all stakes of the round are
## doubled and split among the bettors on the winner in proportion to their stakes. If
## nobody bet on the winner, the stakes are lost. If nobody finished, or the round is
## aborted, every bet is refunded.
## A free "#pick <fish>" costs nothing: one per viewer per round, it pays [member pick_reward]
## if the fish wins. It works alongside a bet.
## Podium finishers also earn a placement reward ([member place_rewards]), bet or not.

signal bet_placed(msg: ChatMessage, target: Contestant, amount: int)
signal bet_rejected(msg: ChatMessage, reason: String)
signal balance_reported(msg: ChatMessage, balance: int)
## Total bets or bettor count changed (also fires with empty state on a reset).
signal bets_changed(summary: String)
signal pick_placed(msg: ChatMessage, target: Contestant)
signal pick_rejected(msg: ChatMessage, reason: String)
## One entry per bet or winning pick: {user_id, name, target, amount, payout, kind}. kind is
## "bet", "pick" or "place". payout is 0 for a lost bet; amount is 0 for a pick or a placement.
signal payouts_settled(results: Array[Dictionary])

@export var points_path: String = PointsStore.DEFAULT_PATH
@export var starting_balance: int = 1000
## Smallest accepted bet.
@export var min_bet: int = 1
## Largest accepted bet. 0 means no limit.
@export var max_bet: int = 0
## Points a correct free pick pays.
@export var pick_reward: int = 50
## Points paid to 1st, 2nd, 3rd... on the podium. Missing or zero entries pay nothing.
@export var place_rewards: Array[int] = [100, 50, 25]

var points: PointsStore = null

var _open: bool = false
var _roster: Array[Contestant] = []
## user_id -> {"name": String, "target": Contestant, "amount": int}
var _bets: Dictionary = {}
## user_id -> {"name": String, "target": Contestant}
var _picks: Dictionary = {}


func _ready() -> void:
	if points == null:
		points = PointsStore.new(points_path, starting_balance)
		points.load_from_disk()
		# A refresh mid-round loses the round itself, so give open bets back.
		if points.refund_stakes() > 0 and not points.save_to_disk():
			push_warning("Could not save refunded bets")


func handle_command(msg: ChatMessage, command: String, args: PackedStringArray) -> void:
	match command:
		"bet":
			place_bet(msg, args)
		"pick":
			place_pick(msg, args)
		"points":
			balance_reported.emit(msg, points.get_balance(msg.user_id))


## Chat entry point for "#bet <name> <amount|all>".
func place_bet(msg: ChatMessage, args: PackedStringArray) -> bool:
	var target: Contestant = null
	var amount: int = 0
	var reason: String = "closed"
	if _open:
		reason = "usage"
	if _open and args.size() >= 2:
		reason = "already_bet" if _bets.has(msg.user_id) else ""
	if reason.is_empty():
		# The amount is the last word, so names containing spaces still work.
		var amount_text: String = args[args.size() - 1]
		target = _find_contestant(" ".join(args.slice(0, args.size() - 1)))
		amount = _parse_amount(amount_text, points.get_balance(msg.user_id))
		# "all" means as much as the limits allow.
		if amount_text.to_lower() == "all" and max_bet > 0:
			amount = mini(amount, max_bet)
		if target == null:
			reason = "unknown_fish"
		elif amount <= 0:
			reason = "invalid_amount"
		elif amount < min_bet:
			reason = "insufficient" if amount_text.to_lower() == "all" else "below_min"
		elif max_bet > 0 and amount > max_bet:
			reason = "above_max"
		elif not points.try_debit(msg.user_id, amount):
			reason = "insufficient"
	if not reason.is_empty():
		bet_rejected.emit(msg, reason)
		return false
	_bets[msg.user_id] = {"name": _display(msg), "target": target, "amount": amount}
	points.add_stake(msg.user_id, amount)
	points.save_to_disk()
	bet_placed.emit(msg, target, amount)
	bets_changed.emit(summary())
	return true


## Chat entry point for "#pick <name>". Free, one per viewer per round.
func place_pick(msg: ChatMessage, args: PackedStringArray) -> bool:
	var target: Contestant = null
	var reason: String = ""
	if not _open:
		reason = "closed"
	elif args.is_empty():
		reason = "usage"
	elif _picks.has(msg.user_id):
		reason = "already_picked"
	else:
		target = _find_contestant(" ".join(args))
		if target == null:
			reason = "unknown_fish"
	if not reason.is_empty():
		pick_rejected.emit(msg, reason)
		return false
	_picks[msg.user_id] = {"name": _display(msg), "target": target}
	pick_placed.emit(msg, target)
	bets_changed.emit(summary())
	return true


func add_contestant(contestant: Contestant) -> void:
	_roster.append(contestant)


func has_bet(user_id: String) -> bool:
	return _bets.has(user_id)


func has_pick(user_id: String) -> bool:
	return _picks.has(user_id)


func total_wagered() -> int:
	var total: int = 0
	for bet: Dictionary in _bets.values():
		total += int(bet["amount"])
	return total


func summary() -> String:
	var parts: PackedStringArray = []
	if not _bets.is_empty():
		parts.append("%d bets, %d points wagered" % [_bets.size(), total_wagered()])
	if not _picks.is_empty():
		parts.append("%d picks" % _picks.size())
	return ", ".join(parts)


## Feed it GameFlow.state_changed.
func on_state_changed(new_state: GameFlow.State, _old_state: GameFlow.State) -> void:
	match new_state:
		GameFlow.State.LOBBY:
			_refund_all()
			_picks.clear()
			_roster.clear()
			_open = true
			bets_changed.emit(summary())
		GameFlow.State.RACING, GameFlow.State.PODIUM:
			_open = false
		GameFlow.State.IDLE:
			_open = false
			_refund_all()
			_picks.clear()
			_roster.clear()
			bets_changed.emit(summary())


## Feed it GameFlow.podium_ready.
@warning_ignore("integer_division")
func on_podium_ready(podium: Array[Dictionary]) -> void:
	_open = false
	var winner_id: String = ""
	if not podium.is_empty() and bool(podium[0]["finished"]):
		winner_id = str(podium[0]["user_id"])
	if winner_id.is_empty():
		_refund_all()
		_picks.clear()
		return
	points.add_win(winner_id)
	points.set_name(winner_id, str(podium[0]["name"]))
	var results: Array[Dictionary] = []
	for entry: Dictionary in podium:
		var place: int = int(entry["place"])
		if not bool(entry["finished"]) or place < 1 or place > place_rewards.size():
			continue
		var reward: int = place_rewards[place - 1]
		if reward <= 0:
			continue
		var finisher: String = str(entry["user_id"])
		points.add(finisher, reward)
		points.set_name(finisher, str(entry["name"]))
		(
			results
			. append(
				{
					"user_id": finisher,
					"name": entry["name"],
					"target": entry["name"],
					"amount": 0,
					"payout": reward,
					"kind": "place",
				}
			)
		)
	# Pool-style: the whole pool, doubled, shared by the winning stakes. Rounded down.
	var pool: int = total_wagered()
	var winning_stakes: int = 0
	for bet: Dictionary in _bets.values():
		if (bet["target"] as Contestant).user_id == winner_id:
			winning_stakes += int(bet["amount"])
	for user_id: String in _bets:
		var bet: Dictionary = _bets[user_id]
		var target: Contestant = bet["target"]
		var amount: int = int(bet["amount"])
		var payout: int = 0
		if target.user_id == winner_id and winning_stakes > 0:
			payout = 2 * pool * amount / winning_stakes
		if payout > 0:
			points.add(user_id, payout)
		results.append(_result("bet", user_id, bet, amount, payout))
	if pick_reward > 0:
		for user_id: String in _picks:
			var pick: Dictionary = _picks[user_id]
			if (pick["target"] as Contestant).user_id == winner_id:
				points.add(user_id, pick_reward)
				results.append(_result("pick", user_id, pick, 0, pick_reward))
	_picks.clear()
	_clear_bets()
	points.save_to_disk()
	payouts_settled.emit(results)


func _result(
	kind: String, user_id: String, entry: Dictionary, amount: int, payout: int
) -> Dictionary:
	return {
		"user_id": user_id,
		"name": entry["name"],
		"target": (entry["target"] as Contestant).display_name,
		"amount": amount,
		"payout": payout,
		"kind": kind,
	}


func _display(msg: ChatMessage) -> String:
	return msg.display_name if msg.display_name != "" else msg.login


func _refund_all() -> void:
	if _bets.is_empty():
		return
	for user_id: String in _bets:
		points.add(user_id, int(_bets[user_id]["amount"]))
	_clear_bets()
	points.save_to_disk()


func _clear_bets() -> void:
	for user_id: String in _bets:
		points.release_stake(user_id, int(_bets[user_id]["amount"]))
	_bets.clear()


func _find_contestant(text: String) -> Contestant:
	var wanted: String = text.trim_prefix("@").to_lower()
	for contestant: Contestant in _roster:
		if contestant.display_name.to_lower() == wanted:
			return contestant
	return null


## Returns 0 when the text is not a positive whole number (or "all" with an empty balance).
func _parse_amount(text: String, balance: int) -> int:
	if text.to_lower() == "all":
		return balance
	if not text.is_valid_int() or text.length() > 15:
		return 0
	return text.to_int()
