extends GutTest
## Home screen layout and its 3D backdrop.


func _make_home() -> HomeScreen:
	return (load("res://scenes/ui/home_screen.tscn") as PackedScene).instantiate() as HomeScreen


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
	var screen: SettingsScreen = (load(HomeScreen.SETTINGS_SCENE) as PackedScene).instantiate()
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


func test_settings_screen_fits_a_720p_window_and_groups_settings_in_tabs() -> void:
	var screen: SettingsScreen = (load(HomeScreen.SETTINGS_SCENE) as PackedScene).instantiate()
	screen.settings = GameSettings.new()
	var host := Control.new()
	host.size = Vector2(1280.0, 720.0)
	add_child_autofree(host)
	host.add_child(screen)
	await wait_process_frames(2)
	var tabs: TabContainer = screen.find_children("*", "TabContainer", true, false)[0]
	assert_gte(tabs.get_tab_count(), 5)
	var bounds := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	assert_true(bounds.encloses(tabs.get_global_rect()), "tabs stay inside the window")
	assert_lte(tabs.get_minimum_size().x, SettingsScreen.PANEL_WIDTH, "tab bar fits the panel")
	for key: String in screen._spinners:
		assert_not_null(screen._spinners[key].get_parent(), "%s is in a tab" % key)
	var reset: Button = screen.find_child("Reset", true, false)
	assert_true(bounds.encloses(reset.get_global_rect()), "buttons stay on screen")


func test_home_board_hidden_until_someone_is_ranked() -> void:
	var home: HomeScreen = _make_home()
	add_child_autofree(home)
	var store := PointsStore.new("", 100)
	home.show_leaderboard(store)
	assert_false(home._board.visible)
	store.add_win("1")
	home.show_leaderboard(store)
	assert_true(home._board.visible)


func _ranked_store() -> PointsStore:
	var store := PointsStore.new("", 100)
	store.set_balance("1", 900)
	store.set_name("1", "A Rather Long Viewer Name Here")
	store.add_win("1")
	return store


func test_leaderboard_fits_narrow_windows() -> void:
	for width: int in [700, 500, 360, 320]:
		var home: HomeScreen = _make_home()
		add_child_autofree(home)
		home.show_leaderboard(_ranked_store())
		home.set_deferred("size", Vector2(width, 900))
		await wait_process_frames(4)
		var board: Control = home._board
		assert_true(board.visible)
		var rect: Rect2 = board.get_global_rect()
		assert_gte(rect.position.x, 0.0, "board starts inside a %dpx window" % width)
		assert_lte(rect.end.x, float(width), "board ends inside a %dpx window" % width)


func test_leaderboard_keeps_full_size_when_there_is_room() -> void:
	var home: HomeScreen = _make_home()
	add_child_autofree(home)
	home.show_leaderboard(_ranked_store())
	home.set_deferred("size", Vector2(1280, 720))
	await wait_process_frames(4)
	var expected: float = 2.0 * LeaderboardPanel.COLUMN_WIDTH + LeaderboardPanel.SEPARATION
	assert_almost_eq(home._board.get_global_rect().size.x, expected, 1.0)


func test_home_screen_builds_the_3d_backdrop() -> void:
	var home: HomeScreen = _make_home()
	add_child_autofree(home)
	var scene: HomeScene3D = home.get_node("Scene3D")
	assert_not_null(scene.camera, "camera is created")
	assert_eq(scene.fish_count(), HomeScene3D.FISH_COUNT)
	assert_eq(scene.school.count, HomeScene3D.FISH_COUNT)
	assert_eq(scene.mouse_filter, Control.MOUSE_FILTER_STOP, "background takes clicks")
	assert_eq(home.get_node("Center").mouse_filter, Control.MOUSE_FILTER_IGNORE)


func _click(button: int, pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = pos
	return event


func test_clicking_the_backdrop_scares_fish() -> void:
	var home: HomeScreen = _make_home()
	add_child_autofree(home)
	home.set_deferred("size", Vector2(1280, 720))
	await wait_process_frames(2)
	var scene: HomeScene3D = home.get_node("Scene3D")
	# Park a fish right in front of the camera so a click at the centre hits it.
	scene.school.positions[0] = (
		scene.camera.position + scene.camera.project_ray_normal(scene.size / 2.0) * 6.0
	)
	var before: Vector3 = scene.school.velocities[0]
	scene._gui_input(_click(MOUSE_BUTTON_RIGHT, true, scene.size / 2.0))
	scene._gui_input(_click(MOUSE_BUTTON_LEFT, false, scene.size / 2.0))
	assert_eq(scene.school.velocities[0], before, "only a left press scares")
	scene._gui_input(_click(MOUSE_BUTTON_LEFT, true, scene.size / 2.0))
	assert_ne(scene.school.velocities[0], before, "a left click scares the fish under it")


func test_menu_controls_sit_above_the_backdrop() -> void:
	var home: HomeScreen = _make_home()
	add_child_autofree(home)
	assert_lt(home.get_node("Scene3D").get_index(), home.get_node("Center").get_index())
	for path: String in ["Center/Box/OpenLobby", "Center/Box/ClientId"]:
		var control: Control = home.get_node(path)
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_STOP, path)


func test_settings_screen_toggles_colorblind_mode() -> void:
	var screen: SettingsScreen = (load(HomeScreen.SETTINGS_SCENE) as PackedScene).instantiate()
	screen.settings = GameSettings.new()
	add_child_autofree(screen)
	assert_false(screen._colorblind.button_pressed)
	assert_true(_tab_titles(screen).has("Accessibility"))
	screen._colorblind.button_pressed = true
	assert_true(screen.settings.colorblind)
	screen.reset_pressed()
	assert_false(screen.settings.colorblind)
	assert_false(screen._colorblind.button_pressed)


func _tab_titles(screen: SettingsScreen) -> Array[String]:
	var tabs: TabContainer = screen.find_children("*", "TabContainer", true, false)[0]
	var titles: Array[String] = []
	for i: int in tabs.get_tab_count():
		titles.append(tabs.get_tab_title(i))
	return titles


func test_settings_screen_has_a_home_button_and_escape_returns_home() -> void:
	var screen: SettingsScreen = (load(HomeScreen.SETTINGS_SCENE) as PackedScene).instantiate()
	screen.settings = GameSettings.new()
	var host := Control.new()
	host.size = Vector2(1280.0, 720.0)
	add_child_autofree(host)
	host.add_child(screen)
	await wait_process_frames(2)
	var home: Button = screen.find_child("Home", true, false)
	assert_not_null(home, "a Home button sits at the top")
	assert_true(Rect2(Vector2.ZERO, host.size).encloses(home.get_global_rect()))
	var wired: bool = false
	for connection: Dictionary in home.pressed.get_connections():
		wired = wired or (connection["callable"] as Callable).get_method() == "_on_back_pressed"
	assert_true(wired, "Home leaves the settings screen")
	assert_true(screen.has_method("_unhandled_input"), "Esc is handled")
	assert_true(InputMap.has_action("ui_cancel"))


func test_title_ends_with_roman_numeral_two() -> void:
	var home: HomeScreen = _make_home()
	add_child_autofree(home)
	var title: Label = home.get_node("Center/Box/Title")
	assert_eq(title.text, "FISHY MARBLE RUN II")


func test_ten_clicks_on_fish_give_one_of_them_cat_ears() -> void:
	var home: HomeScreen = _make_home()
	add_child_autofree(home)
	var scene: HomeScene3D = home.get_node("Scene3D")
	for i: int in HomeScene3D.EARS_CLICKS - 1:
		scene.fish_clicked(4)
	assert_eq(scene.ears_fish, -1, "nine clicks are not enough")
	scene.fish_clicked(7)
	assert_eq(scene.ears_fish, 7, "the tenth click's fish gets the ears")
	var ears: int = scene._world.find_children("*", "MeshInstance3D", false, false).size()
	scene.fish_clicked(2)
	assert_eq(scene.ears_fish, 7, "only one fish gets ears")
	assert_eq(scene._world.find_children("*", "MeshInstance3D", false, false).size(), ears)


func test_ears_follow_their_fish() -> void:
	var home: HomeScreen = _make_home()
	add_child_autofree(home)
	var scene: HomeScene3D = home.get_node("Scene3D")
	for i: int in HomeScene3D.EARS_CLICKS:
		scene.fish_clicked(3)
	scene.school.positions[3] = Vector3(1.0, 2.0, 3.0)
	scene._process(0.0)
	assert_eq(scene._ears.position, scene.school.fish_transform(3).origin)


func test_only_clicks_that_hit_a_fish_are_counted() -> void:
	var home: HomeScreen = _make_home()
	add_child_autofree(home)
	home.set_deferred("size", Vector2(1280, 720))
	await wait_process_frames(2)
	var scene: HomeScene3D = home.get_node("Scene3D")
	for i: int in scene.school.count:
		scene.school.positions[i] = Vector3(500.0, 500.0, 500.0)
	scene._gui_input(_click(MOUSE_BUTTON_LEFT, true, scene.size / 2.0))
	assert_eq(scene.fish_clicks, 0, "an empty click does not count")
	scene.school.positions[0] = (
		scene.camera.position + scene.camera.project_ray_normal(scene.size / 2.0) * 6.0
	)
	scene._gui_input(_click(MOUSE_BUTTON_LEFT, true, scene.size / 2.0))
	assert_eq(scene.fish_clicks, 1)
