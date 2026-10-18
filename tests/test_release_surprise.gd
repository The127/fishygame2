extends GutTest
## The fake "Fishy Marble Run 3" release surprise: its flag, its setting and the title drop.

const PATH: String = "user://test_release_surprise.cfg"
const SETTINGS_PATH: String = "user://test_release_surprise_settings.cfg"


func before_each() -> void:
	ReleaseSurprise.stage = ReleaseSurprise.Stage.OFF
	OnboardingStore.dismissed_this_session = true
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(SETTINGS_PATH)


func after_each() -> void:
	ReleaseSurprise.stage = ReleaseSurprise.Stage.OFF
	OnboardingStore.dismissed_this_session = false
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(SETTINGS_PATH)


func _make_home(enabled: bool = true) -> HomeScreen:
	var home: HomeScreen = (load("res://scenes/ui/home_screen.tscn") as PackedScene).instantiate()
	home.settings = GameSettings.new()
	home.settings.release_surprise = enabled
	home.surprise_store = ReleaseSurpriseStore.new(PATH)
	add_child_autofree(home)
	home.set_deferred("size", Vector2(1280.0, 720.0))
	return home


func test_store_remembers_that_the_surprise_played() -> void:
	assert_false(ReleaseSurpriseStore.new(PATH).is_seen())
	assert_true(ReleaseSurpriseStore.new(PATH).set_seen(true))
	assert_true(ReleaseSurpriseStore.new(PATH).is_seen(), "a new store reads the saved flag")
	assert_true(ReleaseSurprise.rearm(ReleaseSurpriseStore.new(PATH)))
	assert_false(ReleaseSurpriseStore.new(PATH).is_seen())


func test_starts_only_when_enabled_unseen_and_not_running() -> void:
	var store := ReleaseSurpriseStore.new(PATH)
	assert_true(ReleaseSurprise.should_start(true, store))
	assert_false(ReleaseSurprise.should_start(false, store), "the setting turns it off")
	ReleaseSurprise.begin(store)
	assert_eq(ReleaseSurprise.stage, ReleaseSurprise.Stage.THREE)
	assert_false(ReleaseSurprise.should_start(true, store), "not while the fake 3 is running")
	ReleaseSurprise.stage = ReleaseSurprise.Stage.OFF
	assert_false(ReleaseSurprise.should_start(true, store), "plays once per browser source")


func test_setting_is_on_by_default_saved_and_reset() -> void:
	var settings := GameSettings.new(SETTINGS_PATH)
	assert_true(settings.release_surprise)
	settings.release_surprise = false
	assert_true(settings.save())
	var loaded := GameSettings.new(SETTINGS_PATH)
	loaded.load_settings()
	assert_false(loaded.release_surprise)
	loaded.reset_to_defaults()
	assert_true(loaded.release_surprise)


func test_open_lobby_drops_a_3_and_a_d_on_the_title() -> void:
	var home: HomeScreen = _make_home()
	await wait_process_frames(3)
	home._on_open_lobby_pressed()
	await wait_process_frames(2)
	var drop: TitleDrop = home.get_node_or_null("TitleDrop")
	assert_not_null(drop, "the surprise plays instead of opening the lobby")
	assert_true(home.surprise_store.is_seen(), "marked as played right away")
	assert_eq(ReleaseSurprise.stage, ReleaseSurprise.Stage.THREE)
	var open_lobby: Button = home.get_node("Center/Box/OpenLobby")
	assert_true(open_lobby.disabled, "no double press while the letters fall")
	var title: Label = home.get_node("Center/Box/Title")
	assert_eq(title.visible_characters, title.text.length() - HomeScreen.TITLE_NUMBER_LENGTH)
	await wait_for_signal(drop.finished, 10.0)
	assert_true(drop.two.flattened, "the 3 squished the II")
	assert_not_null(drop.d, "a D landed too")
	assert_gt(drop.d.position.x, drop.three.position.x, "the D sits right of the 3")
	assert_almost_eq(drop.three.linear_velocity.y, 0.0, 0.5, "the 3 came to rest")
	assert_lt(drop.three.bottom_y(), drop.two.top_y() + 0.1, "the 3 sits on the pancake")
	await wait_seconds(HomeScreen.SEQUEL_REVEAL_SECONDS + 0.3)
	assert_not_null(home.get_node_or_null("Flyover"), "the 3D course was revealed")
	assert_false(open_lobby.disabled)
	assert_eq(open_lobby.text, HomeScreen.SEQUEL_PLAY_TEXT)


func test_the_fake_3_title_stays_when_coming_back_home() -> void:
	ReleaseSurprise.stage = ReleaseSurprise.Stage.THREE
	var home: HomeScreen = _make_home()
	await wait_process_frames(3)
	var drop: TitleDrop = home.get_node_or_null("TitleDrop")
	assert_not_null(drop)
	assert_true(drop.two.flattened)
	assert_not_null(drop.d)
	var open_lobby: Button = home.get_node("Center/Box/OpenLobby")
	assert_eq(open_lobby.text, HomeScreen.SEQUEL_PLAY_TEXT)


func test_letters_line_up_with_the_title() -> void:
	ReleaseSurprise.stage = ReleaseSurprise.Stage.THREE
	var home: HomeScreen = _make_home()
	await wait_process_frames(6)
	var drop: TitleDrop = home.get_node("TitleDrop")
	var rect: Rect2 = home.title_number_rect()
	# The world origin is the top-left of the "II": it must project onto that screen point.
	var screen: Vector2 = drop.camera.unproject_position(Vector3.ZERO)
	assert_almost_eq(screen.x, rect.position.x - drop.get_global_rect().position.x, 1.0)
	assert_almost_eq(screen.y, rect.position.y - drop.get_global_rect().position.y, 1.0)


func test_turning_the_setting_off_ends_the_fake_3() -> void:
	ReleaseSurprise.stage = ReleaseSurprise.Stage.THREE
	var home: HomeScreen = _make_home(false)
	await wait_process_frames(3)
	assert_null(home.get_node_or_null("TitleDrop"))
	assert_eq(ReleaseSurprise.stage, ReleaseSurprise.Stage.OFF)


func test_disabled_setting_opens_the_lobby_as_usual() -> void:
	var home: HomeScreen = _make_home()
	home.settings.release_surprise = false
	assert_false(ReleaseSurprise.should_start(home.settings.release_surprise, home.surprise_store))


func test_settings_button_arms_the_surprise_again() -> void:
	var store := ReleaseSurpriseStore.new(PATH)
	ReleaseSurprise.begin(store)
	var screen: SettingsScreen = (load(HomeScreen.SETTINGS_SCENE) as PackedScene).instantiate()
	screen.settings = GameSettings.new()
	screen.surprise_store = store
	add_child_autofree(screen)
	assert_not_null(screen.find_child("ReplaySurprise", true, false), "the button is on a page")
	screen.replay_surprise()
	assert_false(store.is_seen())
	assert_eq(ReleaseSurprise.stage, ReleaseSurprise.Stage.OFF)
	assert_true(ReleaseSurprise.should_start(true, store))


func test_the_fake_3_home_flies_over_the_3d_course() -> void:
	ReleaseSurprise.stage = ReleaseSurprise.Stage.THREE
	var home: HomeScreen = _make_home()
	await wait_process_frames(4)
	var flyover: TrackFlyover = home.get_node_or_null("Flyover")
	assert_not_null(flyover, "the course preview replaces the backdrop")
	assert_false((home.get_node("Scene3D") as Control).visible)
	assert_gt(flyover.track_3d.piece_count(), 5)
	var before: Vector3 = flyover.camera.global_position
	await wait_process_frames(10)
	assert_ne(flyover.camera.global_position, before, "the camera keeps flying")


func test_the_round_moves_the_joke_on_to_4d() -> void:
	ReleaseSurprise.stage = ReleaseSurprise.Stage.THREE
	assert_true(ReleaseSurprise.is_sequel())
	ReleaseSurprise.finish_round()
	assert_eq(ReleaseSurprise.stage, ReleaseSurprise.Stage.THREE_PLAYED)
	assert_true(ReleaseSurprise.is_sequel(), "still the fake 3 until the 4 drops")
	ReleaseSurprise.end()
	ReleaseSurprise.finish_round()
	assert_eq(ReleaseSurprise.stage, ReleaseSurprise.Stage.OFF, "no 4D without the 3 first")


func test_tesseract_has_16_corners_and_32_unit_edges() -> void:
	var corners: Array[Vector4] = Tesseract.vertices()
	var edges: Array[Vector2i] = Tesseract.edges()
	assert_eq(corners.size(), 16)
	assert_eq(edges.size(), 32)
	for edge: Vector2i in edges:
		assert_almost_eq(corners[edge.x].distance_to(corners[edge.y]), 2.0, 0.0001)
	var turned: Vector4 = Tesseract.spin(corners[5], 3.7)
	assert_almost_eq(turned.length(), corners[5].length(), 0.0001, "spinning keeps its size")
	assert_gt(
		Tesseract.project(Vector4(1, 0, 0, 1)).x,
		Tesseract.project(Vector4(1, 0, 0, -1)).x,
		"the near end in w comes out bigger"
	)


func test_play_after_the_round_drops_a_4_and_glitches_back_to_2() -> void:
	ReleaseSurprise.stage = ReleaseSurprise.Stage.THREE_PLAYED
	var home: HomeScreen = _make_home()
	home.surprise_store.set_seen(true)
	await wait_process_frames(4)
	var drop: TitleDrop = home.get_node("TitleDrop")
	var title: Label = home.get_node("Center/Box/Title")
	var tagline: Label = home.get_node("Center/Box/Tagline")
	var open_lobby: Button = home.get_node("Center/Box/OpenLobby")
	home._on_open_lobby_pressed()
	assert_true(open_lobby.disabled)
	await wait_for_signal(drop.four_finished, 10.0)
	assert_not_null(drop.four, "a 4 fell")
	assert_true(drop.three.flattened, "the 4 squished the 3")
	assert_lt(drop.four.bottom_y(), drop.three.top_y() + 0.1, "the 4 sits on the flat 3")
	await wait_seconds(HomeScreen.SEQUEL_REVEAL_SECONDS + 0.3)
	var four_d: FourDView = home.get_node_or_null("FourD")
	assert_not_null(four_d, "the 4D track shows")
	assert_eq(tagline.text, HomeScreen.FOUR_D_TAGLINE)
	assert_eq(four_d.ghost_count(), FourDView.FISH_COUNT * FourDView.GHOSTS)
	await wait_for_signal(home.surprise_ended, 15.0)
	assert_eq(ReleaseSurprise.stage, ReleaseSurprise.Stage.OFF, "back to the real game")
	await wait_process_frames(1)
	for node_name: String in ["TitleDrop", "Flyover", "FourD", "Glitch"]:
		assert_null(home.get_node_or_null(node_name), "%s is gone" % node_name)
	assert_eq(title.visible_characters, -1, "the II is back")
	assert_ne(tagline.text, HomeScreen.FOUR_D_TAGLINE)
	assert_ne(open_lobby.text, HomeScreen.SEQUEL_PLAY_TEXT)
	assert_false(open_lobby.disabled)
	assert_true((home.get_node("Scene3D") as Control).visible)
	assert_false(ReleaseSurprise.should_start(true, home.surprise_store), "plays only once")
	assert_true(
		(home.get_node("CornerLayer/Corner/ReplaySurprise") as Button).visible,
		"and can be re-armed"
	)


func test_home_button_rearms_the_surprise_once_it_has_played() -> void:
	var home: HomeScreen = _make_home()
	await wait_process_frames(2)
	var replay: Button = home.get_node("CornerLayer/Corner/ReplaySurprise")
	assert_false(replay.visible, "nothing to replay before it ran")
	home.surprise_store.set_seen(true)
	home._refresh_replay_button()
	assert_true(replay.visible)
	replay.pressed.emit()
	assert_false(home.surprise_store.is_seen())
	assert_false(replay.visible)
	assert_true(ReleaseSurprise.should_start(true, home.surprise_store))


func test_home_replay_button_hides_while_the_joke_runs_or_is_off() -> void:
	ReleaseSurpriseStore.new(PATH).set_seen(true)
	ReleaseSurprise.stage = ReleaseSurprise.Stage.THREE
	var home: HomeScreen = _make_home()
	await wait_process_frames(2)
	assert_false(
		(home.get_node("CornerLayer/Corner/ReplaySurprise") as Button).visible,
		"not during the fake 3"
	)
	var off: HomeScreen = _make_home(false)
	await wait_process_frames(2)
	assert_false(
		(off.get_node("CornerLayer/Corner/ReplaySurprise") as Button).visible,
		"not with the setting off"
	)
