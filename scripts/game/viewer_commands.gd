class_name ViewerCommands
extends Node
## Chat commands that only read: "#help", "#stats" and "#top", plus remembering viewer names.
##
## Each reply has its own cooldown. The node emits [signal reply_ready] for the game to send
## to chat; it never talks to the chat itself.

signal reply_ready(text: String)

## Milliseconds between "#top" replies in chat, shared by everyone.
const TOP_COOLDOWN_MSEC: int = 30000

## Milliseconds between "#help" replies in chat, shared by everyone.
const HELP_COOLDOWN_MSEC: int = 30000

## Milliseconds before the same viewer gets another "#stats" reply.
const STATS_COOLDOWN_MSEC: int = 15000

## Commands that put a viewer on the leaderboard, so their name is remembered.
const NAMED_COMMANDS: PackedStringArray = [
	"join", "bet", "boost", "curse", "points", "fish", "color", "hat", "shop", "stats"
]

## The scores and names to read and update. Set by the owner before chat arrives.
var points: PointsStore = null
## Replies are skipped while [member GameSettings.chat_replies] is off.
var settings: GameSettings = null
## Returns the current time in milliseconds. Tests replace it to move the clock.
var clock: Callable = Time.get_ticks_msec

var _last_top_msec: int = -TOP_COOLDOWN_MSEC
var _last_help_msec: int = -HELP_COOLDOWN_MSEC
var _last_stats_msec: Dictionary[String, int] = {}


## Feed it Chat.command_received, before anything that saves points.
func remember_name(msg: ChatMessage, command: String, _args: PackedStringArray) -> void:
	if NAMED_COMMANDS.has(command):
		points.set_name(msg.user_id, ChatReplies.viewer_name(msg))


## Any chat line from a viewer who is already ranked fills in or refreshes their name, so
## entries saved before names were recorded get one as soon as the viewer says anything.
## Feed it Chat.message_received.
func backfill_name(msg: ChatMessage) -> void:
	if not points.has_entry(msg.user_id):
		return
	if points.set_name(msg.user_id, ChatReplies.viewer_name(msg)):
		points.save_to_disk()


## Feed it Chat.command_received.
func handle_command(msg: ChatMessage, command: String, args: PackedStringArray) -> void:
	match command:
		"help":
			_reply_help()
		"stats":
			_reply_stats(msg, args)
		"top":
			_reply_top()


func _reply_top() -> void:
	var now: int = int(clock.call())
	if now - _last_top_msec < TOP_COOLDOWN_MSEC:
		return
	_last_top_msec = now
	reply_ready.emit(Leaderboard.chat_text(points.top_by_points(Leaderboard.CHAT_ROWS)))


func _reply_help() -> void:
	if not settings.chat_replies:
		return
	var now: int = int(clock.call())
	if now - _last_help_msec < HELP_COOLDOWN_MSEC:
		return
	_last_help_msec = now
	reply_ready.emit(HelpText.CHAT_REPLY)


## "#stats" shows the caller's record, "#stats @name" someone else's. Each viewer has a cooldown.
func _reply_stats(msg: ChatMessage, args: PackedStringArray) -> void:
	if not settings.chat_replies:
		return
	var now: int = int(clock.call())
	if (
		_last_stats_msec.has(msg.user_id)
		and now - _last_stats_msec[msg.user_id] < STATS_COOLDOWN_MSEC
	):
		return
	_last_stats_msec[msg.user_id] = now
	var user_id: String = msg.user_id
	if not args.is_empty():
		var asked: String = " ".join(args)
		user_id = points.find_by_name(asked)
		if user_id.is_empty():
			reply_ready.emit("No stats found for that name.")
			return
	reply_ready.emit(StatsText.chat_text(points, user_id))
