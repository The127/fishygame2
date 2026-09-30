extends GutTest


func after_each() -> void:
	DebugMode.set_enabled(OS.is_debug_build())


func test_override_round_trips() -> void:
	DebugMode.set_enabled(false)
	assert_false(DebugMode.is_enabled())
	DebugMode.set_enabled(true)
	assert_true(DebugMode.is_enabled())


func test_control_panel_hides_debug_buttons_unless_enabled() -> void:
	var scene: PackedScene = load("res://scenes/ui/control_panel.tscn")
	DebugMode.set_enabled(false)
	var off: ControlPanel = scene.instantiate()
	add_child_autofree(off)
	assert_false((off.get_node("Panel/Box/DebugButtons") as Control).visible)
	DebugMode.set_enabled(true)
	var on: ControlPanel = scene.instantiate()
	add_child_autofree(on)
	assert_true((on.get_node("Panel/Box/DebugButtons") as Control).visible)


func test_control_panel_debug_buttons_emit_signals() -> void:
	DebugMode.set_enabled(true)
	var panel: ControlPanel = (
		(load("res://scenes/ui/control_panel.tscn") as PackedScene).instantiate()
	)
	add_child_autofree(panel)
	watch_signals(panel)
	(panel.get_node("Panel/Box/DebugButtons/Duck") as Button).pressed.emit()
	(panel.get_node("Panel/Box/DebugButtons/Meow") as Button).pressed.emit()
	assert_signal_emitted(panel, "debug_duck_pressed")
	assert_signal_emitted(panel, "debug_meow_pressed")


func test_home_screen_cat_ears_button_only_in_debug() -> void:
	var scene: PackedScene = load("res://scenes/ui/home_screen.tscn")
	DebugMode.set_enabled(false)
	var off: HomeScreen = scene.instantiate()
	add_child_autofree(off)
	assert_null(off.get_node_or_null("Center/Box/DebugEars"))
	DebugMode.set_enabled(true)
	var on: HomeScreen = scene.instantiate()
	add_child_autofree(on)
	var button: Button = on.get_node("Center/Box/DebugEars")
	assert_null((on.get_node("Scene3D") as HomeScene3D).ears)
	button.pressed.emit()
	assert_not_null((on.get_node("Scene3D") as HomeScene3D).ears)
	assert_gte((on.get_node("Scene3D") as HomeScene3D).ears_fish, 0)
