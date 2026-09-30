extends GutTest
## Power button feel: armed look, activate burst, ready pulse, drawer fade, cursor per power.

var _panel: ControlPanel


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/ui/control_panel.tscn")
	_panel = scene.instantiate()
	add_child_autofree(_panel)


func _power(index: int) -> PowerButton:
	return _panel.get_node("Panel/Box/PowerButtons").get_child(index) as PowerButton


func test_buttons_know_their_power() -> void:
	assert_eq(_power(0).kind, StreamerPowers.Kind.ROD)
	assert_eq(_power(1).kind, StreamerPowers.Kind.NET)
	assert_eq(_power(2).kind, StreamerPowers.Kind.BLAST)


func test_each_power_has_its_own_color() -> void:
	var seen: Dictionary = {}
	for kind: int in 3:
		seen[UiStyle.power_color(kind)] = true
	assert_eq(seen.size(), 3)


func test_armed_button_spawns_bubbles() -> void:
	_panel.set_armed_power(1)
	assert_true(_power(1).is_armed())
	assert_false(_power(0).is_armed())
	var button: PowerButton = _power(1)
	await wait_seconds(PowerButton.ARMED_BUBBLE_EVERY * 2.0)
	assert_gt(button._bubbles.count(), 0)


func test_activate_bursts_and_settles() -> void:
	var button: PowerButton = _power(2)
	button.play_activate()
	assert_gt(button._bubbles.count(), 0, "a burst of bubbles")
	assert_gt(button.scale.x, 1.0, "starts with a punch")
	await wait_seconds(0.85)
	assert_almost_eq(button.scale.x, 1.0, 0.01)
	assert_eq(button._bubbles.count(), 0, "bubbles are gone")


func test_panel_routes_activation_to_the_button() -> void:
	_panel.play_power_activate(0)
	assert_gt(_power(0)._bubbles.count(), 0)
	assert_eq(_power(1)._bubbles.count(), 0)
	_panel.play_power_activate(-1)
	_panel.play_power_activate(9)


func test_ready_pulses_when_the_cooldown_ends() -> void:
	var button: PowerButton = _power(0)
	_panel.set_power_cooldown(4.0, 8.0)
	assert_eq(button._bubbles.count(), 0)
	_panel.set_power_cooldown(0.0, 8.0)
	assert_gt(button._bubbles.count(), 0)
	assert_true(button._ring_age >= 0.0)


func test_cooling_clears_the_hover_swell() -> void:
	var button: PowerButton = _power(0)
	button.mouse_entered.emit()
	_panel.set_power_cooldown(4.0, 8.0)
	await wait_seconds(PowerButton.SCALE_SECONDS + 0.1)
	assert_almost_eq(button.scale.x, 1.0, 0.01)


func test_bubble_burst_is_capped_and_expires() -> void:
	var bubbles: BubbleBurst = BubbleBurst.new()
	bubbles.burst(Vector2.ZERO, BubbleBurst.MAX_BUBBLES * 2, 100.0, 0.5, 2.0)
	assert_eq(bubbles.count(), BubbleBurst.MAX_BUBBLES)
	bubbles.step(0.6)
	assert_eq(bubbles.count(), 0)


func test_drawer_overshoot_is_damped() -> void:
	assert_eq(ControlPanel.slide_travel(0.5), 0.5)
	assert_almost_eq(
		ControlPanel.slide_travel(1.1), 1.0 + 0.1 * ControlPanel.OVERSHOOT_SCALE, 0.001
	)


func test_drawer_contents_fade_with_the_slide() -> void:
	assert_eq(ControlPanel.slide_alpha(0.0), 0.0)
	assert_eq(ControlPanel.slide_alpha(1.0), 1.0)
	assert_between(ControlPanel.slide_alpha(0.3), 0.01, 0.99)


func test_drawer_fades_out_and_back_in() -> void:
	var box: Control = _panel.get_node("Panel") as Control
	_panel.set_open(false)
	await wait_seconds(ControlPanel.SLIDE_SECONDS + 0.15)
	assert_eq(box.modulate.a, 0.0)
	_panel.set_open(true)
	await wait_seconds(ControlPanel.OPEN_SECONDS + 0.15)
	assert_eq(box.modulate.a, 1.0)


func test_cursor_shows_the_armed_power() -> void:
	var cursor: PowerCursor = PowerCursor.new()
	add_child_autofree(cursor)
	cursor.arm(StreamerPowers.Kind.NET, 80.0)
	assert_true(cursor.visible)
	assert_eq(cursor.kind, StreamerPowers.Kind.NET)
	assert_eq(cursor.radius, 80.0)
	cursor.arm(-1, 0.0)
	assert_false(cursor.visible)
	assert_eq(cursor.kind, -1)


func test_scale_returns_to_normal_when_unarmed_away_from_the_mouse() -> void:
	var button: PowerButton = _power(0)
	button.mouse_entered.emit()
	_panel.set_armed_power(0)
	button.mouse_exited.emit()
	_panel.set_armed_power(-1)
	await wait_seconds(PowerButton.SCALE_SECONDS + 0.1)
	assert_almost_eq(button.scale.x, 1.0, 0.01)


func test_ready_under_the_mouse_restores_the_swell() -> void:
	var button: PowerButton = _power(0)
	button.mouse_entered.emit()
	_panel.set_power_cooldown(4.0, 8.0)
	_panel.set_power_cooldown(0.0, 8.0)
	await wait_seconds(PowerButton.SCALE_SECONDS + 0.1)
	assert_almost_eq(button.scale.x, PowerButton.HOVER_SCALE, 0.01)


func test_cooldown_start_does_not_cut_the_punch_short() -> void:
	var button: PowerButton = _power(0)
	button.play_activate()
	_panel.set_power_cooldown(4.0, 8.0)
	await wait_seconds(PowerButton.SCALE_SECONDS + 0.05)
	assert_true(button._punching, "punch still settling")
	await wait_seconds(0.4)
	assert_almost_eq(button.scale.x, 1.0, 0.01)


func test_quiet_cooldown_end_plays_no_ready_cue() -> void:
	var button: PowerButton = _power(0)
	_panel.set_power_cooldown(4.0, 8.0)
	_panel.set_power_cooldown(0.0, 8.0, true)
	assert_false(button.disabled)
	assert_eq(button._bubbles.count(), 0)


func test_activate_finds_the_button_by_kind() -> void:
	_panel.play_power_activate(StreamerPowers.Kind.BLAST)
	assert_gt(_power(2)._bubbles.count(), 0)
	assert_eq(_power(0)._bubbles.count(), 0)


func test_cooldown_bar_fills_and_button_is_disabled() -> void:
	var button: PowerButton = _power(1)
	var bar: ColorRect = button.get_child(0) as ColorRect
	_panel.set_power_cooldown(6.0, 8.0)
	assert_true(button.disabled)
	var before: float = bar.offset_right
	_panel.set_power_cooldown(2.0, 8.0)
	assert_gt(bar.offset_right, before)
	assert_true(button.disabled)


func test_rapid_double_toggle_ends_consistently() -> void:
	var box: Control = _panel.get_node("Panel") as Control
	_panel.set_open(false)
	await wait_seconds(ControlPanel.SLIDE_SECONDS * 0.4)
	_panel.set_open(true)
	await wait_seconds(ControlPanel.OPEN_SECONDS + 0.15)
	assert_true(box.visible)
	assert_eq(box.modulate.a, 1.0)
	assert_almost_eq(box.get_global_rect().position.y, ControlPanel.OPEN_TOP, 0.5)
	_panel.set_open(false)
	await wait_seconds(ControlPanel.SLIDE_SECONDS * 0.4)
	_panel.set_open(true)
	_panel.set_open(false)
	await wait_seconds(ControlPanel.SLIDE_SECONDS + 0.15)
	assert_false(box.visible)
	assert_eq(box.modulate.a, 0.0)
