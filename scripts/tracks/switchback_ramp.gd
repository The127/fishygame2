class_name SwitchbackRamp
extends Node2D
## A long ramp that pivots about its middle (`Slab`, an AnimatableBody2D) and flips its slope.
## A hidden `Trigger` zone sits somewhere along the ramp: the first fish to enter it makes the slab
## shudder, then the slab swings to the opposite slope, so everything on it rolls back the way it
## came. After a hold it swings back. Every ramp flips at most [member max_flips] times a race and
## nothing flips after [constant HORIZON], so a fish can only ever be held back for a bounded time.
## The trigger position, the flip budget and the hold time come from the race seed.

enum Phase { REST, WARN, HOLD }

## Race seconds after which no more flips start and a reversed ramp settles forward for good.
const HORIZON: float = 45.0
## Seconds the slab shudders before a triggered flip.
const WARN_SECONDS: float = 0.55
## Seconds before a ramp that just swung back can be triggered again.
const COOLDOWN: float = 1.2
const HOLD_MIN: float = 1.6
const HOLD_MAX: float = 2.4
## Share of the ramp, measured from its entry end, in which the trigger can sit.
const TRIGGER_MIN: float = 0.3
const TRIGGER_MAX: float = 0.7
## Swing speed in radians per second.
const SWING_SPEED: float = 0.45
const FLASH_SECONDS: float = 0.7
const GLOW_COLOR: Color = Color(1.0, 0.85, 0.35)
const CHEVRON_SPACING: float = 210.0

## +1 when the ramp runs down toward +x at rest, -1 toward -x.
@export_enum("Right:1", "Left:-1") var direction: int = 1
@export var tilt_degrees: float = 9.0

var phase: Phase = Phase.REST
## Seconds in the current phase (or the cooldown while at rest).
var phase_time: float = 0.0
## True while the slab is tipped against its resting slope.
var reversed: bool = false
var flips_used: int = 0
## Seconds since the race started, advanced in the physics step.
var clock: float = 0.0
## Most flips this race and how long each lasts, drawn by [method arm].
var max_flips: int = 0
var hold_seconds: float = HOLD_MIN

var _armed: bool = false
var _forced: bool = false
var _alarm: float = 0.0
var _flash: float = 0.0
var _scroll: float = 0.0
var _half_length: float = 860.0
## Slope the slab has swung to, without the shudder.
var _swing: float = 0.0

@onready var _slab: AnimatableBody2D = $Slab
@onready var _trigger: Area2D = $Trigger


func _ready() -> void:
	Replayable.join(self)
	var polygon: PackedVector2Array = (_slab.get_node("Visual") as Polygon2D).polygon
	_half_length = absf(polygon[0].x)
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	_place_trigger(0.5)
	_swing = target_angle()
	_slab.rotation = _swing
	# Above the slab's own visual so the glow and chevrons read on top of it.
	z_index = 1


## Plans a race: the trigger position, the flip budget and the hold time, all from `seed_value`.
func arm(seed_value: int) -> void:
	disarm()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	_place_trigger(rng.randf_range(TRIGGER_MIN, TRIGGER_MAX))
	max_flips = rng.randi_range(1, 2)
	hold_seconds = rng.randf_range(HOLD_MIN, HOLD_MAX)
	_armed = true
	# The first fish to reach the zone needs no cooldown.
	phase_time = COOLDOWN


## Stops flipping and puts the ramp back at its resting slope.
func disarm() -> void:
	_armed = false
	_forced = false
	phase = Phase.REST
	phase_time = 0.0
	reversed = false
	flips_used = 0
	clock = 0.0
	max_flips = 0
	_alarm = 0.0
	_flash = 0.0
	if is_node_ready():
		_swing = target_angle()
		_slab.rotation = _swing
		_place_trigger(0.5)
	queue_redraw()


func is_armed() -> bool:
	return _armed


## Radians the slab should lie at: positive tips the +x end down.
func target_angle() -> float:
	var slope: float = deg_to_rad(tilt_degrees) * float(direction)
	return -slope if reversed or _forced else slope


## Makes the slab lie against its resting slope for as long as `on` holds (the backwash hazard).
func set_forced(on: bool) -> void:
	_forced = on
	if on:
		_flash = FLASH_SECONDS


## 0 to 1: how hard the slab shudders and glows as a hazard warns that it is about to tip.
func set_alarm(amount: float) -> void:
	_alarm = clampf(amount, 0.0, 1.0)


## Whether the slab lies against its resting slope right now, for any reason.
func is_tipped() -> bool:
	return reversed or _forced


## The zone's position along the ramp, 0 at the entry end and 1 at the exit end.
func trigger_share() -> float:
	var along: float = _trigger.position.x * float(direction)
	return (along + _half_length) / (2.0 * _half_length)


func _physics_process(delta: float) -> void:
	if _armed:
		clock += delta
		_advance(delta)
	_swing = move_toward(_swing, target_angle(), SWING_SPEED * delta)
	_slab.rotation = _swing + _shudder()
	_flash = maxf(_flash - delta, 0.0)
	_scroll += delta
	queue_redraw()


func _advance(delta: float) -> void:
	phase_time += delta
	match phase:
		Phase.REST:
			var open: bool = clock < HORIZON and flips_used < max_flips and phase_time >= COOLDOWN
			if open and _fish_in_trigger():
				phase = Phase.WARN
				phase_time = 0.0
		Phase.WARN:
			if phase_time >= WARN_SECONDS:
				phase = Phase.HOLD
				phase_time = 0.0
				reversed = true
				flips_used += 1
				_flash = FLASH_SECONDS
		Phase.HOLD:
			if phase_time >= hold_seconds or clock >= HORIZON:
				phase = Phase.REST
				phase_time = 0.0
				reversed = false
				_flash = FLASH_SECONDS


func _fish_in_trigger() -> bool:
	for body: Node2D in _trigger.get_overlapping_bodies():
		if body is Marble:
			return true
	return false


func _place_trigger(share: float) -> void:
	var along: float = (share * 2.0 - 1.0) * _half_length * float(direction)
	var slope: float = tan(deg_to_rad(tilt_degrees)) * float(direction)
	# Covers the stretch of air just above the resting slab at that point.
	_trigger.position = Vector2(along, slope * along - 55.0)


## Shudder of the slab before it tips, in radians.
func _shudder() -> float:
	var strength: float = 0.0
	if phase == Phase.WARN:
		strength = phase_time / WARN_SECONDS
	strength = maxf(strength, _alarm)
	return sin(_scroll * 70.0) * 0.012 * strength


func _draw() -> void:
	var glow: float = maxf(_flash / FLASH_SECONDS, _alarm)
	if phase == Phase.WARN:
		glow = maxf(glow, phase_time / WARN_SECONDS)
	# Chevrons point downhill, so a tipped ramp visibly turns them around.
	var downhill: float = signf(_swing)
	var fade: float = clampf(absf(_swing) / deg_to_rad(tilt_degrees), 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, _slab.rotation)
	var count: int = int(2.0 * _half_length / CHEVRON_SPACING)
	for i: int in count:
		var x: float = -_half_length + (float(i) + 0.5) * CHEVRON_SPACING
		var tip: Vector2 = Vector2(x + 14.0 * downhill, -22.0)
		var back: float = -14.0 * downhill
		var color: Color = Color(GLOW_COLOR, (0.07 + 0.3 * glow) * fade)
		draw_polyline(
			PackedVector2Array([tip + Vector2(back, -9.0), tip, tip + Vector2(back, 9.0)]),
			color,
			3.0,
			true
		)
	if glow > 0.0:
		var bar: Rect2 = Rect2(-_half_length, -12.0, _half_length * 2.0, 24.0)
		draw_rect(bar, Color(GLOW_COLOR, 0.25 * glow))
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array(
		[
			float(phase),
			phase_time,
			1.0 if reversed else 0.0,
			float(flips_used),
			_swing,
			clock,
			_flash,
			1.0 if _forced else 0.0,
			_alarm,
			_scroll,
			1.0 if _armed else 0.0,
		]
	)


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	phase = int(Replayable.step(from, to, weight, 0)) as Phase
	var blend: float = weight if from[0] == to[0] else roundf(weight)
	phase_time = lerpf(from[1], to[1], blend)
	reversed = Replayable.step(from, to, weight, 2) > 0.5
	flips_used = int(Replayable.step(from, to, weight, 3))
	_swing = Replayable.mix(from, to, weight, 4)
	clock = Replayable.mix(from, to, weight, 5)
	_flash = Replayable.mix(from, to, weight, 6)
	_forced = Replayable.step(from, to, weight, 7) > 0.5
	_alarm = Replayable.mix(from, to, weight, 8)
	_scroll = Replayable.mix(from, to, weight, 9)
	_armed = Replayable.step(from, to, weight, 10) > 0.5
	_slab.rotation = _swing + _shudder()
	queue_redraw()
