class_name Marble
extends RigidBody2D
## A fish marble. The visual is drawn by FishVisual, tinted by `color`.

const RADIUS: float = 14.0

## Seconds a curse keeps the marble slowed.
const CURSE_SECONDS: float = 3.0
const CURSE_DAMP: float = 3.0
const CURSE_TINT: Color = Color(0.6, 0.35, 0.85)
const BOOST_IMPULSE: float = 450.0
const CURSE_KNOCKBACK: float = 250.0

var id: int = 0
var color: Color = Color.WHITE:
	set(value):
		color = value
		if _fish != null:
			_fish.color = value

var label_text: String = "":
	set(value):
		label_text = value
		if _label != null:
			_label.text = value

var _curse_left: float = 0.0
var _base_damp: float = 0.0
var _label: Label
var _fish: FishVisual


func _ready() -> void:
	_fish = FishVisual.new()
	_fish.color = color
	add_child(_fish)
	# Top level so the name stays upright and unscaled while the marble rolls.
	_label = Label.new()
	_label.top_level = true
	_label.text = label_text
	_label.z_index = 10
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## Pushes the marble along `forward` (a unit vector toward the finish).
func boost(forward: Vector2) -> void:
	apply_central_impulse(forward * BOOST_IMPULSE * mass)


## Knocks the marble back against `forward` and slows it for [constant CURSE_SECONDS].
func curse(forward: Vector2) -> void:
	if _curse_left <= 0.0:
		_base_damp = linear_damp
	_curse_left = CURSE_SECONDS
	linear_damp = CURSE_DAMP
	apply_central_impulse(-forward * CURSE_KNOCKBACK * mass)
	if _fish != null:
		_fish.color = color.lerp(CURSE_TINT, 0.6)


func is_cursed() -> bool:
	return _curse_left > 0.0


func _physics_process(delta: float) -> void:
	if _curse_left <= 0.0:
		return
	_curse_left -= delta
	if _curse_left <= 0.0:
		_curse_left = 0.0
		linear_damp = _base_damp
		if _fish != null:
			_fish.color = color


func _process(delta: float) -> void:
	_fish.face(linear_velocity, delta)
	var size: Vector2 = _label.get_minimum_size()
	_label.global_position = global_position + Vector2(-size.x * 0.5, -RADIUS - size.y - 2.0)
