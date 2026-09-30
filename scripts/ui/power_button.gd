class_name PowerButton
extends Button
## A streamer power button with a drawn icon that shows the shared cooldown: while it runs the
## button is disabled and a bar fills it from left to right. It swells on hover, squashes on
## press, glows and blows bubbles while armed, bursts when the power fires and rings once the
## cooldown ends.

const FLASH_SECONDS: float = 0.35
const BAR_COLOR: Color = Color(UiStyle.CYAN, 0.35)
## Gap between the button border and the bar.
const INSET: float = 3.0
const HOVER_SCALE: float = 1.06
const PRESS_SCALE: float = 0.94
const SCALE_SECONDS: float = 0.14
const MIN_HEIGHT: float = 76.0
## Room above the label for the icon.
const TEXT_TOP_MARGIN: float = 38.0
const ICON_HALF: float = 13.0
const ICON_CENTER_Y: float = 25.0
const RING_SECONDS: float = 0.5
const RING_GROW: float = 16.0
const ARMED_BUBBLE_EVERY: float = 0.3

## Which power this is: a [enum StreamerPowers.Kind].
@export var kind: int = 0

var _bar: ColorRect
var _cooling: bool = false
var _fraction: float = 1.0
var _flash_tween: Tween
var _scale_tween: Tween
var _bubbles: BubbleBurst = BubbleBurst.new()
var _glow: StyleBoxFlat = StyleBoxFlat.new()
var _time: float = 0.0
var _bubble_clock: float = 0.0
var _hovered: bool = false
var _ring_age: float = -1.0
var _ring_color: Color = Color.WHITE
var _was_animating: bool = false


func _ready() -> void:
	custom_minimum_size.y = MIN_HEIGHT
	_bar = ColorRect.new()
	_bar.color = BAR_COLOR
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.anchor_bottom = 1.0
	_bar.offset_left = INSET
	_bar.offset_top = INSET
	_bar.offset_bottom = -INSET
	_bar.visible = false
	add_child(_bar)
	_glow.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_glow.set_border_width_all(2)
	_glow.set_corner_radius_all(8)
	resized.connect(_on_resized)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	_on_resized()


func _process(delta: float) -> void:
	_time += delta
	_bubbles.step(delta)
	if _ring_age >= 0.0:
		_ring_age += delta
		if _ring_age >= RING_SECONDS:
			_ring_age = -1.0
	if is_armed():
		_bubble_clock -= delta
		if _bubble_clock <= 0.0:
			_bubble_clock = ARMED_BUBBLE_EVERY
			var x: float = randf_range(size.x * 0.2, size.x * 0.8)
			_bubbles.emit(Vector2(x, size.y - 6.0), Vector2(0.0, -28.0), 1.1, randf_range(1.5, 3.0))
	var animating: bool = is_armed() or _ring_age >= 0.0 or _bubbles.count() > 0
	if animating or _was_animating:
		queue_redraw()
	_was_animating = animating


func _draw() -> void:
	var accent: Color = UiStyle.power_color(kind)
	if is_armed():
		var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
		_draw_halo(accent, 2.0 + 4.0 * pulse, 0.45 + 0.4 * pulse)
	if _ring_age >= 0.0:
		var t: float = _ring_age / RING_SECONDS
		_draw_halo(_ring_color, 2.0 + RING_GROW * t, 0.9 * (1.0 - t))
	var icon_color: Color = accent
	if disabled:
		icon_color = Color(UiStyle.MUTED, 0.7)
	elif is_armed():
		icon_color = Color.WHITE
	elif _hovered:
		icon_color = accent.lightened(0.35)
	PowerIcon.draw(self, kind, Vector2(size.x * 0.5, ICON_CENTER_Y), ICON_HALF, icon_color)
	_bubbles.draw(self, Color(accent, 0.85))


## True while this power is the chosen one and waits for a click on the track.
func is_armed() -> bool:
	return button_pressed


func is_cooling() -> bool:
	return _cooling


## Gives the button its look: the icon's room above the label and the armed style.
func apply_style() -> void:
	var accent: Color = UiStyle.power_color(kind)
	var normal: StyleBoxFlat = UiStyle.button_box(false)
	normal.border_color = accent
	var hover: StyleBoxFlat = UiStyle.button_box(true)
	var armed: StyleBoxFlat = UiStyle.armed_button_box()
	armed.border_color = accent.lightened(0.5)
	armed.bg_color = Color(accent, 0.3)
	armed.shadow_color = Color(accent, 0.65)
	var gray: StyleBoxFlat = UiStyle.disabled_button_box()
	var styles: Dictionary = {
		"normal": normal,
		"hover": hover,
		"pressed": armed,
		"hover_pressed": armed,
		"focus": hover,
		"disabled": gray,
	}
	for state: String in styles:
		var box: StyleBoxFlat = styles[state]
		box.content_margin_top = TEXT_TOP_MARGIN
		add_theme_stylebox_override(state, box)
	add_theme_color_override("font_hover_pressed_color", Color.WHITE)


## Shows the cooldown as [param fraction] done, 0..1. Use 1 for ready.
func set_cooldown_progress(fraction: float) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	var cooling: bool = _fraction < 1.0
	if cooling != _cooling:
		_cooling = cooling
		disabled = cooling
		_bar.visible = cooling
		if cooling:
			_scale_to(1.0)
		else:
			_flash()
			_pulse_ready()
	_update_bar()


## Plays the burst of the power firing: a ring, a spray of bubbles and a little punch.
func play_activate() -> void:
	_ring_color = Color.WHITE
	_ring_age = 0.0
	_bubbles.burst(size * 0.5, 10, 150.0, 0.7, 3.0)
	if _scale_tween != null:
		_scale_tween.kill()
	scale = Vector2.ONE * 1.14
	_scale_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.3)


func _update_bar() -> void:
	if _bar != null:
		_bar.offset_right = INSET + maxf(0.0, size.x - 2.0 * INSET) * _fraction


func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	modulate = Color(1.8, 1.8, 1.8)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, FLASH_SECONDS)


## The clear "ready again" cue: a ring in the power's colour and a few bubbles.
func _pulse_ready() -> void:
	_ring_color = UiStyle.power_color(kind)
	_ring_age = 0.0
	_bubbles.burst(size * 0.5, 5, 70.0, 0.6, 2.5)


func _draw_halo(color: Color, grow: float, alpha: float) -> void:
	_glow.border_color = Color(color, alpha)
	_glow.set_expand_margin_all(grow)
	draw_style_box(_glow, Rect2(Vector2.ZERO, size))


func _on_resized() -> void:
	pivot_offset = size * 0.5
	_update_bar()


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	if not disabled and not button_pressed:
		_scale_to(HOVER_SCALE if hovered else 1.0)
	queue_redraw()


func _on_button_down() -> void:
	if not disabled:
		_scale_to(PRESS_SCALE)


func _on_button_up() -> void:
	_scale_to(HOVER_SCALE if _hovered and not disabled else 1.0)


func _scale_to(target: float) -> void:
	if _scale_tween != null:
		_scale_tween.kill()
	_scale_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE * target, SCALE_SECONDS)
