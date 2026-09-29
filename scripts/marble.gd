class_name Marble
extends RigidBody2D
## A fish marble. The visual is drawn in code and tinted by `color`.

const RADIUS: float = 14.0

var id: int = 0
var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


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
