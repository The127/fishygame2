extends GutTest
## GameSettings load, validation, reset and how the game applies them.

const PATH: String = "user://test_settings.cfg"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_defaults_match_the_game_defaults() -> void:
	var settings := GameSettings.new()
	assert_eq(settings.max_players, 20)
	assert_eq(settings.countdown_seconds, 3)
	assert_eq(settings.starting_balance, 1000)
	assert_eq(settings.boost_cost, 100)
	assert_eq(settings.curse_cost, 150)
	assert_eq(settings.max_bet, 0)
	assert_eq(settings.cheer_strength, 100)
	assert_true(settings.chat_replies)
	assert_false(settings.auto_mode)
	assert_eq(settings.auto_join_seconds, 60)
	assert_eq(settings.default_map, GameSettings.RANDOM_MAP)


func test_save_and_load_round_trip() -> void:
	var settings := GameSettings.new(PATH)
	settings.min_players = 3
	settings.max_players = 8
	settings.boost_cost = 250
	settings.default_map = "pachinko"
	settings.chat_replies = false
	settings.auto_mode = true
	settings.auto_join_seconds = 90
	assert_true(settings.save())
	var loaded := GameSettings.new(PATH)
	loaded.load_settings()
	assert_eq(loaded.min_players, 3)
	assert_eq(loaded.max_players, 8)
	assert_eq(loaded.boost_cost, 250)
	assert_eq(loaded.default_map, "pachinko")
	assert_false(loaded.chat_replies)
	assert_true(loaded.auto_mode)
	assert_eq(loaded.auto_join_seconds, 90)


func test_missing_file_keeps_defaults() -> void:
	var settings := GameSettings.new(PATH)
	settings.load_settings()
	assert_eq(settings.max_players, 20)


func test_without_a_path_nothing_is_saved() -> void:
	assert_false(GameSettings.new().save())


func test_set_number_clamps_to_the_range() -> void:
	var settings := GameSettings.new()
	settings.set_number("max_players", 500.0)
	assert_eq(settings.max_players, 20)
	settings.set_number("countdown_seconds", -4.0)
	assert_eq(settings.countdown_seconds, 0)
	settings.set_number("min_bet", 0.0)
	assert_eq(settings.min_bet, 1)


func test_set_number_clamps_huge_values_to_the_max() -> void:
	var settings := GameSettings.new()
	settings.set_number("boost_cost", 1e30)
	assert_eq(settings.boost_cost, 1000000)


func test_set_number_rejects_unknown_keys_and_non_finite_values() -> void:
	var settings := GameSettings.new()
	assert_false(settings.set_number("nope", 1.0))
	assert_false(settings.set_number("boost_cost", INF))
	assert_false(settings.set_number("boost_cost", NAN))
	assert_eq(settings.boost_cost, 100)


func test_load_clamps_out_of_range_values() -> void:
	_write("[game]\nmax_players=9999\ncountdown_seconds=-5\nboost_cost=99999999\n")
	var settings := GameSettings.new(PATH)
	settings.load_settings()
	assert_eq(settings.max_players, 20)
	assert_eq(settings.countdown_seconds, 0)
	assert_eq(settings.boost_cost, 1000000)


func test_load_ignores_values_of_the_wrong_type() -> void:
	_write('[game]\nmax_players="many"\nchat_replies=3\ndefault_map=7\nmin_bet=[1]\n')
	var settings := GameSettings.new(PATH)
	settings.load_settings()
	assert_eq(settings.max_players, 20)
	assert_true(settings.chat_replies)
	assert_eq(settings.default_map, GameSettings.RANDOM_MAP)
	assert_eq(settings.min_bet, 1)


func test_load_survives_a_corrupt_file() -> void:
	_write("this is { not a config")
	var settings := GameSettings.new(PATH)
	settings.load_settings()
	assert_eq(settings.max_players, 20)


func test_load_replaces_an_unknown_map_with_random() -> void:
	_write('[game]\ndefault_map="deleted_map"\n')
	var settings := GameSettings.new(PATH)
	settings.load_settings()
	assert_eq(settings.default_map, GameSettings.RANDOM_MAP)


func test_min_players_above_max_pushes_max_up() -> void:
	var settings := GameSettings.new()
	settings.max_players = 4
	settings.min_players = 6
	settings.sanitize()
	assert_eq(settings.max_players, 6)


func test_min_bet_above_max_bet_pushes_max_up_but_zero_stays_unlimited() -> void:
	var settings := GameSettings.new()
	settings.min_bet = 500
	settings.sanitize()
	assert_eq(settings.max_bet, 0, "no limit stays no limit")
	settings.max_bet = 100
	settings.sanitize()
	assert_eq(settings.max_bet, 500)


func test_reset_restores_defaults() -> void:
	var settings := GameSettings.new()
	settings.max_players = 5
	settings.boost_cost = 7
	settings.default_map = "zigzag"
	settings.chat_replies = false
	settings.reset_to_defaults()
	assert_eq(settings.max_players, 20)
	assert_eq(settings.boost_cost, 100)
	assert_eq(settings.default_map, GameSettings.RANDOM_MAP)
	assert_true(settings.chat_replies)


func test_every_default_is_inside_its_range() -> void:
	var settings := GameSettings.new()
	for field: Dictionary in GameSettings.FIELDS:
		var value: int = settings.get(field["key"])
		assert_between(value, int(field["min"]), int(field["max"]), str(field["key"]))


func test_play_fraction_is_the_whole_screen_by_default() -> void:
	assert_eq(GameSettings.new().play_fraction(), Rect2(0.0, 0.0, 1.0, 1.0))


func test_play_fraction_leaves_out_the_padding() -> void:
	var settings := GameSettings.new()
	settings.set_number("pad_left", 25.0)
	settings.set_number("pad_right", 5.0)
	settings.set_number("pad_top", 10.0)
	settings.set_number("pad_bottom", 20.0)
	var rect: Rect2 = settings.play_fraction()
	assert_almost_eq(rect.position.x, 0.25, 0.0001)
	assert_almost_eq(rect.position.y, 0.10, 0.0001)
	assert_almost_eq(rect.size.x, 0.70, 0.0001)
	assert_almost_eq(rect.size.y, 0.70, 0.0001)


func test_padding_is_clamped_so_a_fifth_of_the_screen_stays() -> void:
	var settings := GameSettings.new()
	settings.set_number("pad_left", 90.0)
	settings.set_number("pad_right", 90.0)
	assert_eq(settings.pad_left, 40)
	assert_almost_eq(settings.play_fraction().size.x, 0.2, 0.0001)


func test_padding_survives_save_and_load() -> void:
	var settings := GameSettings.new(PATH)
	settings.pad_left = 30
	settings.pad_bottom = 15
	assert_true(settings.save())
	var loaded := GameSettings.new(PATH)
	loaded.load_settings()
	assert_eq(loaded.pad_left, 30)
	assert_eq(loaded.pad_bottom, 15)
