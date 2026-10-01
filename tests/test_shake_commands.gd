extends GutTest
## "#shake" becomes a shake request carrying the viewer's name.


func _message(display_name: String, login: String) -> ChatMessage:
	var msg: ChatMessage = ChatMessage.new()
	msg.user_id = "1"
	msg.display_name = display_name
	msg.login = login
	return msg


func test_shake_emits_the_viewer() -> void:
	var commands: ShakeCommands = ShakeCommands.new()
	add_child_autofree(commands)
	watch_signals(commands)
	commands.handle_command(_message("Ann", "ann"), "shake", PackedStringArray())
	assert_signal_emitted_with_parameters(commands, "shake_requested", ["Ann"])


func test_the_login_names_a_viewer_without_a_display_name() -> void:
	var commands: ShakeCommands = ShakeCommands.new()
	add_child_autofree(commands)
	watch_signals(commands)
	commands.handle_command(_message("", "bob"), "shake", PackedStringArray())
	assert_signal_emitted_with_parameters(commands, "shake_requested", ["bob"])


func test_other_commands_are_ignored() -> void:
	var commands: ShakeCommands = ShakeCommands.new()
	add_child_autofree(commands)
	watch_signals(commands)
	commands.handle_command(_message("Ann", "ann"), "left", PackedStringArray())
	assert_signal_not_emitted(commands, "shake_requested")
