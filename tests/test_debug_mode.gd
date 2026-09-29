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
