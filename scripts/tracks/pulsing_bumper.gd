class_name PulsingBumper
extends AnimatableBody2D
## A muscle lobe of the stomach wall: a bumper that swells and relaxes like a slow heartbeat,
## shoving any fish beside it. Kinematic, so the motion depends only on the physics clock.

## Size factor at rest and at the top of a pulse.
const REST_SCALE: float = 1.0
const PEAK_SCALE: float = 1.45

## Seconds from one pulse to the next.
@export var period: float = 1.6
## Where in its cycle the bumper starts, as a fraction of the period.
@export_range(0.0, 1.0) var phase: float = 0.0

var clock: float = 0.0
## Shifts every bumper of a race by the same amount, drawn from the race seed.
var _offset: float = 0.0


func _ready() -> void:
	Replayable.join(self)
	_apply_scale()


## Called by [method Track.seed_gimmicks]: starts the pulse at a point that depends on the seed.
func reseed(seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	_offset = rng.randf()
	clock = 0.0
	_apply_scale()


## Size factor the bumper has at race time `t`: a quick swell, then a slow relax.
func scale_at(t: float) -> float:
	var cycle: float = fposmod(t / period + phase + _offset, 1.0)
	var swell: float = sin(PI * cycle / 0.3) if cycle < 0.3 else 0.0
	return lerpf(REST_SCALE, PEAK_SCALE, swell)


func _physics_process(delta: float) -> void:
	clock += delta
	_apply_scale()


func _apply_scale() -> void:
	scale = Vector2.ONE * scale_at(clock)


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([clock, _offset])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	clock = Replayable.mix(from, to, weight, 0)
	_offset = from[1]
	_apply_scale()
