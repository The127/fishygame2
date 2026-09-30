extends GutTest
## The control panel slides in from the top: tab click, F1, auto-hide and the Home question.

var _panel: ControlPanel


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/ui/control_panel.tscn")
	_panel = scene.instantiate()
	add_child_autofree(_panel)


func _tab() -> Button:
	return _panel.get_node("Handle") as Button


func _box() -> Control:
	return _panel.get_node("Panel") as Control


func _press_f1() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_F1
	event.pressed = true
	_panel._unhandled_input(event)


func test_starts_open() -> void:
	assert_true(_panel.is_open())
	assert_true(_box().visible)


func test_tab_click_closes_and_opens_with_a_slide() -> void:
	_tab().pressed.emit()
	assert_false(_panel.is_open())
	await wait_seconds(ControlPanel.SLIDE_SECONDS + 0.15)
	assert_false(_box().visible, "fully slid out of view")
	assert_lt(_box().get_global_rect().end.y, 0.0, "above the top edge")
	_tab().pressed.emit()
	assert_true(_panel.is_open())
	assert_true(_box().visible)
	await wait_seconds(ControlPanel.SLIDE_SECONDS + 0.15)
	assert_almost_eq(_box().get_global_rect().position.y, ControlPanel.OPEN_TOP, 0.5)


func test_f1_toggles_too() -> void:
	_press_f1()
	assert_false(_panel.is_open())
	_press_f1()
	assert_true(_panel.is_open())


func test_tab_is_faint_until_hovered() -> void:
	assert_almost_eq(_tab().modulate.a, ControlPanel.TAB_IDLE_ALPHA, 0.01)
	_tab().mouse_entered.emit()
	await wait_seconds(ControlPanel.FADE_SECONDS + 0.1)
	assert_almost_eq(_tab().modulate.a, 1.0, 0.01)
	_tab().mouse_exited.emit()
	await wait_seconds(ControlPanel.FADE_SECONDS + 0.1)
	assert_almost_eq(_tab().modulate.a, ControlPanel.TAB_IDLE_ALPHA, 0.01)


func test_tab_opened_drawer_auto_hides_without_the_mouse() -> void:
	_panel.set_open(false)
	_tab().pressed.emit()
	assert_true(_panel.is_open())
	_panel.update_auto_hide(ControlPanel.AUTO_HIDE_SECONDS - 0.5, false)
	assert_true(_panel.is_open())
	_panel.update_auto_hide(1.0, false)
	assert_false(_panel.is_open())


func test_mouse_over_the_drawer_keeps_it_open() -> void:
	_panel.set_open(false)
	_tab().pressed.emit()
	_panel.update_auto_hide(ControlPanel.AUTO_HIDE_SECONDS - 0.5, false)
	_panel.update_auto_hide(1.0, true)
	_panel.update_auto_hide(ControlPanel.AUTO_HIDE_SECONDS - 0.5, false)
	assert_true(_panel.is_open(), "hovering resets the countdown")


func test_f1_opened_drawer_stays() -> void:
	_panel.set_open(false)
	_press_f1()
	_panel.update_auto_hide(ControlPanel.AUTO_HIDE_SECONDS * 3.0, false)
	assert_true(_panel.is_open())


func test_leave_question_keeps_a_tab_opened_drawer_open() -> void:
	_panel.set_open(false)
	_tab().pressed.emit()
	_panel.ask_leave()
	_panel.update_auto_hide(ControlPanel.AUTO_HIDE_SECONDS * 3.0, false)
	assert_true(_panel.is_open())


func test_leave_question_reveals_a_closed_drawer_and_stay_closes_it_again() -> void:
	_panel.set_open(false)
	_panel.ask_leave()
	assert_true(_panel.is_open())
	assert_true((_panel.get_node("Panel/Box/LeaveConfirm") as Control).visible)
	_panel.cancel_leave()
	assert_false(_panel.is_open())


func test_stay_leaves_an_open_drawer_open() -> void:
	_panel.ask_leave()
	_panel.cancel_leave()
	assert_true(_panel.is_open())
