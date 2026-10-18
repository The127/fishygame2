extends GutTest
## Settings screen: pages, named choices, dependent rows, search and confirmations.


func test_reset_to_defaults_asks_first() -> void:
	var screen: SettingsScreen = (load(HomeScreen.SETTINGS_SCENE) as PackedScene).instantiate()
	screen.settings = GameSettings.new()
	add_child_autofree(screen)
	screen._spinners["max_players"].value = 8.0
	var reset: Button = screen.find_child("Reset", true, false)
	reset.pressed.emit()
	assert_true(screen._reset_dialog.visible, "asks first")
	assert_eq(screen.settings.max_players, 8, "nothing reset before confirming")
	screen._reset_dialog.confirmed.emit()
	assert_eq(screen.settings.max_players, 20)


func test_named_choices_set_their_number() -> void:
	var screen: SettingsScreen = (load(HomeScreen.SETTINGS_SCENE) as PackedScene).instantiate()
	screen.settings = GameSettings.new()
	add_child_autofree(screen)
	var replay: OptionButton = screen._choices["finish_replay"]
	assert_eq(replay.selected, GameSettings.REPLAY_CLOSE)
	replay.select(GameSettings.REPLAY_ALWAYS)
	replay.item_selected.emit(GameSettings.REPLAY_ALWAYS)
	assert_eq(screen.settings.finish_replay, GameSettings.REPLAY_ALWAYS)
	var hazards: OptionButton = screen._choices["hazard_frequency"]
	assert_eq(hazards.selected, screen.settings.hazard_frequency - 1, "1 is the first name")
	hazards.item_selected.emit(4)
	assert_eq(screen.settings.hazard_frequency, 5)
	screen.reset_pressed()
	assert_eq(replay.selected, GameSettings.REPLAY_CLOSE)


func test_turning_a_switch_off_greys_out_what_depends_on_it() -> void:
	var screen: SettingsScreen = (load(HomeScreen.SETTINGS_SCENE) as PackedScene).instantiate()
	screen.settings = GameSettings.new()
	add_child_autofree(screen)
	assert_false(screen._toggles["reply_joins"].disabled)
	screen._toggles["chat_replies"].button_pressed = false
	for toggle: Dictionary in GameSettings.CHAT_TOGGLES:
		assert_true(screen._toggles[String(toggle["key"])].disabled, String(toggle["key"]))
	assert_true(screen._row_of["reply_joins"].modulate.a < 1.0, "the row is dimmed")
	assert_false(screen._spinners["auto_join_seconds"].editable, "auto mode is off by default")
	screen._toggles["auto_mode"].button_pressed = true
	assert_true(screen._spinners["auto_join_seconds"].editable)
	assert_false(screen._texts["auto_join_ignore"].editable, "auto-join is off by default")
	screen._toggles["auto_join_chatters"].button_pressed = true
	assert_true(screen._texts["auto_join_ignore"].editable)


func test_typing_the_ignore_list_saves_it() -> void:
	var screen: SettingsScreen = (load(HomeScreen.SETTINGS_SCENE) as PackedScene).instantiate()
	screen.settings = GameSettings.new()
	add_child_autofree(screen)
	var field: LineEdit = screen._texts["auto_join_ignore"]
	assert_eq(field.text, screen.settings.auto_join_ignore)
	field.text = "mybot, otherbot"
	field.text_changed.emit(field.text)
	assert_eq(screen.settings.auto_join_ignore, "mybot, otherbot")
	screen.reset_pressed()
	assert_eq(field.text, GameSettings.DEFAULT_AUTO_JOIN_IGNORE)


func test_search_shows_matching_rows_from_every_page() -> void:
	var screen: SettingsScreen = (load(HomeScreen.SETTINGS_SCENE) as PackedScene).instantiate()
	screen.settings = GameSettings.new()
	add_child_autofree(screen)
	screen.show_page(0)
	assert_false(screen._row_of["boost_cost"].is_visible_in_tree(), "other pages are hidden")
	screen._search.text = "cooldown"
	screen._search.text_changed.emit("cooldown")
	assert_true(screen._row_of["viewer_cooldown"].is_visible_in_tree())
	assert_true(screen._row_of["power_cooldown"].is_visible_in_tree())
	assert_false(screen._row_of["min_players"].is_visible_in_tree())
	screen._search.text = "zzzz"
	screen._search.text_changed.emit("zzzz")
	assert_true(screen._no_match.visible)
	screen.show_page(1)
	assert_eq(screen._search.text, "", "picking a page clears the search")
	assert_true(screen._row_of["min_bet"].is_visible_in_tree())
	assert_false(screen._no_match.visible)
