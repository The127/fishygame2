class_name Betting
extends Node
## Viewers bet points on who wins. Bets are taken from the balance right away and
## paid out at the podium; the game scene feeds it the round events and chat commands.
##
## Rules: one bet per viewer per round, open during the lobby and the countdown.
## A bet on the winner pays amount * racer count (stake included). If nobody finished,
## or the round is aborted, every bet is refunded.

signal bet_placed(msg: ChatMessage, target: Contestant, amount: int)
signal bet_rejected(msg: ChatMessage, reason: String)
signal balance_reported(msg: ChatMessage, balance: int)
## Total bets or bettor count changed (also fires with empty state on a reset).
signal bets_changed(summary: String)
## One entry per bet: {user_id, name, target, amount, payout}. payout is 0 for a lost bet.
signal payouts_settled(results: Array[Dictionary])

@export var points_path: String = "user://points.json"
@export var starting_balance: int = 1000

var points: PointsStore = null

var _open: bool = false
var _roster: Array[Contestant] = []
## user_id -> {"name": String, "target": Contestant, "amount": int}
var _bets: Dictionary = {}


func _ready() -> void:
	if points == null:
		points = PointsStore.new(points_path, starting_balance)
		points.load_from_disk()


func handle_command(msg: ChatMessage, command: String, args: PackedStringArray) -> void:
	match command:
		"bet":
			place_bet(msg, args)
		"points":
			balance_reported.emit(msg, points.get_balance(msg.user_id))


## Chat entry point for "#bet <name> <amount|all>".
func place_bet(msg: ChatMessage, args: PackedStringArray) -> bool:
	var target: Contestant = null
	var amount: int = 0
	var reason: String = "closed"
	if _open:
		reason = "usage"
	if _open and args.size() == 2:
		reason = "already_bet" if _bets.has(msg.user_id) else ""
	if reason.is_empty():
		target = _find_contestant(args[0])
		amount = _parse_amount(args[1], points.get_balance(msg.user_id))
		if target == null:
			reason = "unknown_fish"
		elif amount <= 0:
			reason = "invalid_amount"
		elif not points.try_debit(msg.user_id, amount):
			reason = "insufficient"
	if not reason.is_empty():
		bet_rejected.emit(msg, reason)
		return false
	var name_to_show: String = msg.display_name if msg.display_name != "" else msg.login
	_bets[msg.user_id] = {"name": name_to_show, "target": target, "amount": amount}
	points.save_to_disk()
	bet_placed.emit(msg, target, amount)
	bets_changed.emit(summary())
	return true


func add_contestant(contestant: Contestant) -> void:
	_roster.append(contestant)


func has_bet(user_id: String) -> bool:
	return _bets.has(user_id)


func total_wagered() -> int:
	var total: int = 0
	for bet: Dictionary in _bets.values():
		total += int(bet["amount"])
	return total


func summary() -> String:
	if _bets.is_empty():
		return ""
	return "%d bets, %d points wagered" % [_bets.size(), total_wagered()]


## Feed it GameFlow.state_changed.
func on_state_changed(new_state: GameFlow.State, _old_state: GameFlow.State) -> void:
	match new_state:
		GameFlow.State.LOBBY:
			_refund_all()
			_roster.clear()
			_open = true
			bets_changed.emit(summary())
		GameFlow.State.RACING, GameFlow.State.PODIUM:
			_open = false
		GameFlow.State.IDLE:
			_open = false
			_refund_all()
			_roster.clear()
			bets_changed.emit(summary())


## Feed it GameFlow.podium_ready.
func on_podium_ready(podium: Array[Dictionary]) -> void:
	_open = false
	var winner_id: String = ""
	if not podium.is_empty() and bool(podium[0]["finished"]):
		winner_id = str(podium[0]["user_id"])
	if winner_id.is_empty():
		_refund_all()
		return
	var odds: int = _roster.size()
	var results: Array[Dictionary] = []
	for user_id: String in _bets:
		var bet: Dictionary = _bets[user_id]
		var target: Contestant = bet["target"]
		var amount: int = int(bet["amount"])
		var payout: int = amount * odds if target.user_id == winner_id else 0
		if payout > 0:
			points.add(user_id, payout)
		(
			results
			. append(
				{
					"user_id": user_id,
					"name": bet["name"],
					"target": target.display_name,
					"amount": amount,
					"payout": payout,
				}
			)
		)
	_bets.clear()
	points.save_to_disk()
	payouts_settled.emit(results)


func _refund_all() -> void:
	if _bets.is_empty():
		return
	for user_id: String in _bets:
		points.add(user_id, int(_bets[user_id]["amount"]))
	_bets.clear()
	points.save_to_disk()


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
