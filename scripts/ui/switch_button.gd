class_name SwitchButton
extends Button
## On/off switch for the settings screen: a pill with a sliding knob that reads clearly at a
## glance in both states, unlike the stock checkbox whose unchecked box is invisible here.

const TRACK_SIZE: Vector2 = Vector2(64.0, 32.0)
const KNOB_INSET: float = 4.0
const OFF_TRACK: Color = Color(0.416, 0.624, 0.769, 0.25)


func _init() -> void:
	toggle_mode = true
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = TRACK_SIZE
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggled.connect(_on_toggled)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Shows `on` without emitting [signal BaseButton.toggled].
func show_state(on: bool, enabled: bool = true) -> void:
	set_pressed_no_signal(on)
	disabled = not enabled
	queue_redraw()


func _draw() -> void:
	var track := Rect2((size - TRACK_SIZE) / 2.0, TRACK_SIZE)
	var radius: float = TRACK_SIZE.y / 2.0
	var on: bool = button_pressed
	var color: Color = UiStyle.CYAN if on else OFF_TRACK
	if disabled:
		color = Color(color, 0.35)
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	if not disabled and (has_focus() or is_hovered()):
		box.set_border_width_all(2)
		box.border_color = UiStyle.CYAN_LIGHT
	draw_style_box(box, track)
	var x: float = track.end.x - radius if on else track.position.x + radius
	var knob_color: Color = Color.WHITE if on else UiStyle.TEXT.darkened(0.25)
	if disabled:
		knob_color = Color(knob_color, 0.5)
	draw_circle(Vector2(x, track.get_center().y), radius - KNOB_INSET, knob_color)


func _on_toggled(_on: bool) -> void:
	queue_redraw()
