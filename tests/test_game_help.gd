extends GameTestBase
## Game scene: "#help" chat command and the lobby cheat sheet.


func test_help_replies_with_commands() -> void:
	_say("0", "#help")
	assert_eq(_source.sent.size(), 1)
	assert_eq(_source.sent[0], HelpText.CHAT_REPLY)


func test_help_reply_fits_in_one_chat_message() -> void:
	assert_lt(HelpText.CHAT_REPLY.length(), 500)


func test_help_is_rate_limited_for_everyone() -> void:
	_say("0", "#help")
	_say("1", "#help")
	assert_eq(_source.sent.size(), 1)
	_game._viewer_commands._last_help_msec -= ViewerCommands.HELP_COOLDOWN_MSEC
	_say("1", "#help")
	assert_eq(_source.sent.size(), 2)


func test_help_is_silent_when_replies_are_off() -> void:
	_game.settings.chat_replies = false
	_say("0", "#help")
	assert_eq(_source.sent.size(), 0)


func test_help_does_not_share_the_top_cooldown() -> void:
	_say("0", "#top")
	_say("1", "#help")
	assert_eq(_source.sent.size(), 2)


func test_cheat_sheet_shows_in_lobby_only() -> void:
	var overlay: Overlay = _game.get_node("Overlay") as Overlay
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_true(overlay._help_panel.visible)
	_join(2)
	_flow.start_race()
	assert_false(overlay._help_panel.visible)


func _cheat_sheet_text() -> String:
	var overlay: Overlay = _game.get_node("Overlay") as Overlay
	var texts: PackedStringArray = []
	for label: Label in overlay._help_panel.find_children("*", "Label", true, false):
		texts.append(label.text)
	return " ".join(texts)


func test_cheat_sheet_lists_the_commands_of_the_loaded_map_only() -> void:
	_panel.map_selected.emit("sushi")
	assert_string_contains(_cheat_sheet_text(), "#chop")
	assert_string_contains(_cheat_sheet_text(), "SUSHI BAR")
	assert_false(_cheat_sheet_text().contains("#roll"))
	_panel.map_selected.emit("zigzag")
	await wait_process_frames(1)
	assert_false(_cheat_sheet_text().contains("#chop"), "the old map's rows are gone")
	assert_string_contains(_cheat_sheet_text(), "#join")
