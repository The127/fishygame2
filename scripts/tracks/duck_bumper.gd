class_name DuckBumper
extends AnimatableBody2D
## A rubber duck bobbing about in a chamber of the pipe. Kinematic, so fish are nudged by it
## and the motion is identical for a given physics step. It traces a slow figure of eight around
## its home position; the race seed decides where on it the duck starts.

const BODY: Color = Color(0.95, 0.78, 0.16)
const BODY_SHADE: Color = Color(0.72, 0.5, 0.1)
const BEAK: Color = Color(0.95, 0.42, 0.1)
## Drawing scale, sized so the duck fills its collider.
const SCALE: float = 1.3

## Phase in radians the duck moves at, per second.
@export var speed: float = 1.1
## How far the duck drifts from its home position, in pixels, along each axis.
@export var reach: Vector2 = Vector2(68.0, 24.0)

var _home: Vector2 = Vector2.ZERO
var _phase: float = 0.0
var _facing: float = 1.0


func _ready() -> void:
	_home = position
	Replayable.join(self)
	_place()


func _physics_process(delta: float) -> void:
	_phase = fposmod(_phase + speed * delta, TAU)
	_place()


## Picks where on its path the duck starts in this race. Called by [Track] with a seed.
func reseed(seed_value: int) -> void:
	_phase = fposmod(float(seed_value % 6283) * 0.001, TAU)
	_place()


func get_phase() -> float:
	return _phase


## Position on the map at a given phase.
func path_at(phase: float) -> Vector2:
	return _home + Vector2(sin(phase) * reach.x, sin(phase * 2.0) * reach.y)


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([_phase])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_phase = Replayable.mix(from, to, weight, 0)
	_place()


func _place() -> void:
	position = path_at(_phase)
	var facing: float = 1.0 if cos(_phase) >= 0.0 else -1.0
	if facing != _facing:
		_facing = facing
		queue_redraw()


func _draw() -> void:
	# Drawn facing right; flipped for a duck heading left.
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(_facing * SCALE, SCALE))
	draw_circle(Vector2(0.0, 5.0), 19.0, BODY_SHADE)
	draw_circle(Vector2(0.0, 3.0), 18.0, BODY)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-14.0, 0.0), Vector2(-28.0, -9.0), Vector2(-17.0, 9.0)]), BODY
	)
	draw_circle(Vector2(12.0, -15.0), 10.0, BODY)
	draw_colored_polygon(
		PackedVector2Array([Vector2(20.0, -17.0), Vector2(30.0, -13.0), Vector2(20.0, -9.0)]), BEAK
	)
	draw_circle(Vector2(15.0, -18.0), 2.0, Color(0.1, 0.06, 0.02))
	draw_arc(Vector2(-2.0, 5.0), 9.0, PI * 0.9, PI * 1.9, 12, BODY_SHADE, 2.5, true)
	draw_arc(Vector2(0.0, 3.0), 22.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, 0.14), 5.0, true)
	draw_set_transform(Vector2.ZERO)
