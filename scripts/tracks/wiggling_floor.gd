class_name WigglingFloor
extends StaticBody2D
## A stretch of floor that ripples like a muscle: a wave runs along it in the direction the fish
## travel, lifting and lowering the surface. The wave fades out toward both ends, so the stretch
## stays joined to the rest of the map, and is always smaller than the slope it lies on, so the
## floor never turns uphill and no dip can trap a fish.
##
## `surface` is the top line of the floor from upstream to downstream, in this body's local
## coordinates. The body builds its colliders and its `Visual` Polygon2D from it and moves both
## on the physics clock, so the wave is part of the finish replay. Any Line2D under `Visual` (the
## map's edge outline) follows the shape too. A seed picks where in its cycle the wave starts.

## Spacing in pixels between the points the wave is sampled at.
const STEP: float = 28.0

## Top line of the floor, upstream first.
@export var surface: PackedVector2Array = PackedVector2Array()
## How thick the floor is, straight down from the surface.
@export var thickness: float = 26.0
## Highest the surface rises or sinks from its resting line, in pixels.
@export var amplitude: float = 6.0
@export var wavelength: float = 340.0
## Seconds a wave takes to travel one wavelength.
@export var period: float = 3.6

var _clock: float = 0.0
## Shifts the wave, in fractions of a cycle. Drawn from the race seed.
var _offset: float = 0.0
var _points: PackedVector2Array = PackedVector2Array()
var _along: PackedFloat32Array = PackedFloat32Array()
var _length: float = 0.0
var _shapes: Array[ConvexPolygonShape2D] = []
var _visual: Polygon2D


func _ready() -> void:
	Replayable.join(self)
	_resample()
	for i: int in _points.size() - 1:
		var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
		var owner_node: CollisionShape2D = CollisionShape2D.new()
		owner_node.shape = shape
		add_child(owner_node)
		_shapes.append(shape)
	_visual = get_node("Visual") as Polygon2D
	_shape_floor()


## Called by [method Track.seed_gimmicks]: the wave starts at a point that depends on the seed.
func reseed(seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	_offset = rng.randf()
	_clock = 0.0
	_shape_floor()


## Called by [method Track.stop_gimmicks]: the floor is where the scene put it.
func stop_gimmick() -> void:
	_clock = 0.0
	_offset = 0.0
	_shape_floor()


## How far the surface is raised (negative) or lowered at `along` pixels from the upstream end
## at race time `t`.
func lift_at(along: float, t: float) -> float:
	var u: float = clampf(along / maxf(_length, 1.0), 0.0, 1.0)
	var envelope: float = sin(PI * u) * sin(PI * u)
	return -amplitude * envelope * sin(TAU * (along / wavelength - t / period + _offset))


func _physics_process(delta: float) -> void:
	_clock += delta
	_shape_floor()


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([_clock, _offset])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_clock = Replayable.mix(from, to, weight, 0)
	_offset = from[1]
	_shape_floor()


func _resample() -> void:
	_points = PackedVector2Array()
	_along = PackedFloat32Array()
	_length = 0.0
	for i: int in surface.size() - 1:
		_length += surface[i].distance_to(surface[i + 1])
	var count: int = maxi(ceili(_length / STEP), 1)
	var curve: Curve2D = Curve2D.new()
	for point: Vector2 in surface:
		curve.add_point(point)
	for i: int in count + 1:
		var along: float = _length * float(i) / float(count)
		_points.append(curve.sample_baked(along))
		_along.append(along)


func _shape_floor() -> void:
	if _shapes.is_empty():
		return
	var top: PackedVector2Array = PackedVector2Array()
	for i: int in _points.size():
		top.append(_points[i] + Vector2(0.0, lift_at(_along[i], _clock)))
	var drop: Vector2 = Vector2(0.0, thickness)
	for i: int in _shapes.size():
		_shapes[i].points = PackedVector2Array(
			[top[i], top[i + 1], top[i + 1] + drop, top[i] + drop]
		)
	var ring: PackedVector2Array = top.duplicate()
	for i: int in range(top.size() - 1, -1, -1):
		ring.append(top[i] + drop)
	_visual.polygon = ring
	var outline: PackedVector2Array = ring + PackedVector2Array([ring[0]])
	for child: Node in _visual.get_children():
		if child is Line2D:
			(child as Line2D).points = outline
