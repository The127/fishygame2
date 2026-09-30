class_name Blowhole
extends Node2D
## The whale's blowhole, at the finish: a column of water (an Area2D child named Column) that
## throws every fish that has already crossed the line up into the air. Fish still racing pass
## through untouched, so it never decides a result.

## Lift in pixels per second squared, on top of the gravity it beats.
const LIFT: float = 1900.0
## Seconds the plume takes to build up and die away.
const FADE: float = 0.2
const DROPLETS: int = 16

@export var tint: Color = Color(0.7, 0.95, 1.0)

var _column: Area2D
var _size: Vector2 = Vector2.ZERO
## How strongly the plume spouts, 0 to 1.
var _strength: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	Replayable.join(self)
	_column = get_node("Column") as Area2D
	var shape: CollisionShape2D = _column.get_node("CollisionShape2D") as CollisionShape2D
	_size = (shape.shape as RectangleShape2D).size


## Unit vector the plume throws fish along, in world space.
func get_direction() -> Vector2:
	return -global_transform.y.normalized()


func _physics_process(delta: float) -> void:
	_clock += delta
	var launching: bool = false
	var push: Vector2 = get_direction() * LIFT
	for body: Node2D in _column.get_overlapping_bodies():
		if body is Marble and (body as Marble).has_finished:
			var marble: Marble = body as Marble
			marble.apply_central_force(push * marble.mass)
			launching = true
	_strength = move_toward(_strength, 1.0 if launching else 0.0, delta / FADE)
	queue_redraw()


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([_strength, _clock])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_strength = Replayable.mix(from, to, weight, 0)
	_clock = Replayable.mix(from, to, weight, 1)
	queue_redraw()


func _draw() -> void:
	var half: float = _size.x * 0.5
	# The hole itself: a dark slit with a wet rim.
	draw_rect(Rect2(-half, -4.0, _size.x, 8.0), Color(0.02, 0.0, 0.05, 0.8))
	draw_line(
		Vector2(-half, 0.0), Vector2(half, 0.0), Color(tint, 0.4 + 0.4 * _strength), 3.0, true
	)
	if _strength <= 0.01:
		return
	var top: float = -_size.y
	var body: PackedVector2Array = PackedVector2Array(
		[
			Vector2(-half * 0.6, 0.0),
			Vector2(-half, top),
			Vector2(half, top),
			Vector2(half * 0.6, 0.0)
		]
	)
	var base_color: Color = Color(tint, 0.5 * _strength)
	var top_color: Color = Color(tint, 0.0)
	draw_polygon(body, PackedColorArray([base_color, top_color, top_color, base_color]))
	for i: int in DROPLETS:
		var lane: float = fposmod(float(i) * 0.618034, 1.0) - 0.5
		var rise: float = fposmod(
			_clock * (1.1 + 0.6 * fposmod(float(i) * 0.37, 1.0)) + float(i) * 0.13, 1.0
		)
		var pos: Vector2 = Vector2(lane * _size.x * (0.6 + 0.5 * rise), -rise * _size.y * 1.2)
		var radius: float = 2.5 + 3.0 * fposmod(float(i) * 0.71, 1.0)
		draw_circle(pos, radius, Color(1.0, 1.0, 1.0, 0.7 * _strength * (1.0 - rise)))
