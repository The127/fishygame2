extends GutTest

var _chat: Node
var _got: Array = []


func before_each() -> void:
	_got = []
	_chat = load("res://scripts/chat/chat.gd").new()
	add_child_autofree(_chat)
	_chat.set_source(DebugChatSource.new())


func _on_command(msg: ChatMessage, command: String, args: PackedStringArray) -> void:
	_got.append([msg, command, args])


func test_debug_join_becomes_command() -> void:
	_chat.command_received.connect(_on_command)
	(_chat.source as DebugChatSource).inject("42", "Fake", "#JOIN blue")
	assert_eq(_got.size(), 1)
	assert_eq(_got[0][0].user_id, "42")
	assert_eq(_got[0][1], "join")
	assert_eq(_got[0][2], PackedStringArray(["blue"]))


func test_plain_message_is_not_command() -> void:
	_chat.command_received.connect(_on_command)
	watch_signals(_chat)
	(_chat.source as DebugChatSource).inject("42", "Fake", "hello")
	assert_signal_emitted(_chat, "message_received")
	assert_eq(_got.size(), 0)
