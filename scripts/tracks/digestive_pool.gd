class_name DigestivePool
extends Area2D
## A pool of stomach juice. Fish wading through it are slowed and buoyed up a little, so they
## crawl along the floor instead of racing over it. The pool is the Area2D's rectangle and is
## only ever a drag: it never stops a fish on a slope.

## Drag in 1/s: the force is this times the fish's speed, against its motion.
const DRAG: float = 1.6
## Fraction of gravity the juice takes away, on top of the drag.
const BUOYANCY: float = 0.15
const BUBBLES: int = 9

@export var tint: Color = Color(0.75, 1.0, 0.3)

var _size: Vector2 = Vector2.ZERO
var _time: float = 0.0


func _ready() -> void:
	var shape: CollisionShape2D = get_node("CollisionShape2D") as CollisionShape2D
	_size = (shape.shape as RectangleShape2D).size


func _physics_process(_delta: float) -> void:
	var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	for body: Node2D in get_overlapping_bodies():
		if body is Marble:
			var marble: Marble = body as Marble
			var force: Vector2 = -marble.linear_velocity * DRAG
			force.y -= gravity * BUOYANCY
			marble.apply_central_force(force * marble.mass)


func _process(delta: float) -> void:
	# Ambient only: the bubbles keep moving under the replay too.
	_time += delta
	queue_redraw()


func _draw() -> void:
	var half: Vector2 = _size * 0.5
	draw_rect(Rect2(-half, _size), Color(tint, 0.16))
	draw_line(Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Color(tint, 0.55), 2.0, true)
	for i: int in BUBBLES:
		var lane: float = fposmod(float(i) * 0.618034, 1.0)
		var rise: float = fposmod(_time * (0.25 + 0.2 * fposmod(float(i) * 0.37, 1.0)) + lane, 1.0)
		var pos: Vector2 = Vector2((lane - 0.5) * _size.x * 0.92, half.y - rise * _size.y)
		var radius: float = 2.0 + 3.0 * fposmod(float(i) * 0.71, 1.0)
		var alpha: float = sin(PI * rise)
		draw_arc(pos, radius, 0.0, TAU, 10, Color(tint, 0.8 * alpha), 1.5, true)
