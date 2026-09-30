class_name Geyser
extends Node2D
## A vent that erupts on a timer. A column of hot water (an Area2D child named Column) throws
## every marble in it along the vent's upward axis, so a tilted vent throws them sideways too.
## Each cycle is quiet, then a telegraph of glow and bubbles, then the eruption. The phase and
## the period come from the race seed and time only advances in physics frames, so a seed
## replays the same eruptions. A vent that was never armed stays quiet.

enum Phase { QUIET, TELEGRAPH, ERUPT }

## Lift in pixels per second squared at full strength, on top of the gravity it beats.
const LIFT: float = 1500.0
## Seconds the lift takes to build up and die away.
const FADE: float = 0.25
## How far the period may stray from `period`, as a fraction.
const PERIOD_SPREAD: float = 0.2
const BUBBLES: int = 14
const VENT_WIDTH: float = 46.0
const MOUTH: float = VENT_WIDTH * 0.5

@export var period: float = 4.6
@export var telegraph_seconds: float = 0.9
@export var erupt_seconds: float = 1.1
@export var tint: Color = Color(1.0, 0.55, 0.2)

var clock: float = 0.0

var _column: Area2D
var _size: Vector2 = Vector2.ZERO
var _armed: bool = false
var _cycle: float = 0.0
var _offset: float = 0.0


func _ready() -> void:
	Replayable.join(self)
	_column = get_node("Column") as Area2D
	var shape: CollisionShape2D = _column.get_node("CollisionShape2D") as CollisionShape2D
	_size = (shape.shape as RectangleShape2D).size
	_cycle = period


## Picks this vent's phase and period for a race and starts its clock. Called by
## [method Track.seed_gimmicks], so it runs whatever the hazard setting is.
func reseed(seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	_cycle = period * rng.randf_range(1.0 - PERIOD_SPREAD, 1.0 + PERIOD_SPREAD)
	_cycle = maxf(_cycle, telegraph_seconds + erupt_seconds + 0.5)
	_offset = rng.randf_range(0.0, _cycle)
	clock = 0.0
	_armed = true
	queue_redraw()


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([clock, 1.0 if _armed else 0.0, _offset, _cycle])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	clock = Replayable.mix(from, to, weight, 0)
	_armed = Replayable.step(from, to, weight, 1) > 0.5
	_offset = from[2]
	_cycle = from[3]
	queue_redraw()


func disarm() -> void:
	_armed = false
	clock = 0.0
	queue_redraw()


func is_armed() -> bool:
	return _armed


## Seconds between two eruptions of this vent.
func get_cycle() -> float:
	return _cycle


## Unit vector the column throws marbles along, in world space.
func get_direction() -> Vector2:
	return -global_transform.y.normalized()


## True while the vent is throwing marbles.
func is_erupting() -> bool:
	return phase_at(clock) == Phase.ERUPT


## Where the vent is in its cycle at race time `t`. A vent that was never armed is quiet.
func phase_at(t: float) -> Phase:
	if not _armed:
		return Phase.QUIET
	var into: float = fposmod(t + _offset, _cycle)
	var start: float = _cycle - telegraph_seconds - erupt_seconds
	if into < start:
		return Phase.QUIET
	return Phase.TELEGRAPH if into < start + telegraph_seconds else Phase.ERUPT


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not _armed:
		return
	clock += delta
	if is_erupting():
		var erupt: float = _phase_time()
		var strength: float = clampf(minf(erupt, erupt_seconds - erupt) / FADE, 0.0, 1.0)
		var push: Vector2 = get_direction() * LIFT * strength
		for body: Node2D in _column.get_overlapping_bodies():
			if body is Marble:
				var marble: Marble = body as Marble
				marble.apply_central_force(push * marble.mass)
	queue_redraw()


## Seconds since the current phase began, or -1 while the vent is quiet.
func _phase_time() -> float:
	var into: float = fposmod(clock + _offset, _cycle)
	var start: float = _cycle - telegraph_seconds - erupt_seconds
	if into < start:
		return -1.0
	return into - start if into < start + telegraph_seconds else into - start - telegraph_seconds


func _draw() -> void:
	var alert: float = 0.25
	var phase: Phase = phase_at(clock)
	var into: float = _phase_time()
	if phase == Phase.TELEGRAPH:
		alert = 0.5 + 0.5 * sin(into * 14.0)
	elif phase == Phase.ERUPT:
		alert = 1.0
	# The glowing crack the water comes out of.
	draw_rect(Rect2(-MOUTH - 6.0, -3.0, VENT_WIDTH + 12.0, 6.0), Color(tint, 0.25 + 0.4 * alert))
	draw_rect(Rect2(-MOUTH, -2.0, VENT_WIDTH, 4.0), Color(1.0, 0.85, 0.5, 0.35 + 0.6 * alert))
	if phase == Phase.TELEGRAPH:
		_draw_bubbles(0.25 + 0.5 * into / telegraph_seconds, 0.3, 90.0)
	elif phase == Phase.ERUPT:
		var fade: float = clampf(minf(into, erupt_seconds - into) / FADE, 0.0, 1.0)
		_draw_column(fade)
		_draw_bubbles(1.0, fade, 620.0)


## The rising column of hot water: a soft fill with brighter edges.
func _draw_column(strength: float) -> void:
	var half: float = _size.x * 0.5
	var top: float = -_size.y
	var body: PackedVector2Array = PackedVector2Array(
		[Vector2(-MOUTH, 0.0), Vector2(-half, top), Vector2(half, top), Vector2(MOUTH, 0.0)]
	)
	var base_color: Color = Color(tint, 0.34 * strength)
	var top_color: Color = Color(tint, 0.0)
	draw_polygon(body, PackedColorArray([base_color, top_color, top_color, base_color]))
	draw_line(Vector2(-MOUTH, 0.0), Vector2(-half, top), Color(tint, 0.5 * strength), 2.0, true)
	draw_line(Vector2(MOUTH, 0.0), Vector2(half, top), Color(tint, 0.5 * strength), 2.0, true)


## Bubbles rising along the column. `height` is the fraction of the column they reach.
func _draw_bubbles(height: float, strength: float, speed: float) -> void:
	var reach: float = _size.y * height
	for i: int in BUBBLES:
		var lane: float = fposmod(float(i) * 0.618034, 1.0) - 0.5
		var pace: float = speed * (0.6 + 0.8 * fposmod(float(i) * 0.37, 1.0))
		var rise: float = fposmod(clock * pace + float(i) * 53.0, maxf(reach, 1.0))
		var spread: float = lerpf(MOUTH, _size.x * 0.5, rise / _size.y)
		var wobble: float = sin(clock * 5.0 + float(i) * 2.3) * 5.0
		var pos: Vector2 = Vector2(lane * 2.0 * spread * 0.8 + wobble, -rise)
		var fade: float = 1.0 - rise / maxf(reach, 1.0)
		var radius: float = 2.5 + 3.0 * fposmod(float(i) * 0.71, 1.0)
		draw_circle(pos, radius, Color(1.0, 0.85, 0.6, 0.5 * strength * fade))
		draw_arc(pos, radius, 0.0, TAU, 10, Color(tint, 0.8 * strength * fade), 1.5, true)
