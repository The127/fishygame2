extends GutTest
## ViewerCommands: reply cooldowns, the chat-replies switch and name remembering.

var _commands: ViewerCommands
var _now: int = 1000000
var _replies: Array[String] = []


func before_each() -> void:
	_replies.clear()
	_now = 1000000
	_commands = ViewerCommands.new()
	_commands.points = PointsStore.new("")
	_commands.settings = GameSettings.new("")
	_commands.clock = func() -> int: return _now
	_commands.reply_ready.connect(func(text: String) -> void: _replies.append(text))
	add_child_autofree(_commands)


func _say(user_id: String, command: String, args: PackedStringArray = PackedStringArray()) -> void:
	var msg: ChatMessage = ChatMessage.create(user_id, user_id, user_id, "#" + command)
	_commands.handle_command(msg, command, args)


func test_help_cooldown_is_shared() -> void:
	_say("a", "help")
	_say("b", "help")
	assert_eq(_replies.size(), 1)
	_now += ViewerCommands.HELP_COOLDOWN_MSEC - 1
	_say("b", "help")
	assert_eq(_replies.size(), 1)
	_now += 1
	_say("b", "help")
	assert_eq(_replies.size(), 2)


func test_top_cooldown_is_shared() -> void:
	_say("a", "top")
	_say("b", "top")
	assert_eq(_replies.size(), 1)
	_now += ViewerCommands.TOP_COOLDOWN_MSEC
	_say("b", "top")
	assert_eq(_replies.size(), 2)


func test_stats_cooldown_is_per_viewer() -> void:
	_say("a", "stats")
	_say("a", "stats")
	assert_eq(_replies.size(), 1)
	_say("b", "stats")
	assert_eq(_replies.size(), 2)
	_now += ViewerCommands.STATS_COOLDOWN_MSEC
	_say("a", "stats")
	assert_eq(_replies.size(), 3)


func test_cooldowns_are_independent() -> void:
	_say("a", "help")
	_say("a", "top")
	_say("a", "stats")
	assert_eq(_replies.size(), 3)


func test_help_and_stats_are_silent_when_replies_are_off_and_do_not_start_cooldown() -> void:
	_commands.settings.chat_replies = false
	_say("a", "help")
	_say("a", "stats")
	assert_eq(_replies.size(), 0)
	_commands.settings.chat_replies = true
	_say("a", "help")
	_say("a", "stats")
	assert_eq(_replies.size(), 2)


func test_top_replies_even_when_replies_are_off() -> void:
	_commands.settings.chat_replies = false
	_say("a", "top")
	assert_eq(_replies.size(), 1)


func test_unknown_stats_name_still_costs_the_cooldown() -> void:
	_say("a", "stats", PackedStringArray(["nobody"]))
	assert_eq(_replies, ["No stats found for that name."] as Array[String])
	_say("a", "stats")
	assert_eq(_replies.size(), 1)


func test_other_commands_are_ignored() -> void:
	_say("a", "bet")
	assert_eq(_replies.size(), 0)


func test_remember_name_only_for_named_commands() -> void:
	var msg: ChatMessage = ChatMessage.create("a", "alice", "Alice", "#help")
	_commands.remember_name(msg, "help", PackedStringArray())
	assert_eq(_commands.points.find_by_name("Alice"), "")
	_commands.remember_name(msg, "join", PackedStringArray())
	assert_eq(_commands.points.find_by_name("Alice"), "a")
