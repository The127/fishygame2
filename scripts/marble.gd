class_name Marble
extends RigidBody2D
## A fish marble. The visual is drawn in code and tinted by `color`.

const RADIUS: float = 14.0

var id: int = 0
var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()

var label_text: String = "":
	set(value):
		label_text = value
		if _label != null:
			_label.text = value

var _label: Label


func _ready() -> void:
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


func _process(_delta: float) -> void:
	var size: Vector2 = _label.get_minimum_size()
	_label.global_position = global_position + Vector2(-size.x * 0.5, -RADIUS - size.y - 2.0)


func _draw() -> void:
	var dark: Color = color.darkened(0.35)
	# Tail, body, fin, eye.
	draw_colored_polygon(
		PackedVector2Array([Vector2(-6, 0), Vector2(-15, -8), Vector2(-15, 8)]), dark
	)
	draw_circle(Vector2.ZERO, RADIUS - 2.0, color)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-2, -10), Vector2(4, -13), Vector2(5, -8)]), dark
	)
	draw_circle(Vector2(5, -2), 3.0, Color.WHITE)
	draw_circle(Vector2(6, -2), 1.5, Color.BLACK)
	draw_arc(Vector2.ZERO, RADIUS - 2.0, 0.0, TAU, 24, dark, 1.5)
