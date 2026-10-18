extends GutTest
## The RTX switch on the home screen, unlocked by the fake 3D sequel.

const PATH: String = "user://test_home_rtx_surprise.cfg"


func before_each() -> void:
	ReleaseSurprise.stage = ReleaseSurprise.Stage.OFF
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func after_each() -> void:
	ReleaseSurprise.stage = ReleaseSurprise.Stage.OFF
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _make_home(played: bool, rtx: bool = false) -> HomeScreen:
	var store := ReleaseSurpriseStore.new(PATH)
	if played:
		store.set_played()
	var home: HomeScreen = (
		(load("res://scenes/ui/home_screen.tscn") as PackedScene).instantiate() as HomeScreen
	)
	home.settings = GameSettings.new()
	home.settings.rtx = rtx
	home.surprise_store = store
	add_child_autofree(home)
	return home


func test_rtx_button_sits_below_replay_and_switches_the_look() -> void:
	var home: HomeScreen = _make_home(true)
	var rtx: Button = home.get_node("CornerLayer/Corner/Rtx")
	var replay: Button = home.get_node("CornerLayer/Corner/ReplaySurprise")
	assert_true(rtx.visible)
	assert_gt(rtx.get_index(), replay.get_index(), "below the 3D replay button")
	assert_eq(rtx.text, HomeScreen.RTX_OFF_TEXT)
	assert_false(home.is_rtx_on())
	rtx.pressed.emit()
	assert_true(home.settings.rtx)
	assert_eq(rtx.text, HomeScreen.RTX_ON_TEXT)
	assert_true(home.is_rtx_on())
	var scene: HomeScene3D = home.get_node("Scene3D")
	assert_true(scene.is_rtx())
	assert_eq(scene.viewport.msaa_3d, Viewport.MSAA_4X)
	rtx.pressed.emit()
	assert_false(home.is_rtx_on())
	assert_false(scene.is_rtx())
	assert_eq(scene.viewport.msaa_3d, Viewport.MSAA_DISABLED)


func test_rtx_is_hidden_and_off_until_the_3d_sequel_played() -> void:
	var home: HomeScreen = _make_home(false, true)
	assert_false((home.get_node("CornerLayer/Corner/Rtx") as Button).visible)
	assert_false(home.is_rtx_on(), "a saved RTX setting does nothing while locked")


func test_the_unlock_survives_a_rearm() -> void:
	var store := ReleaseSurpriseStore.new(PATH)
	assert_false(store.has_played())
	ReleaseSurprise.begin(store)
	assert_true(ReleaseSurpriseStore.new(PATH).has_played())
	ReleaseSurprise.rearm(store)
	assert_false(store.is_seen())
	assert_true(ReleaseSurpriseStore.new(PATH).has_played(), "REPLAY 3D keeps RTX unlocked")


func test_settings_screen_shows_rtx_only_once_unlocked() -> void:
	for played: bool in [false, true]:
		var store := ReleaseSurpriseStore.new(PATH)
		if played:
			store.set_played()
		var screen: SettingsScreen = (
			(load(HomeScreen.SETTINGS_SCENE) as PackedScene).instantiate() as SettingsScreen
		)
		screen.settings = GameSettings.new()
		screen.surprise_store = store
		add_child_autofree(screen)
		assert_eq(screen._row_of.has(SettingsScreen.RTX_KEY), played)
		assert_eq(screen._row_of.has(SettingsScreen.RTX_INTRO_KEY), played)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_unlocking_while_the_home_screen_is_up_applies_a_saved_rtx_setting() -> void:
	var home: HomeScreen = _make_home(false, true)
	assert_false(home.is_rtx_on())
	ReleaseSurprise.begin(home.surprise_store)
	ReleaseSurprise.end()
	home._refresh_replay_button()
	var rtx: Button = home.get_node("CornerLayer/Corner/Rtx")
	assert_true(rtx.visible)
	assert_eq(rtx.text, HomeScreen.RTX_ON_TEXT, "shows the saved setting")
	assert_true(home.is_rtx_on())


func test_the_unlock_intro_plays_once_and_leaves_rtx_on() -> void:
	var home: HomeScreen = _make_home(true)
	var rtx: Button = home.get_node("CornerLayer/Corner/Rtx")
	assert_false(home.surprise_store.is_rtx_intro_seen())
	var done: Array[bool] = [false]
	var run: Callable = func() -> void:
		await home.play_rtx_intro()
		done[0] = true
	run.call()
	await wait_process_frames(2)
	assert_not_null(home.get_node_or_null("RtxIntro"), "the show is on")
	assert_false(rtx.visible, "the switch waits for the end of the show")
	assert_false(home.is_rtx_on(), "the home filter steps aside for the show's own")
	await wait_until(func() -> bool: return done[0], RtxIntro.END_AT + 2.0)
	assert_true(ReleaseSurpriseStore.new(PATH).is_rtx_intro_seen(), "marked once it is over")
	await wait_process_frames(1)
	assert_null(home.get_node_or_null("RtxIntro"), "the show cleans up")
	assert_true(rtx.visible)
	assert_true(home.settings.rtx, "RTX stays on after the show")
	assert_eq(rtx.text, HomeScreen.RTX_ON_TEXT)
	assert_true(home.is_rtx_on())


func test_replay_rtx_plays_the_show_again_and_follows_its_setting() -> void:
	var home: HomeScreen = _make_home(true)
	home.surprise_store.set_rtx_intro_seen()
	home._refresh_replay_button()
	var replay: Button = home.get_node("CornerLayer/Corner/ReplayRtx")
	var rtx: Button = home.get_node("CornerLayer/Corner/Rtx")
	var open_lobby: Button = home.get_node("Center/Box/OpenLobby")
	assert_true(replay.visible)
	assert_gt(rtx.get_index(), replay.get_index(), "the switch stays at the bottom")
	replay.pressed.emit()
	await wait_process_frames(2)
	assert_not_null(home.get_node_or_null("RtxIntro"), "the show plays again")
	assert_false(replay.visible)
	assert_true(open_lobby.disabled, "no lobby in the middle of the show")
	await wait_until(func() -> bool: return not open_lobby.disabled, RtxIntro.END_AT + 2.0)
	assert_null(home.get_node_or_null("RtxIntro"))
	assert_true(replay.visible)
	home.settings.rtx_intro = false
	home._refresh_replay_button()
	assert_false(replay.visible, "hidden while the show is turned off")


func test_replay_rtx_is_hidden_until_the_3d_sequel_played() -> void:
	var home: HomeScreen = _make_home(false)
	assert_false((home.get_node("CornerLayer/Corner/ReplayRtx") as Button).visible)


func test_the_show_is_skipped_after_the_sequel_when_turned_off() -> void:
	ReleaseSurprise.stage = ReleaseSurprise.Stage.THREE_PLAYED
	var home: HomeScreen = _make_home(true)
	home.settings.rtx_intro = false
	home.surprise_store.set_seen(true)
	await wait_process_frames(4)
	home._on_open_lobby_pressed()
	await wait_for_signal(home.surprise_ended, 20.0)
	assert_false(home.surprise_store.is_rtx_intro_seen(), "the show never played")
	assert_null(home.get_node_or_null("RtxIntro"))
