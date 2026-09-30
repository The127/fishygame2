class_name PinballFlipper
extends AnimatableBody2D
## A pinball flipper: a blade hinged at its origin that rests pointing down toward the drain and
## snaps up when fired, flinging any fish lying on it. The fling is a direct push on the fish
## touching the blade (measured by the `Sensor`, built in code), so a fire always hits the same
## way. The blade and its sensor are built in code from `length`.

const BASE_RADIUS: float = 18.0
const TIP_RADIUS: float = 9.0
## Blade speed in radians per second, up and back down.
const RAISE_SPEED: float = 4.5
const LOWER_SPEED: float = 5.0
## Seconds the blade stays up.
const HOLD_SECONDS: float = 0.14
## Speed in pixels per second a fish leaves the blade at, at the tip. Nearer the hinge is gentler.
const KICK_SPEED: float = 560.0
## How far around the blade a fish still counts as touching it.
const SENSOR_PAD: float = 12.0
const FILL: Color = Color(0.2, 0.05, 0.16)
const EDGE: Color = Color(1.0, 0.42, 0.55)
const LIT_EDGE: Color = Color(1.0, 0.9, 0.85)

## -1 for the left flipper (hinged on the left, pointing right), 1 for the right one.
@export_enum("Left:-1", "Right:1") var side: int = -1
@export var length: float = 150.0
## How far below horizontal the blade points at rest, in degrees.
@export var rest_degrees: float = 28.0
## How far above horizontal it points when raised, in degrees.
@export var raise_degrees: float = 34.0

## Whether the blade is on its way up or held up.
var raised: bool = false

var _hold: float = 0.0
## 1 just after a fire, fading to 0: the blade glows.
var _lit: float = 0.0
var _sensor: Area2D


func _ready() -> void:
	Replayable.join(self)
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = _blade(0.0)
	collider.shape = shape
	add_child(collider)
	_sensor = Area2D.new()
	var zone: CollisionShape2D = CollisionShape2D.new()
	var zone_shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	zone_shape.points = _blade(SENSOR_PAD)
	zone.shape = zone_shape
	_sensor.add_child(zone)
	add_child(_sensor)
	rotation = rest_angle()


func _physics_process(delta: float) -> void:
	_lit = maxf(_lit - delta * 2.5, 0.0)
	if raised:
		_hold -= delta
		if _hold <= 0.0:
			raised = false
	var target: float = raised_angle() if raised else rest_angle()
	rotation = move_toward(rotation, target, (RAISE_SPEED if raised else LOWER_SPEED) * delta)
	queue_redraw()


func _draw() -> void:
	var points: PackedVector2Array = _blade(0.0)
	draw_colored_polygon(points, FILL.lerp(EDGE, _lit * 0.6))
	draw_polyline(points + PackedVector2Array([points[0]]), EDGE.lerp(LIT_EDGE, _lit), 3.0, true)
	draw_circle(Vector2.ZERO, BASE_RADIUS * 0.45, EDGE.lerp(LIT_EDGE, _lit))


## Rotation with the blade at rest (radians, clockwise positive).
func rest_angle() -> float:
	var rest: float = deg_to_rad(rest_degrees)
	return rest if side < 0 else PI - rest


## Rotation with the blade up.
func raised_angle() -> float:
	var up: float = deg_to_rad(raise_degrees)
	return -up if side < 0 else PI + up


## Raises the blade and flings every fish touching it. Returns how many were flung.
func fire() -> int:
	raised = true
	_hold = HOLD_SECONDS
	_lit = 1.0
	var flung: int = 0
	var direction: Vector2 = kick_direction()
	for body: Node2D in _sensor.get_overlapping_bodies():
		if not body is Marble:
			continue
		var marble: Marble = body as Marble
		var along: float = clampf(to_local(marble.global_position).x, 0.0, length)
		var speed: float = KICK_SPEED * lerpf(0.6, 1.0, along / length)
		var gain: float = speed - marble.linear_velocity.dot(direction)
		if gain > 0.0:
			marble.sleeping = false
			marble.apply_central_impulse(direction * gain * marble.mass)
		flung += 1
	return flung


## The way a fling sends a fish: up and toward the middle of the table.
func kick_direction() -> Vector2:
	var angle: float = lerp_angle(rest_angle(), raised_angle(), 0.15)
	var along: Vector2 = Vector2.from_angle(angle)
	var normal: Vector2 = Vector2(along.y, -along.x)
	return normal if normal.y < 0.0 else -normal


## Part of the finish replay ([Replayable]): the blade angle and its glow.
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([rotation, _lit, 1.0 if raised else 0.0])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	rotation = Replayable.mix(from, to, weight, 0)
	_lit = Replayable.mix(from, to, weight, 1)
	raised = Replayable.step(from, to, weight, 2) > 0.5
	queue_redraw()


## Puts the blade back at rest, as it starts a race.
func reset() -> void:
	raised = false
	_hold = 0.0
	_lit = 0.0
	rotation = rest_angle()
	queue_redraw()


## The blade outline, widened by `pad` all round, pointing along +x from the hinge.
func _blade(pad: float) -> PackedVector2Array:
	var base: float = BASE_RADIUS + pad
	var tip: float = TIP_RADIUS + pad
	return PackedVector2Array(
		[
			Vector2(-base, 0.0),
			Vector2(0.0, -base),
			Vector2(length, -tip),
			Vector2(length + tip, 0.0),
			Vector2(length, tip),
			Vector2(0.0, base),
		]
	)
