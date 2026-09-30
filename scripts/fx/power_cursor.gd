class_name PowerCursor
extends Node2D
## A ring that follows the mouse while a streamer power is armed, showing how far it reaches.

var radius: float = 0.0:
	set(value):
		radius = value
		visible = value > 0.0
		queue_redraw()


func _ready() -> void:
	z_index = 20
	visible = false


func _process(_delta: float) -> void:
	if radius > 0.0:
		global_position = get_global_mouse_position()


func _draw() -> void:
	if radius <= 0.0:
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.7), 2.0)
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0, 0.9))
