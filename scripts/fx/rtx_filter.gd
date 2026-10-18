class_name RtxFilter
extends CanvasLayer
## The "RTX ON" setting: an over-the-top post effect over the race and its overlay (bloom,
## lens streaks, light shafts, a shine sweep) plus a pulsing "RTX ON" badge. Hidden while
## off, so it then costs nothing. Sits above the overlay and below the control panel.

const SHADER_PATH: String = "res://assets/shaders/rtx.gdshader"
const LAYER: int = 5
const MARGIN: float = 48.0
const BADGE_GREEN: Color = Color(0.46, 0.73, 0.0)
## Seconds per pulse of the badge glow.
const PULSE_SECONDS: float = 1.6

var _screen: ColorRect
var _frame: Control
var _badge: Label
var _look: LabelSettings
var _age: float = 0.0


func _init() -> void:
	layer = LAYER
	visible = false
	_screen = ColorRect.new()
	_screen.name = "Screen"
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	_screen.material = material
	add_child(_screen)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_badge = Label.new()
	_badge.name = "Badge"
	_badge.text = "RTX ON"
	_look = LabelSettings.new()
	_look.font = UiStyle.font(900, 2)
	_look.font_size = 44
	_look.font_color = Color.WHITE
	_look.outline_color = BADGE_GREEN
	_look.outline_size = 14
	_look.shadow_color = Color(BADGE_GREEN, 0.8)
	_look.shadow_size = 28
	_look.shadow_offset = Vector2.ZERO
	_badge.label_settings = _look
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_badge)
	set_badge_at_top(false)


func set_enabled(on: bool) -> void:
	visible = on
	set_process(on)


func is_enabled() -> bool:
	return visible


## Puts the badge in the top left corner instead of the bottom left one.
func set_badge_at_top(top: bool) -> void:
	var preset: Control.LayoutPreset = (
		Control.PRESET_TOP_LEFT if top else Control.PRESET_BOTTOM_LEFT
	)
	_badge.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	_badge.grow_vertical = Control.GROW_DIRECTION_END if top else Control.GROW_DIRECTION_BEGIN


func badge_is_at_top() -> bool:
	return _badge.anchor_top == 0.0


## Keeps the badge inside the part of the screen the game may use (see
## [method GameSettings.play_fraction]).
func set_play_fraction(fraction: Rect2) -> void:
	_frame.anchor_left = fraction.position.x
	_frame.anchor_top = fraction.position.y
	_frame.anchor_right = fraction.end.x
	_frame.anchor_bottom = fraction.end.y
	_frame.offset_left = 0.0
	_frame.offset_top = 0.0
	_frame.offset_right = 0.0
	_frame.offset_bottom = 0.0


func _ready() -> void:
	set_process(visible)


func _process(delta: float) -> void:
	_age += delta
	var pulse: float = 0.5 + 0.5 * sin(_age * TAU / PULSE_SECONDS)
	_look.shadow_color = Color(BADGE_GREEN, 0.4 + 0.6 * pulse)
