class_name Marble
extends RigidBody2D
## A fish marble. The visual is drawn by FishVisual, tinted by `color`.

const RADIUS: float = 14.0

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


func _process(delta: float) -> void:
	_fish.face(linear_velocity, delta)
	var size: Vector2 = _label.get_minimum_size()
	_label.global_position = global_position + Vector2(-size.x * 0.5, -RADIUS - size.y - 2.0)
