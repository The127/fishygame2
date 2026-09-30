class_name TrapDoor
extends Node2D
## A hinged floor plate that swings open on a timer and drops the fish above it onto the stretch
## of floor below, skipping what lies between. Each cycle is closed, then a telegraph of glowing
## edges and bubbles, then the plate swings down and stays open for a moment before it lifts back
## into the floor. The phase and the period come from the race seed and time only advances in
## physics frames, so a seed replays the same openings. A door that was never armed stays shut.
## Children: `Plate` (an AnimatableBody2D hinged at the door's origin, its polygon running
## away from the hinge along the local x axis, with a `Visual` polygon). The plate swings by
## `open_degrees` (the sign says which way), so pick it such that the free end goes down.

enum Phase { SHUT, TELEGRAPH, OPEN }

## How fast the plate swings, in radians per second. Gentle, so it never flings a fish.
const SWING_SPEED: float = 4.0
const BUBBLES: int = 8
## How far the period may stray from `period`, as a fraction.
const PERIOD_SPREAD: float = 0.15
const GLOW_COLOR: Color = Color(1.0, 0.85, 0.4)

@export var period: float = 6.5
@export var telegraph_seconds: float = 0.9
@export var open_seconds: float = 1.7
## How far the plate swings open, in degrees. Negative swings the other way.
@export_range(-110.0, 110.0) var open_degrees: float = 80.0
## Length of the plate along its local x axis (negative if it runs toward -x), for the glow.
@export var length: float = 110.0
@export var tint: Color = Color(1.0, 0.8, 0.35)

var clock: float = 0.0

var _plate: AnimatableBody2D
var _armed: bool = false
var _cycle: float = 0.0
var _offset: float = 0.0


func _ready() -> void:
	Replayable.join(self)
	_plate = get_node("Plate") as AnimatableBody2D
	_cycle = period
	queue_redraw()


## Picks this door's phase and period for a race and starts its clock. Called by
## [method Track.seed_gimmicks], so it runs whatever the hazard setting is.
func reseed(seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	_cycle = period * rng.randf_range(1.0 - PERIOD_SPREAD, 1.0 + PERIOD_SPREAD)
	_cycle = maxf(_cycle, telegraph_seconds + open_seconds + 0.5)
	_offset = rng.randf_range(0.0, _cycle)
	clock = 0.0
	_armed = true
	queue_redraw()


## Shuts the door for good and puts the plate back in the floor. Called by [method Track.stop_gimmicks].
func stop_gimmick() -> void:
	_armed = false
	clock = 0.0
	_plate.rotation = 0.0
	queue_redraw()


func is_armed() -> bool:
	return _armed


## Seconds between two openings of this door.
func get_cycle() -> float:
	return _cycle


## True while the door is meant to be open (the plate may still be swinging).
func is_open() -> bool:
	return phase_at(clock) == Phase.OPEN


## Where the door is in its cycle at race time `t`. A door that was never armed stays shut.
func phase_at(t: float) -> Phase:
	if not _armed:
		return Phase.SHUT
	var into: float = fposmod(t + _offset, _cycle)
	var start: float = _cycle - telegraph_seconds - open_seconds
	if into < start:
		return Phase.SHUT
	return Phase.TELEGRAPH if into < start + telegraph_seconds else Phase.OPEN


## The plate angle the door is swinging toward, in radians.
func target_angle() -> float:
	return deg_to_rad(open_degrees) if is_open() else 0.0


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not _armed:
		return
	clock += delta
	_plate.rotation = move_toward(_plate.rotation, target_angle(), SWING_SPEED * delta)
	queue_redraw()


## Seconds since the current phase began, or -1 while the door is shut.
func _phase_time() -> float:
	var into: float = fposmod(clock + _offset, _cycle)
	var start: float = _cycle - telegraph_seconds - open_seconds
	if into < start:
		return -1.0
	return into - start if into < start + telegraph_seconds else into - start - telegraph_seconds


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([clock, 1.0 if _armed else 0.0, _offset, _cycle, _plate.rotation])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	clock = Replayable.mix(from, to, weight, 0)
	_armed = Replayable.step(from, to, weight, 1) > 0.5
	_offset = from[2]
	_cycle = from[3]
	_plate.rotation = Replayable.mix(from, to, weight, 4)
	queue_redraw()


func _draw() -> void:
	var phase: Phase = phase_at(clock)
	var into: float = _phase_time()
	var alert: float = 0.0
	if phase == Phase.TELEGRAPH:
		alert = 0.5 + 0.5 * sin(into * 16.0)
	elif phase == Phase.OPEN:
		alert = 0.6
	# The hinge and a row of studs along the plate glow while the door is about to open.
	draw_circle(Vector2.ZERO, 7.0, Color(tint, 0.35 + 0.5 * alert))
	var step: float = length / 5.0
	for i: int in 5:
		var at: Vector2 = Vector2(step * (float(i) + 0.5), 0.0)
		var lit: float = alert if phase != Phase.SHUT else 0.0
		draw_circle(at, 3.5, Color(GLOW_COLOR, 0.25 + 0.7 * lit))
	if phase == Phase.TELEGRAPH:
		_draw_bubbles(0.3 + 0.5 * into / telegraph_seconds, 0.45)
	elif phase == Phase.OPEN:
		_draw_bubbles(1.0, 0.8)


## Bubbles streaming down through the hole.
func _draw_bubbles(strength: float, alpha: float) -> void:
	for i: int in BUBBLES:
		var along: float = fposmod(float(i) * 0.618034, 1.0)
		var fall: float = fposmod(clock * (90.0 + 40.0 * along) + float(i) * 37.0, 80.0)
		var pos: Vector2 = Vector2(length * along, 14.0 + fall)
		var fade: float = 1.0 - fall / 80.0
		var radius: float = 2.0 + 2.5 * fposmod(float(i) * 0.71, 1.0)
		draw_arc(pos, radius, 0.0, TAU, 10, Color(tint, alpha * strength * fade), 1.5, true)
