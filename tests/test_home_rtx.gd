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
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
