class_name SushiDecor
extends Node2D
## The dressing of Sushi Bar: red paper lanterns that hang from the top of the frame and sway a
## little, each with a warm glow. Purely visual; no physics.

## World x of each lantern, the length of its cord and its body size.
@export var lantern_xs: PackedFloat32Array = [300.0, 560.0, 1360.0, 1620.0]
@export var cord: float = 70.0
@export var lantern_size: Vector2 = Vector2(54.0, 70.0)
@export var paper: Color = Color(0.86, 0.16, 0.12)
@export var glow: Color = Color(1.0, 0.6, 0.3)

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for i: int in lantern_xs.size():
		_draw_lantern(lantern_xs[i], sin(_time * 0.9 + float(i) * 1.7) * 0.05)


## One lantern on its cord, swung `angle` radians about the top of the cord.
func _draw_lantern(x: float, angle: float) -> void:
	var top: Vector2 = Vector2(x, 0.0)
	var hang: Vector2 = top + Vector2(0.0, cord).rotated(angle)
	draw_line(top, hang, Color(0.1, 0.05, 0.04), 2.0, true)
	draw_set_transform(hang, angle)
	var half: Vector2 = lantern_size * 0.5
	for ring: int in 4:
		var r: float = half.x * (1.6 - 0.15 * float(ring))
		draw_circle(Vector2(0.0, half.y), r, Color(glow, 0.05))
	var body: PackedVector2Array = PackedVector2Array()
	for k: int in 24:
		var a: float = TAU * float(k) / 24.0
		body.append(Vector2(cos(a) * half.x, half.y + sin(a) * half.y))
	draw_colored_polygon(body, paper)
	# Ribs, the black caps and a pale tassel.
	for rib: int in 3:
		var y: float = half.y + (float(rib) - 1.0) * half.y * 0.5
		var w: float = half.x * sqrt(maxf(1.0 - pow((y - half.y) / half.y, 2.0), 0.0))
		draw_line(Vector2(-w, y), Vector2(w, y), paper.darkened(0.35), 2.0, true)
	draw_rect(Rect2(-half.x * 0.45, -2.0, half.x * 0.9, 8.0), Color(0.08, 0.06, 0.06))
	draw_rect(
		Rect2(-half.x * 0.45, lantern_size.y - 6.0, half.x * 0.9, 8.0), Color(0.08, 0.06, 0.06)
	)
	draw_line(
		Vector2(0.0, lantern_size.y + 2.0),
		Vector2(0.0, lantern_size.y + 22.0),
		Color(1.0, 0.85, 0.4),
		3.0,
		true
	)
	draw_circle(Vector2(0.0, half.y), half.x * 0.35, Color(glow, 0.35))
	draw_set_transform(Vector2.ZERO)
