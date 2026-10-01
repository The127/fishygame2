extends GutTest
## "#left" and "#right" become flipper requests carrying the viewer's name.


func _message(display_name: String, login: String) -> ChatMessage:
	var msg: ChatMessage = ChatMessage.new()
	msg.user_id = "1"
	msg.display_name = display_name
	msg.login = login
	return msg


func test_left_and_right_emit_their_side() -> void:
	var commands: FlipperCommands = FlipperCommands.new()
	add_child_autofree(commands)
	watch_signals(commands)
	commands.handle_command(_message("Ann", "ann"), "left", PackedStringArray())
	commands.handle_command(_message("Ann", "ann"), "right", PackedStringArray())
	assert_signal_emit_count(commands, "flippers_requested", 2)
	assert_signal_emitted_with_parameters(commands, "flippers_requested", [-1, "Ann"], 0)
	assert_signal_emitted_with_parameters(commands, "flippers_requested", [1, "Ann"], 1)


func test_the_login_names_a_viewer_without_a_display_name() -> void:
	var commands: FlipperCommands = FlipperCommands.new()
	add_child_autofree(commands)
	watch_signals(commands)
	commands.handle_command(_message("", "bob"), "left", PackedStringArray())
	assert_signal_emitted_with_parameters(commands, "flippers_requested", [-1, "bob"])


func test_other_commands_are_ignored() -> void:
	var commands: FlipperCommands = FlipperCommands.new()
	add_child_autofree(commands)
	watch_signals(commands)
	commands.handle_command(_message("Ann", "ann"), "join", PackedStringArray())
	assert_signal_not_emitted(commands, "flippers_requested")
