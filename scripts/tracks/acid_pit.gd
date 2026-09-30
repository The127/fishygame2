class_name AcidPit
extends Area2D
## A pit of stomach acid in the floor, closed by a hatch (an AnimatableBody2D child named Lid).
## The hatch sinks into the acid for a moment every few seconds, so a fish crossing while it is
## down is lost and a fish crossing while it is up is safe: each fish's fate is its own timing.
## Any fish that touches the acid is dissolved at once and is out of the race (DNF), so nothing
## can ever get stuck in it. The fish leaves a skeleton that sinks into the pit. The Area2D's
## rectangle is the acid itself, from its surface down to the bottom of the basin (the walls are
## ordinary colliders in the map).
##
## Everything here runs on the pit's own race clock, so the hatch and the skeletons are part of
## the finish replay. A seed picks where in its cycle the hatch starts.

## A fish that dissolved. `body_entered` is not used: a fish can be shoved in any frame.
signal fish_dissolved(marble: Marble)
## A particle burst was let off, for the finish replay to play again.
signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)

## Most skeletons a pit keeps; a new one replaces the oldest.
const MAX_SKELETONS: int = 6
## Floats kept per skeleton in the replay state: x, y, time of death, facing.
const SKELETON_FLOATS: int = 4
## Seconds the skeleton takes to show through the fading fish.
const SKELETON_FADE_IN: float = 0.5
## Pixels a skeleton sinks, and how quickly it settles.
const SINK_DEPTH: float = 26.0
const SINK_RATE: float = 0.7
const BUBBLES: int = 12
const BONE: Color = Color(0.94, 0.92, 0.8)
## Seconds before the hatch opens that it starts to glow.
const WARNING_SECONDS: float = 0.8
## The hatch's stone color and the brightness of its lit edge.
const LID_COLOR: Color = Color(0.4, 0.13, 0.27)
const LID_RIM: Color = Color(1.0, 0.55, 0.85)

@export var tint: Color = Color(0.7, 1.0, 0.25)
## Seconds from one opening to the next.
@export var period: float = 7.0
## Seconds the hatch stays fully open, and seconds it takes to sink or rise.
@export var open_seconds: float = 1.0
@export var move_seconds: float = 0.35
## Pixels the hatch sinks.
@export var drop: float = 46.0

var _size: Vector2 = Vector2.ZERO
var _lid: AnimatableBody2D
var _lid_shape: PackedVector2Array = PackedVector2Array()
## Shifts the hatch's cycle, drawn from the race seed.
var _offset: float = 0.0
## Race seconds, advanced by the physics clock so the skeletons replay.
var _clock: float = 0.0
## Ambient time for the bubbles and ripples, kept moving under the replay too.
var _time: float = 0.0
## Skeleton slots, each `SKELETON_FLOATS` floats; a negative time of death means empty.
var _skeletons: PackedFloat32Array = PackedFloat32Array()
var _next_slot: int = 0


func _ready() -> void:
	Replayable.join(self)
	var shape: CollisionShape2D = get_node("CollisionShape2D") as CollisionShape2D
	_size = (shape.shape as RectangleShape2D).size
	_lid = get_node_or_null("Lid") as AnimatableBody2D
	if _lid != null:
		_lid_shape = (_lid.get_node("Collider") as CollisionPolygon2D).polygon
	_clear_skeletons()
	_move_lid()


## Called by [method Track.seed_gimmicks]: the hatch starts at a point of its cycle that depends on
## the seed.
func reseed(seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	_offset = rng.randf() * period
	_clock = 0.0
	_move_lid()


## How far the hatch is open at race time `t`, 0 (closed, flush with the floor) to 1 (sunk).
func openness_at(t: float) -> float:
	var cycle: float = fposmod(t + _offset, period)
	if cycle < move_seconds:
		return smoothstep(0.0, 1.0, cycle / move_seconds)
	if cycle < move_seconds + open_seconds:
		return 1.0
	if cycle < 2.0 * move_seconds + open_seconds:
		return 1.0 - smoothstep(0.0, 1.0, (cycle - move_seconds - open_seconds) / move_seconds)
	return 0.0


## How close the hatch is to opening at race time `t`, 0 to 1 (only while it is still closed).
func warning_at(t: float) -> float:
	var cycle: float = fposmod(t + _offset, period)
	var until_open: float = period - cycle
	if until_open > WARNING_SECONDS:
		return 0.0
	return 1.0 - until_open / WARNING_SECONDS


func _move_lid() -> void:
	if _lid != null:
		_lid.position = Vector2(0.0, drop * openness_at(_clock))


func _physics_process(delta: float) -> void:
	_clock += delta
	_move_lid()
	for body: Node2D in get_overlapping_bodies():
		if body is Marble:
			var marble: Marble = body as Marble
			if not marble.eaten and not marble.has_finished and not marble.freeze:
				_dissolve(marble)


## Called by [method Track.stop_gimmicks]: the pit is clean again.
func stop_gimmick() -> void:
	_clock = 0.0
	_offset = 0.0
	_clear_skeletons()
	_move_lid()
	queue_redraw()


## How many skeletons lie in the pit right now.
func skeleton_count() -> int:
	var count: int = 0
	for i: int in MAX_SKELETONS:
		if _skeletons[i * SKELETON_FLOATS + 2] >= 0.0:
			count += 1
	return count


func _dissolve(marble: Marble) -> void:
	var at: Vector2 = marble.global_position
	var facing: float = -1.0 if marble.linear_velocity.x < 0.0 else 1.0
	marble.dissolve()
	var local: Vector2 = to_local(at)
	# The fish may touch the acid with its edge only; its bones lie in the liquid.
	local.y = maxf(local.y, -_size.y * 0.5 + 6.0)
	var base: int = _next_slot * SKELETON_FLOATS
	_skeletons[base] = local.x
	_skeletons[base + 1] = local.y
	_skeletons[base + 2] = _clock
	_skeletons[base + 3] = facing
	_next_slot = (_next_slot + 1) % MAX_SKELETONS
	RaceFx.burst(self, at, Marble.ACID_COLOR, 22, 150.0, Vector2(0.0, 40.0))
	burst_played.emit(at, Marble.ACID_COLOR, 22, 150.0, Vector2(0.0, 40.0))
	fish_dissolved.emit(marble)
	queue_redraw()


func _clear_skeletons() -> void:
	_skeletons.resize(MAX_SKELETONS * SKELETON_FLOATS)
	_skeletons.fill(0.0)
	for i: int in MAX_SKELETONS:
		_skeletons[i * SKELETON_FLOATS + 2] = -1.0
	_next_slot = 0


## Part of the finish replay ([Replayable]): the clock, the cycle shift and every skeleton slot.
func replay_state() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array([_clock, _offset])
	state.append_array(_skeletons)
	return state


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_clock = Replayable.mix(from, to, weight, 0)
	_offset = from[1]
	for i: int in MAX_SKELETONS * SKELETON_FLOATS:
		_skeletons[i] = Replayable.step(from, to, weight, 2 + i)
	_move_lid()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var half: Vector2 = _size * 0.5
	var surface: float = -half.y
	# The liquid: bright at the surface, darker toward the bottom.
	var top_color: Color = Color(tint, 0.55)
	var bottom_color: Color = Color(tint.darkened(0.6), 0.85)
	var ripple: float = sin(_time * 2.4) * 1.5
	var wave: PackedVector2Array = PackedVector2Array()
	var steps: int = 10
	for i: int in steps + 1:
		var u: float = float(i) / float(steps)
		wave.append(Vector2(lerpf(-half.x, half.x, u), surface + sin(_time * 2.4 + u * 9.0) * 2.0))
	var body: PackedVector2Array = wave.duplicate()
	body.append(Vector2(half.x, half.y))
	body.append(Vector2(-half.x, half.y))
	var colors: PackedColorArray = PackedColorArray()
	for point: Vector2 in body:
		colors.append(top_color.lerp(bottom_color, clampf((point.y - surface) / _size.y, 0.0, 1.0)))
	draw_polygon(body, colors)
	# A soft glow above the surface and a bright line on it.
	var glow: PackedVector2Array = PackedVector2Array(
		[
			Vector2(-half.x, surface - 26.0),
			Vector2(half.x, surface - 26.0),
			Vector2(half.x, surface),
			Vector2(-half.x, surface)
		]
	)
	var clear: Color = Color(tint, 0.0)
	var lit: Color = Color(tint, 0.22 + ripple * 0.02)
	draw_polygon(glow, PackedColorArray([clear, clear, lit, lit]))
	draw_polyline(wave, Color(tint.lightened(0.4), 0.9), 2.0, true)
	for i: int in BUBBLES:
		var lane: float = fposmod(float(i) * 0.618034, 1.0)
		var rise: float = fposmod(_time * (0.18 + 0.2 * fposmod(float(i) * 0.37, 1.0)) + lane, 1.0)
		var at: Vector2 = Vector2((lane - 0.5) * _size.x * 0.8, half.y - rise * (_size.y - 4.0))
		var radius: float = 2.0 + 3.0 * fposmod(float(i) * 0.71, 1.0)
		draw_arc(
			at, radius, 0.0, TAU, 10, Color(tint.lightened(0.3), 0.8 * sin(PI * rise)), 1.5, true
		)
	_draw_lid()
	for i: int in MAX_SKELETONS:
		var base: int = i * SKELETON_FLOATS
		if _skeletons[base + 2] >= 0.0:
			_draw_skeleton(base)


## One skeleton, drawn from its slot: it shows through as the fish fades and settles slowly.
func _draw_skeleton(base: int) -> void:
	var age: float = maxf(_clock - _skeletons[base + 2], 0.0)
	var facing: float = _skeletons[base + 3]
	var alpha: float = clampf((age - 0.1) / SKELETON_FADE_IN, 0.0, 1.0) * 0.9
	var sink: float = SINK_DEPTH * (1.0 - exp(-age * SINK_RATE))
	var at: Vector2 = Vector2(_skeletons[base], _skeletons[base + 1] + sink)
	at.y = minf(at.y, _size.y * 0.5 - 10.0)
	var bone: Color = Color(BONE, alpha)
	var dark: Color = Color(0.05, 0.1, 0.0, alpha)
	# Spine, then ribs curving back from it.
	draw_line(at + Vector2(-16.0, 0.0) * facing, at + Vector2(9.0, 0.0) * facing, bone, 2.0, true)
	for i: int in 4:
		var x: float = (-9.0 + 5.0 * float(i)) * facing
		draw_line(at + Vector2(x, 0.0), at + Vector2(x - 3.0 * facing, -7.0), bone, 1.5, true)
		draw_line(at + Vector2(x, 0.0), at + Vector2(x - 3.0 * facing, 7.0), bone, 1.5, true)
	# Tail fork and the skull with its eye socket and jaw.
	draw_line(
		at + Vector2(-16.0, 0.0) * facing, at + Vector2(-25.0 * facing, -7.0), bone, 1.5, true
	)
	draw_line(at + Vector2(-16.0, 0.0) * facing, at + Vector2(-25.0 * facing, 7.0), bone, 1.5, true)
	var skull: Vector2 = at + Vector2(15.0 * facing, 0.0)
	draw_circle(skull, 6.5, bone)
	draw_circle(skull + Vector2(1.5 * facing, -1.5), 2.2, dark)
	draw_line(
		skull + Vector2(3.0 * facing, 3.0), skull + Vector2(9.0 * facing, 4.0), bone, 1.5, true
	)


## The hatch: a stone plate with slits that glow green shortly before it sinks.
func _draw_lid() -> void:
	if _lid == null or _lid_shape.size() < 3:
		return
	var glow: float = warning_at(_clock) * (0.6 + 0.4 * sin(_time * 14.0))
	var plate: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in _lid_shape:
		plate.append(point + _lid.position)
	var submerged: float = _lid.position.y / maxf(drop, 1.0)
	var stone: Color = LID_COLOR.lerp(Color(tint.darkened(0.4), 1.0), submerged * 0.6)
	draw_colored_polygon(plate, stone.lerp(Color(tint, 1.0), glow * 0.45))
	# Lit top edge, the first edge of the shape, and slits across the plate.
	draw_line(plate[0], plate[1], Color(LID_RIM, 0.75), 2.0, true)
	var slits: int = 5
	for i: int in slits:
		var u: float = (float(i) + 0.5) / float(slits)
		var top: Vector2 = plate[0].lerp(plate[1], u) + Vector2(0.0, 6.0)
		var bottom: Vector2 = plate[3].lerp(plate[2], u) - Vector2(0.0, 6.0)
		draw_line(top, bottom, Color(tint, 0.25 + 0.6 * glow), 2.0, true)
