extends GutTest
## Home screen layout and marble wrapping.


func _make_home() -> HomeScreen:
	return (load("res://scenes/ui/home_screen.tscn") as PackedScene).instantiate() as HomeScreen


func _make_marbles(area: Vector2) -> HomeMarbles:
	var marbles: HomeMarbles = HomeMarbles.new()
	add_child_autofree(marbles)
	marbles.size = area
	return marbles


func test_marbles_wait_for_a_size_before_spawning() -> void:
	var marbles: HomeMarbles = _make_marbles(Vector2.ZERO)
	marbles._process(0.016)
	assert_eq(marbles._marbles.size(), 0, "no spawn while the size is zero")
	marbles.size = Vector2(800, 600)
	marbles._process(0.016)
	assert_eq(marbles._marbles.size(), HomeMarbles.MARBLE_COUNT)
	var xs: Dictionary = {}
	for marble: Dictionary in marbles._marbles:
		xs[snappedf(Vector2(marble["pos"]).x, 1.0)] = true
	assert_gt(xs.size(), 1, "marbles are spread out, not clustered")


func test_wrap_keeps_positions_inside_margin() -> void:
	var marbles: HomeMarbles = _make_marbles(Vector2(800, 600))
	marbles._process(0.016)
	var m: float = HomeMarbles.WRAP_MARGIN
	var wrapped: Vector2 = marbles._wrap(Vector2(800 + m + 10.0, -m - 10.0))
	assert_almost_eq(wrapped.x, -m + 10.0, 0.001)
	assert_almost_eq(wrapped.y, 600.0 + m - 10.0, 0.001)
	var inside: Vector2 = Vector2(100, 200)
	assert_eq(marbles._wrap(inside), inside, "positions in range are unchanged")


func test_title_fits_narrow_window() -> void:
	var home: HomeScreen = _make_home()
	add_child_autofree(home)
	home.set_deferred("size", Vector2(500, 700))
	await wait_process_frames(4)
	var title: Label = home.get_node("Center/Box/Title")
	var rect: Rect2 = title.get_global_rect()
	assert_gte(rect.position.x, 0.0)
	assert_lte(rect.end.x, 500.0, "title stays inside a 500px window")
	assert_lt(title.get_theme_font_size("font_size"), HomeScreen.TITLE_FONT_SIZE)


func test_settings_button_opens_the_settings_screen() -> void:
	var home: HomeScreen = _make_home()
	add_child_autofree(home)
	var button: Button = home.get_node("Center/Box/Settings")
	assert_eq(button.text, "SETTINGS")
	assert_true(button.pressed.is_connected(home._on_settings_pressed), "button is wired")
	assert_true(load(HomeScreen.SETTINGS_SCENE) is PackedScene)


func test_settings_screen_edits_and_resets_the_settings() -> void:
	var screen: SettingsScreen = (
		(load("res://scenes/ui/settings_screen.tscn") as PackedScene).instantiate()
	)
	screen.settings = GameSettings.new()
	add_child_autofree(screen)
	var spinner: SpinBox = screen._spinners["max_players"]
	spinner.value = 8.0
	assert_eq(screen.settings.max_players, 8)
	var min_spinner: SpinBox = screen._spinners["min_players"]
	min_spinner.value = 12.0
	assert_eq(screen.settings.max_players, 12, "max follows the raised minimum")
	assert_eq(spinner.value, 12.0, "the control shows the corrected value")
	screen.reset_pressed()
	assert_eq(screen.settings.max_players, 20)
	assert_eq(spinner.value, 20.0)


func test_home_board_hidden_until_someone_is_ranked() -> void:
	var home: HomeScreen = _make_home()
	add_child_autofree(home)
	var store := PointsStore.new("", 100)
	home.show_leaderboard(store)
	assert_false(home._board.visible)
	store.add_win("1")
	home.show_leaderboard(store)
	assert_true(home._board.visible)
