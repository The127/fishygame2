class_name Peristalsis
extends Area2D
## A stretch of gut that squeezes whatever is inside it along, always. Every fish in the
## Area2D's rectangle is pushed along the node's x axis, so a fish never dawdles in it. The
## push is constant, so nothing about it needs recording for the replay.

## Push in pixels per second squared.
@export var push: float = 240.0
@export var tint: Color = Color(1.0, 0.6, 0.85)

var _size: Vector2 = Vector2.ZERO
var _time: float = 0.0


func _ready() -> void:
	var shape: CollisionShape2D = get_node("CollisionShape2D") as CollisionShape2D
	_size = (shape.shape as RectangleShape2D).size


## Unit vector the gut pushes along, in world space.
func get_direction() -> Vector2:
	return global_transform.x.normalized()


func _physics_process(_delta: float) -> void:
	var force: Vector2 = get_direction() * push
	for body: Node2D in get_overlapping_bodies():
		if body is Marble:
			var marble: Marble = body as Marble
			marble.apply_central_force(force * marble.mass)


func _process(delta: float) -> void:
	# Ambient only: the ripples keep moving under the replay too.
	_time += delta
	queue_redraw()


func _draw() -> void:
	var half: Vector2 = _size * 0.5
	var spacing: float = 180.0
	var count: int = int(_size.x / spacing)
	for i: int in count:
		var x: float = fposmod(_time * 120.0 + float(i) * spacing, _size.x)
		var alpha: float = 0.35 * sin(PI * x / _size.x)
		var tip: Vector2 = Vector2(x - half.x, half.y - 12.0)
		draw_polyline(
			PackedVector2Array([tip + Vector2(-14.0, -12.0), tip, tip + Vector2(-14.0, 12.0)]),
			Color(tint, alpha),
			3.0,
			true
		)
