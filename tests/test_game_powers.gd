extends GameTestBase
## Game scene: arming and firing the streamer's powers, notices and chat lines.

var _powers: StreamerPowers


func before_each() -> void:
	super.before_each()
	_powers = _game.get_node("StreamerPowers") as StreamerPowers


func _click(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	_game._unhandled_input(event)


func test_settings_are_applied() -> void:
	var settings := GameSettings.new()
	settings.power_cooldown = 12
	settings.powers_per_race = 2
	settings.powers_enabled = false
	_game.settings = settings
	_game._apply_settings()
	assert_eq(_powers.cooldown, 12.0)
	assert_eq(_powers.max_per_race, 2)
	assert_false(_powers.enabled)


func test_hotkey_arms_and_the_same_key_disarms() -> void:
	_panel.power_pressed.emit(StreamerPowers.Kind.NET)
	assert_eq(_game._armed_power, StreamerPowers.Kind.NET)
	_panel.power_pressed.emit(StreamerPowers.Kind.NET)
	assert_eq(_game._armed_power, -1)


func test_right_click_disarms_without_firing() -> void:
	_start_race(2)
	_panel.power_pressed.emit(StreamerPowers.Kind.ROD)
	_click(MOUSE_BUTTON_RIGHT)
	assert_eq(_game._armed_power, -1)
	assert_eq(_powers.uses_left(), _powers.max_per_race)


func test_click_without_an_armed_power_does_nothing() -> void:
	_start_race(2)
	_click(MOUSE_BUTTON_LEFT)
	assert_eq(_powers.uses_left(), _powers.max_per_race)


func test_rod_hooks_the_fish_and_announces_it() -> void:
	_start_race(2)
	var marble: Marble = _marble(1)
	_game.get_viewport().warp_mouse(Vector2.ZERO)
	_game._on_power_used(StreamerPowers.Kind.ROD, marble.global_position)
	assert_eq(_source.sent, ["The streamer hooked @User1!"] as Array[String])


func test_armed_click_uses_the_power_and_disarms() -> void:
	_start_race(2)
	_panel.power_pressed.emit(StreamerPowers.Kind.BLAST)
	_click(MOUSE_BUTTON_LEFT)
	assert_eq(_game._armed_power, -1)
	assert_eq(_powers.uses_left(), _powers.max_per_race - 1)
	assert_eq(_source.sent.size(), 1)


func test_rod_that_finds_nothing_says_so() -> void:
	_start_race(2)
	_game._on_power_used(StreamerPowers.Kind.ROD, Vector2(99999.0, 99999.0))
	assert_eq(_source.sent, ["The streamer's hook came up empty"] as Array[String])


func test_net_and_blast_count_fish() -> void:
	_start_race(2)
	var at: Vector2 = _marble(0).global_position
	_game._on_power_used(StreamerPowers.Kind.NET, at)
	assert_true(_source.sent[0].begins_with("The streamer cast a net over "))
	_game._on_power_used(StreamerPowers.Kind.BLAST, Vector2(99999.0, 99999.0))
	assert_eq(_source.sent[1], "The streamer blasted no fish!")


func test_chat_line_respects_the_toggle() -> void:
	_game.settings.reply_powers = false
	_start_race(2)
	_game._on_power_used(StreamerPowers.Kind.BLAST, Vector2.ZERO)
	assert_eq(_source.sent.size(), 0)


func test_power_is_rejected_outside_a_race() -> void:
	_panel.power_pressed.emit(StreamerPowers.Kind.ROD)
	_click(MOUSE_BUTTON_LEFT)
	assert_eq(_source.sent.size(), 0)
	assert_eq(_game._power_status_text(), "powers only work during a race")


func test_state_change_puts_the_power_away() -> void:
	_panel.power_pressed.emit(StreamerPowers.Kind.ROD)
	_start_race(2)
	assert_eq(_game._armed_power, -1)
