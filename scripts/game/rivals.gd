class_name Rivals
extends Node
## Rivalries: "#rival <name>" makes another viewer your rival, "#rival" alone says who it is.
##
## Every race in which both race and you finish ahead of your rival (or they do not finish)
## pays you [member reward] points. The rivalry is saved with the points and stays until you
## pick another rival. The node emits signals for the replies; it never talks to the chat.

signal rival_set(msg: ChatMessage, rival_name: String)
## rival_name is "" when the viewer has no rival.
signal rival_reported(msg: ChatMessage, rival_name: String)
signal rival_rejected(msg: ChatMessage, reason: String)

## Points for finishing ahead of your rival. 0 pays nothing.
@export var reward: int = 5

## The scores, names and rivalries. Set by the owner before chat arrives.
var points: PointsStore = null


## Feed it Chat.command_received.
func handle_command(msg: ChatMessage, command: String, args: PackedStringArray) -> void:
	if command != "rival":
		return
	if args.is_empty():
		var current: String = points.rivals.get_rival(msg.user_id)
		rival_reported.emit(msg, "" if current.is_empty() else points.get_name(current))
		return
	var rival_id: String = points.find_by_name(" ".join(args))
	if rival_id.is_empty():
		rival_rejected.emit(msg, "unknown_viewer")
		return
	if rival_id == msg.user_id:
		rival_rejected.emit(msg, "self")
		return
	points.rivals.set_rival(msg.user_id, rival_id)
	points.save_to_disk()
	rival_set.emit(msg, points.get_name(rival_id))


## Pays everyone who finished ahead of their rival. [param standings] has one entry per fish
## in the race: {user_id, name, place, finished}. Returns one payout entry per reward, shaped
## like [signal Betting.payouts_settled] entries with kind "rival" and the rival's name as
## target. The caller saves the points.
func settle(standings: Array[Dictionary]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if reward <= 0:
		return results
	var by_user: Dictionary = {}
	for entry: Dictionary in standings:
		by_user[str(entry["user_id"])] = entry
	for entry: Dictionary in standings:
		var user_id: String = str(entry["user_id"])
		var rival_id: String = points.rivals.get_rival(user_id)
		if rival_id.is_empty() or not by_user.has(rival_id) or not bool(entry["finished"]):
			continue
		var rival: Dictionary = by_user[rival_id]
		if bool(rival["finished"]) and int(rival["place"]) <= int(entry["place"]):
			continue
		points.add(user_id, reward)
		(
			results
			. append(
				{
					"user_id": user_id,
					"name": entry["name"],
					"target": rival["name"],
					"amount": 0,
					"payout": reward,
					"kind": "rival",
				}
			)
		)
	return results
