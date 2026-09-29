class_name FishVisual
extends Node2D
## Procedural fish drawing. It faces its `heading` (radians) and never spins
## with the rolling body, so the fish stays right side up.

const LENGTH: float = 15.0
const HEIGHT: float = 10.0

var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()

var heading: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 5


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Points the fish along a travel direction. Slow or still marbles keep their last heading.
func face(velocity: Vector2, delta: float) -> void:
	if velocity.length() > 20.0:
		heading = lerp_angle(heading, velocity.angle(), clampf(delta * 10.0, 0.0, 1.0))
	global_position = get_parent().global_position
	# Flip vertically when swimming left so the dorsal fin stays on top.
	var facing_left: bool = absf(wrapf(heading, -PI, PI)) > PI * 0.5
	rotation = heading
	scale = Vector2(1.0, -1.0 if facing_left else 1.0)


func _draw() -> void:
	var dark: Color = color.darkened(0.35)
	var light: Color = color.lightened(0.45)
	var wag: float = sin(_time * 12.0) * 3.0
	# Tail.
	draw_colored_polygon(
		PackedVector2Array(
			[
				Vector2(-LENGTH * 0.6, 0),
				Vector2(-LENGTH - 4.0, -HEIGHT * 0.7 + wag),
				Vector2(-LENGTH - 1.0, wag * 0.4),
				Vector2(-LENGTH - 4.0, HEIGHT * 0.7 + wag),
			]
		),
		dark
	)
	# Dorsal and belly fins.
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(-5, -HEIGHT * 0.7), Vector2(2, -HEIGHT - 4.0), Vector2(5, -HEIGHT * 0.6)]
		),
		dark
	)
	draw_colored_polygon(
		PackedVector2Array(
			[Vector2(-2, HEIGHT * 0.7), Vector2(2, HEIGHT + 2.0), Vector2(4, HEIGHT * 0.6)]
		),
		dark
	)
	# Body: an ellipse, lighter belly, outline.
	var body := PackedVector2Array()
	var belly := PackedVector2Array()
	for i: int in 24:
		var a: float = TAU * float(i) / 24.0
		var p := Vector2(cos(a) * LENGTH, sin(a) * HEIGHT)
		body.append(p)
		if p.y >= 0.0:
			belly.append(Vector2(p.x, p.y * 0.55 + 3.0))
	draw_colored_polygon(body, color)
	draw_polyline(body + PackedVector2Array([body[0]]), dark, 1.5)
	# Gill line, eye.
	draw_arc(Vector2(5, 0), 7.0, PI * 0.65, PI * 1.35, 8, dark, 1.5)
	draw_circle(Vector2(9, -2.5), 3.0, Color.WHITE)
	draw_circle(Vector2(10, -2.5), 1.5, Color.BLACK)
	if belly.size() > 2:
		draw_polyline(belly, light, 1.0)
