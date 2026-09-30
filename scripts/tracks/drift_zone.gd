class_name DriftZone
extends Area2D
## A flooded stretch of lane where a slow current carries the fish along the zone's x axis (turn
## the node to follow the lane). It only ever pushes the way the lane already runs, so it speeds
## a fish up and can never hold one back. The zone is the Area2D's rectangle.

## Push in pixels per second squared.
const PUSH: float = 240.0
const STREAKS: int = 12
const STREAK_LENGTH: float = 46.0

@export var tint: Color = Color(0.45, 0.85, 0.95)

var _size: Vector2 = Vector2.ZERO
var _time: float = 0.0


func _ready() -> void:
	var shape: CollisionShape2D = get_node("CollisionShape2D") as CollisionShape2D
	_size = (shape.shape as RectangleShape2D).size


func _physics_process(_delta: float) -> void:
	var push: Vector2 = Vector2.RIGHT.rotated(global_rotation) * PUSH
	for body: Node2D in get_overlapping_bodies():
		if body is Marble:
			var marble: Marble = body as Marble
			marble.apply_central_force(push * marble.mass)


func _process(delta: float) -> void:
	# Ambient only: the streaks keep drifting under the replay too.
	_time += delta
	queue_redraw()


func _draw() -> void:
	var half: Vector2 = _size * 0.5
	draw_rect(Rect2(-half, _size), Color(tint, 0.1))
	draw_line(Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Color(tint, 0.4), 2.0, true)
	for i: int in STREAKS:
		var row: float = fposmod(float(i) * 0.618034, 1.0)
		var along: float = fposmod(_time * (0.12 + 0.08 * fposmod(float(i) * 0.37, 1.0)) + row, 1.0)
		var y: float = -half.y + (0.15 + 0.7 * fposmod(float(i) * 0.43, 1.0)) * _size.y
		var x: float = -half.x + along * _size.x
		var fade: float = sin(PI * along)
		var start: Vector2 = Vector2(maxf(x - STREAK_LENGTH, -half.x), y)
		draw_line(start, Vector2(x, y), Color(tint, 0.55 * fade), 1.5, true)
