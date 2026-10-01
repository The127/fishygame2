class_name GravityFlipper
extends Node2D
## Turns gravity around the room at seeded, irregular intervals: down, up, toward the finish or
## away from it, so walls become floors and the ceiling becomes the floor. There is no countdown.
## The room tells instead: debris that was falling hangs still, gravity thins out to a weightless
## beat, the wall that is about to become the floor charges with light and then the room drops
## toward it. The flips are planned from the race seed in [method reseed], and time only advances
## in [method tick], so a seed replays the same flips.
## Children: `Zone` (Area2D that overrides gravity).

## Emitted when gravity turns. `pull` is the side of the room that is now the floor.
signal flipped(pull: Pull)

enum Pull { DOWN, UP, RIGHT, LEFT }

## Seconds between two flips, drawn per flip.
const MIN_INTERVAL: float = 2.8
const MAX_INTERVAL: float = 4.0
## Seconds before the first flip at the earliest and latest.
const FIRST_MIN: float = 3.0
const FIRST_MAX: float = 4.0
## Seconds of build-up before a flip: the room charges and gravity thins out.
const WARNING_SECONDS: float = 1.2
## Share of gravity left at the weightless beat just before a flip, and what it grows back from.
const WEIGHTLESS: float = 0.12
## Seconds gravity takes to come back to full strength after a flip.
const RETURN_SECONDS: float = 0.5
## Race seconds after which no more flips are planned.
const HORIZON: float = 120.0
## Seconds the wave that follows a flip takes to cross the room.
const FLASH_SECONDS: float = 0.8
## Relative odds of each side becoming the floor next. Away from the finish is the rare one.
const ODDS: Array[float] = [3.0, 3.0, 3.0, 0.6]
## Gravity strength per side. The pull away from the finish is weaker, so it is a setback
## rather than a disaster.
const STRENGTH: Array[float] = [1.0, 1.0, 1.0, 0.45]
## Sideways lean of the up and down pulls toward +x, and the downward lean of the pull away
## from the finish, so a fish is always eased toward the finish or toward a floor.
const LEAN: float = 0.2
const BACK_LEAN: float = 0.3
## Downward lean of the pull toward the finish, so a fish pressed against a wall rolls down it.
const FORWARD_LEAN: float = 0.25
## Looks of the debris that drifts about the room. Speed in pixels per second.
const BUBBLES: int = 30
const SHARDS: int = 26
const BUBBLE_SPEED: float = 60.0
const SHARD_SPEED: float = 46.0
## How fast the drift of the debris follows the gravity, in full reversals per second.
const DRIFT_EASE: float = 3.0
const GLOW_COLOR: Color = Color(0.62, 0.68, 1.0)
const CHARGE_COLOR: Color = Color(1.0, 0.86, 0.5)
## Thickness of the lit band along the wall that is about to become the floor.
const GLOW_DEPTH: float = 150.0

## Area the glow and the debris cover, in this node's space.
@export var bounds: Rect2 = Rect2(30.0, 70.0, 1860.0, 940.0)

## Which side of the room is the floor right now.
var pull: Pull = Pull.DOWN
## Which way a sideways pull leans: +1 toward the bottom of the room, -1 toward the top.
var lean: float = 1.0
## Seconds since the race started, advanced by [method tick].
var clock: float = 0.0

var _times: Array[float] = []
var _pulls: Array[int] = []
var _leans: Array[float] = []
var _next: int = 0
var _armed: bool = false
var _flash: float = 0.0
## Seconds since the last flip, capped at [constant RETURN_SECONDS] (for the return of gravity).
var _since_flip: float = RETURN_SECONDS
## Which way the debris drifts, eased toward where gravity is not pulling.
var _drift: Vector2 = Vector2.UP
var _scroll: Vector2 = Vector2.ZERO

@onready var _zone: Area2D = $Zone


func _ready() -> void:
	_zone.gravity_space_override = Area2D.SPACE_OVERRIDE_REPLACE
	_zone.gravity_point = false
	_apply()
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	Replayable.join(self)


## Direction gravity pulls toward when `side` is the floor (unit vector).
static func direction_of(side: Pull, lean_sign: float = 1.0) -> Vector2:
	match side:
		Pull.UP:
			return Vector2(LEAN, -1.0).normalized()
		Pull.RIGHT:
			return Vector2(1.0, FORWARD_LEAN * lean_sign).normalized()
		Pull.LEFT:
			return Vector2(-1.0, BACK_LEAN * lean_sign).normalized()
		_:
			return Vector2(LEAN, 1.0).normalized()


## Plans the flips of a race from `seed_value` and puts gravity back to down.
func reseed(seed_value: int) -> void:
	disarm()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var current: int = Pull.DOWN
	var t: float = rng.randf_range(FIRST_MIN, FIRST_MAX)
	while t < HORIZON:
		current = _draw_pull(rng, current)
		_times.append(t)
		_pulls.append(current)
		_leans.append(1.0 if rng.randf() < 0.5 else -1.0)
		t += rng.randf_range(MIN_INTERVAL, MAX_INTERVAL)
	_armed = true
	queue_redraw()


## Stops flipping and puts gravity back to down.
func disarm() -> void:
	_armed = false
	_times.clear()
	_pulls.clear()
	_leans.clear()
	_next = 0
	clock = 0.0
	_flash = 0.0
	_since_flip = RETURN_SECONDS
	pull = Pull.DOWN
	lean = 1.0
	_drift = -direction_of(pull)
	if is_node_ready():
		_apply()
	queue_redraw()


func is_armed() -> bool:
	return _armed


## Start times, in race seconds, of the planned flips.
func get_schedule() -> Array[float]:
	return _times.duplicate()


## Which side becomes the floor at each planned flip (values of [enum Pull]).
func get_pulls() -> Array[int]:
	return _pulls.duplicate()


## Side of the room that becomes the floor at the next flip, or the current one when none is left.
func next_pull() -> Pull:
	if _armed and _next < _pulls.size():
		return _pulls[_next] as Pull
	return pull


## 0 until the last [constant WARNING_SECONDS] before a flip, then rising to 1 at the flip.
func warning() -> float:
	if not _armed or _next >= _times.size():
		return 0.0
	return clampf(1.0 - (_times[_next] - clock) / WARNING_SECONDS, 0.0, 1.0)


## 1 at the moment of a flip, fading to 0.
func flash() -> float:
	return _flash / FLASH_SECONDS


## Share of full gravity that pulls right now: it thins to [constant WEIGHTLESS] as a flip
## nears and grows back in [constant RETURN_SECONDS] afterwards.
func weight() -> float:
	var thin: float = smoothstep(0.0, 1.0, warning())
	var back: float = smoothstep(0.0, 1.0, _since_flip / RETURN_SECONDS)
	return minf(lerpf(1.0, WEIGHTLESS, thin), lerpf(WEIGHTLESS, 1.0, back))


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not _armed:
		return
	clock += delta
	while _next < _times.size() and clock >= _times[_next]:
		var side: Pull = _pulls[_next] as Pull
		var new_lean: float = _leans[_next]
		_next += 1
		turn_to(side, new_lean)
	_flash = maxf(_flash - delta, 0.0)
	_since_flip = minf(_since_flip + delta, RETURN_SECONDS)
	# The debris hangs still while gravity thins out, then drifts away from the new floor.
	var target: Vector2 = -direction_of(pull, lean) * weight()
	_drift = _drift.move_toward(target, DRIFT_EASE * delta)
	_scroll += _drift * delta
	_apply_strength()
	if _since_flip < RETURN_SECONDS:
		_wake_bodies()
	queue_redraw()


## Turns gravity toward `side` right now.
func turn_to(side: Pull, lean_sign: float = 1.0) -> void:
	pull = side
	lean = lean_sign
	_flash = FLASH_SECONDS
	_since_flip = 0.0
	_apply()
	flipped.emit(side)


## Part of the finish replay ([Replayable]): which side is the floor, where the flip clock and
## the build-up stand, the wave, and the drift and scroll of the debris.
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array(
		[
			clock,
			float(_next),
			float(pull),
			lean,
			_flash,
			_since_flip,
			_drift.x,
			_drift.y,
			_scroll.x,
			_scroll.y,
			1.0 if _armed else 0.0
		]
	)


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, blend: float) -> void:
	clock = Replayable.mix(from, to, blend, 0)
	_next = int(Replayable.step(from, to, blend, 1))
	pull = int(Replayable.step(from, to, blend, 2)) as Pull
	lean = Replayable.step(from, to, blend, 3)
	_flash = Replayable.mix(from, to, blend, 4)
	_since_flip = Replayable.mix(from, to, blend, 5)
	_drift = Replayable.mix_vector(from, to, blend, 6)
	_scroll = Replayable.mix_vector(from, to, blend, 8)
	_armed = Replayable.step(from, to, blend, 10) > 0.5
	queue_redraw()


## After the replay the physics zone points the way gravity really does again.
func replay_end() -> void:
	_apply()
	queue_redraw()


func _draw_pull(rng: RandomNumberGenerator, current: int) -> int:
	var total: float = 0.0
	for side: int in ODDS.size():
		if side != current:
			total += ODDS[side]
	var roll: float = rng.randf() * total
	for side: int in ODDS.size():
		if side == current:
			continue
		roll -= ODDS[side]
		if roll <= 0.0:
			return side
	return (current + 1) % ODDS.size()


func _apply() -> void:
	_zone.gravity_direction = direction_of(pull, lean)
	_apply_strength()
	_wake_bodies()


## A fish resting against a wall is asleep, and a new gravity does not wake it. Gravity is thin
## for a moment after a flip, so a fish woken once falls asleep again before it gains speed
## (it keeps its rest time) and hangs there for good. Waking it on every frame until gravity is
## back to full lets it build up speed.
func _wake_bodies() -> void:
	for body: Node2D in _zone.get_overlapping_bodies():
		if body is RigidBody2D:
			(body as RigidBody2D).sleeping = false


func _apply_strength() -> void:
	var base: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	_zone.gravity = base * STRENGTH[pull] * weight()


func _draw() -> void:
	_draw_debris()
	if not _armed:
		return
	var charge: float = warning()
	if charge > 0.0:
		_draw_charge(next_pull(), charge)
	if _flash > 0.0:
		_draw_wave()


## A lit band along the wall that is about to become the floor, flickering faster as it fills.
func _draw_charge(side: Pull, charge: float) -> void:
	var flicker: float = 0.75 + 0.25 * sin(clock * (14.0 + 26.0 * charge))
	var alpha: float = charge * charge * flicker
	var core: Color = Color(CHARGE_COLOR, 0.42 * alpha)
	var faint: Color = Color(CHARGE_COLOR, 0.0)
	_draw_band(side, GLOW_DEPTH * (0.6 + 0.4 * charge), core, faint)
	_draw_band(side, 14.0, Color(CHARGE_COLOR, 0.8 * alpha), faint)


## The wave a flip sends out from the new floor to the opposite wall.
func _draw_wave() -> void:
	var travelled: float = 1.0 - flash()
	var normal: Vector2 = -direction_of(pull, lean)
	var span: float = absf(normal.x) * bounds.size.x + absf(normal.y) * bounds.size.y
	var front: float = travelled * (span + GLOW_DEPTH)
	var center: Vector2 = bounds.get_center()
	var axis: Vector2 = normal.normalized()
	# The wave is a soft stripe perpendicular to the direction of travel.
	var origin: Vector2 = center - axis * span * 0.5
	var tail: float = GLOW_DEPTH * 1.4
	var side: Vector2 = Vector2(-axis.y, axis.x) * (bounds.size.length())
	var a: Vector2 = origin + axis * (front - tail)
	var b: Vector2 = origin + axis * front
	var faint: Color = Color(GLOW_COLOR, 0.0)
	var strong: Color = Color(GLOW_COLOR, 0.3 * flash())
	var quad: PackedVector2Array = PackedVector2Array([a - side, a + side, b + side, b - side])
	draw_polygon(quad, PackedColorArray([faint, faint, strong, strong]))


## A gradient band `depth` deep along the wall that `side` is, bright at the wall.
func _draw_band(side: Pull, depth: float, at_wall: Color, away: Color) -> void:
	var rect: Rect2 = bounds
	var points: PackedVector2Array
	match side:
		Pull.UP:
			points = PackedVector2Array(
				[
					rect.position,
					Vector2(rect.end.x, rect.position.y),
					Vector2(rect.end.x, rect.position.y + depth),
					Vector2(rect.position.x, rect.position.y + depth)
				]
			)
		Pull.RIGHT:
			points = PackedVector2Array(
				[
					Vector2(rect.end.x, rect.position.y),
					rect.end,
					Vector2(rect.end.x - depth, rect.end.y),
					Vector2(rect.end.x - depth, rect.position.y)
				]
			)
		Pull.LEFT:
			points = PackedVector2Array(
				[
					rect.position,
					Vector2(rect.position.x, rect.end.y),
					Vector2(rect.position.x + depth, rect.end.y),
					Vector2(rect.position.x + depth, rect.position.y)
				]
			)
		_:
			points = PackedVector2Array(
				[
					Vector2(rect.position.x, rect.end.y),
					rect.end,
					Vector2(rect.end.x, rect.end.y - depth),
					Vector2(rect.position.x, rect.end.y - depth)
				]
			)
	draw_polygon(points, PackedColorArray([at_wall, at_wall, away, away]))


## Light bubbles drift away from the floor and heavy shards fall toward it. Both hang still
## while gravity thins out before a flip.
func _draw_debris() -> void:
	for i: int in BUBBLES:
		var lane: float = fposmod(float(i) * 0.618034, 1.0)
		var pace: float = 0.6 + 0.8 * fposmod(float(i) * 0.37, 1.0)
		var at: Vector2 = _wrap(
			Vector2(lane * bounds.size.x, fposmod(float(i) * 0.211, 1.0) * bounds.size.y),
			_scroll * BUBBLE_SPEED * pace,
			float(i)
		)
		var radius: float = 2.0 + 3.0 * fposmod(float(i) * 0.71, 1.0)
		draw_arc(at, radius, 0.0, TAU, 10, Color(GLOW_COLOR, 0.35), 1.5, true)
	for i: int in SHARDS:
		var lane: float = fposmod(float(i) * 0.7548777 + 0.3, 1.0)
		var pace: float = 0.6 + 0.8 * fposmod(float(i) * 0.53, 1.0)
		var at: Vector2 = _wrap(
			Vector2(lane * bounds.size.x, fposmod(float(i) * 0.3819, 1.0) * bounds.size.y),
			-_scroll * SHARD_SPEED * pace,
			float(i) + 50.0
		)
		var size: float = 3.0 + 4.0 * fposmod(float(i) * 0.43, 1.0)
		var turn: float = float(i) * 1.7 + clock * 0.4
		var tip: Vector2 = Vector2.from_angle(turn) * size
		var left: Vector2 = Vector2.from_angle(turn + 2.4) * size * 0.7
		var right: Vector2 = Vector2.from_angle(turn - 2.4) * size * 0.7
		draw_colored_polygon(
			PackedVector2Array([at + tip, at + left, at + right]), Color(GLOW_COLOR, 0.5)
		)


## A point of the debris field: `start` inside the bounds moved by `travelled`, wrapped round.
func _wrap(start: Vector2, travelled: Vector2, phase: float) -> Vector2:
	var x: float = fposmod(start.x + travelled.x + sin(clock * 1.1 + phase) * 8.0, bounds.size.x)
	var y: float = fposmod(start.y + travelled.y + cos(clock * 0.9 + phase) * 6.0, bounds.size.y)
	return bounds.position + Vector2(x, y)
