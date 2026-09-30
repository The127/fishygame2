class_name ShockRing
extends Node2D
## A thin ring that expands and fades: the splash of a hook, the yank on a fish, the blast
## shockwave. Visual only; it frees itself when done.

var max_radius: float = 100.0
var duration: float = 0.4
var color: Color = Color.WHITE
var width: float = 4.0
## Seconds to wait before the ring starts growing.
var delay: float = 0.0

var _age: float = 0.0


## Adds a ring under `host` at a global position.
static func spawn(
	host: Node,
	global_pos: Vector2,
	radius: float,
	seconds: float,
	tint: Color,
	line_width: float = 4.0,
	wait: float = 0.0
) -> ShockRing:
	var ring: ShockRing = ShockRing.new()
	ring.max_radius = radius
	ring.duration = seconds
	ring.color = tint
	ring.width = line_width
	ring.delay = wait
	host.add_child(ring)
	ring.global_position = global_pos
	return ring


func _ready() -> void:
	z_index = 8


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= delay + duration:
		queue_free()


## 0 when the ring starts, 1 when it is gone.
func progress() -> float:
	return clampf((_age - delay) / maxf(duration, 0.001), 0.0, 1.0)


## Grows fast and slows down.
func current_radius() -> float:
	var left: float = 1.0 - progress()
	return max_radius * (1.0 - left * left * left)


func _draw() -> void:
	if _age < delay:
		return
	var left: float = 1.0 - progress()
	var radius: float = current_radius()
	var ring: Color = Color(color.r, color.g, color.b, color.a * left)
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.12 * left))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, ring, maxf(width * left, 1.0))
