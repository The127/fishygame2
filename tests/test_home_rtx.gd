extends GutTest
## The RTX switch on the home screen.


func test_rtx_button_sits_below_replay_and_switches_the_look() -> void:
	var home: HomeScreen = (
		(load("res://scenes/ui/home_screen.tscn") as PackedScene).instantiate() as HomeScreen
	)
	home.settings = GameSettings.new()
	add_child_autofree(home)
	var rtx: Button = home.get_node("CornerLayer/Corner/Rtx")
	var replay: Button = home.get_node("CornerLayer/Corner/ReplaySurprise")
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
