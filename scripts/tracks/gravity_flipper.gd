class_name GravityFlipper
extends Node2D
## Turns gravity around the room: down, up, toward the finish or away from it, so walls become
## floors and the ceiling becomes the floor. Chat steers it: each viewer's latest "#up", "#down",
## "#left" or "#right" is a vote ([method vote]), and the side with the most live votes becomes
## the floor once the room has had [constant MIN_DWELL] seconds to settle. When chat is quiet the
## room turns by itself, at seeded and irregular intervals. There is no countdown. The room tells
## instead: debris that was falling hangs still, gravity thins out to a weightless beat, the wall
## that is about to become the floor charges with light and then the room drops toward it. The
## autopilot flips are planned from the race seed in [method reseed], and time only advances in
## [method tick], so a seed replays the same flips when nobody votes.
## Children: `Zone` (Area2D that overrides gravity).

## Emitted when gravity turns. `pull` is the side of the room that is now the floor.
signal flipped(pull: Pull)
## The chat tally changed. Empty text hides it.
signal tally_changed(text: String)

enum Pull { DOWN, UP, RIGHT, LEFT }

## Group of the flipper on the map in play: the game calls [method vote] on it for chat presses.
const CHAT_GROUP: StringName = &"chat_gravity"
## Seconds a vote counts for. A viewer's newer vote replaces the older one.
const VOTE_WINDOW: float = 7.0
## Seconds after a turn before chat can turn gravity again, so a pull is something fish can use.
const MIN_DWELL: float = 2.5
## Seconds of build-up before a turn chat asked for.
const CHAT_BUILD: float = 0.4
## Seconds the fish furthest behind may go without gaining [constant STALL_PROGRESS] pixels
## before the sea takes the wheel from chat for [constant LOCKOUT_SECONDS], so a chat that
## fights over the helm (or trolls it) cannot trap a fish for the whole race. Every lockout of a
## race lasts twice as long as the one before, up to [constant LOCKOUT_MAX].
const STALL_SECONDS: float = 12.0
const STALL_PROGRESS: float = 60.0
const LOCKOUT_SECONDS: float = 8.0
const LOCKOUT_MAX: float = 64.0
## Race seconds after which chat loses the helm for good, so no race outlasts the time limit
## because of the votes.
const CHAT_CUTOFF: float = 60.0
## Seconds between looks at where the fish are.
const STALL_CHECK: float = 0.5
## Names of the sides as chat types them, in [enum Pull] order.
const COMMANDS: PackedStringArray = ["down", "up", "right", "left"]

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
## Live votes, oldest first: one per viewer, with the side and the clock time of the vote.
var _vote_names: PackedStringArray = PackedStringArray()
var _vote_sides: PackedInt32Array = PackedInt32Array()
var _vote_times: PackedFloat32Array = PackedFloat32Array()
## Seconds since gravity last turned, capped at [constant MIN_DWELL].
var _dwell: float = MIN_DWELL
## Side chat asked for that the room is charging toward, or -1, and for how long.
var _pending: int = -1
var _pending_time: float = 0.0
var _chat_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_text: String = ""
## Furthest x the rearmost fish has reached, and for how long it has made no progress.
var _rear_best: float = -INF
var _stall_time: float = 0.0
var _stall_check_in: float = 0.0
## Seconds chat is locked out of the helm, after a stall.
var _lockout: float = 0.0
var _lockouts: int = 0

@onready var _zone: Area2D = $Zone


func _ready() -> void:
	add_to_group(CHAT_GROUP)
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
	_chat_rng.seed = seed_value + 1
	var current: int = Pull.DOWN
	var t: float = rng.randf_range(FIRST_MIN, FIRST_MAX)
	while t < HORIZON:
		current = _draw_pull(rng, current)
		_times.append(t)
		_pulls.append(current)
		_leans.append(1.0 if rng.randf() < 0.5 else -1.0)
		t += rng.randf_range(MIN_INTERVAL, MAX_INTERVAL)
	_armed = true
	_emit_tally()
	queue_redraw()


## Stops flipping and puts gravity back to down.
func disarm() -> void:
	var was_armed: bool = _armed
	_armed = false
	_vote_names = PackedStringArray()
	_vote_sides = PackedInt32Array()
	_vote_times = PackedFloat32Array()
	_dwell = MIN_DWELL
	_pending = -1
	_pending_time = 0.0
	_rear_best = -INF
	_stall_time = 0.0
	_stall_check_in = 0.0
	_lockout = 0.0
	_lockouts = 0
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
	if was_armed:
		tally_changed.emit("")
	_last_text = ""
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
	if _pending >= 0:
		return _pending as Pull
	if _armed and _next < _pulls.size():
		return _pulls[_next] as Pull
	return pull


## 0 until the last [constant WARNING_SECONDS] before a flip, then rising to 1 at the flip.
func warning() -> float:
	if _pending >= 0:
		return clampf(_pending_time / CHAT_BUILD, 0.0, 1.0)
	if not _armed or _next >= _times.size() or is_chat_live():
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
	_dwell = minf(_dwell + delta, MIN_DWELL)
	_watch_stall(delta)
	_prune_votes()
	_follow_chat(delta)
	# While chat holds the helm the planned flips pass by unused.
	while _next < _times.size() and clock >= _times[_next]:
		var side: Pull = _pulls[_next] as Pull
		var new_lean: float = _leans[_next]
		_next += 1
		if not is_chat_live():
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
	_emit_tally()
	queue_redraw()


## A viewer typed "#up", "#down", "#left" or "#right": `side` is the floor they want. Their
## newest vote replaces their older one. Returns whether the vote counted.
func vote(side: Pull, who: String) -> bool:
	if not _armed or _lockout > 0.0:
		return false
	var old: int = _vote_names.find(who)
	if old >= 0:
		_vote_names.remove_at(old)
		_vote_sides.remove_at(old)
		_vote_times.remove_at(old)
	_vote_names.append(who)
	_vote_sides.append(side)
	_vote_times.append(clock)
	_emit_tally()
	queue_redraw()
	return true


## Live votes per side, in [enum Pull] order.
func vote_counts() -> PackedInt32Array:
	var counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for side: int in _vote_sides:
		counts[side] += 1
	return counts


## True while chat holds the helm: there are live votes, or a turn chat asked for is charging.
func is_chat_live() -> bool:
	return _pending >= 0 or not _vote_names.is_empty()


## The side chat wants as the floor, or -1 without votes. Ties keep the current floor, else the
## side voted for most recently wins.
func leading_side() -> int:
	var counts: PackedInt32Array = vote_counts()
	var best: int = 0
	for count: int in counts:
		best = maxi(best, count)
	if best == 0:
		return -1
	if counts[pull] == best:
		return pull
	for i: int in range(_vote_sides.size() - 1, -1, -1):
		if counts[_vote_sides[i]] == best:
			return _vote_sides[i]
	return -1


## Text of the on-screen tally: the votes per side, the leader in brackets.
func tally_text() -> String:
	if not _armed:
		return ""
	if _lockout > 0.0:
		return "THE SEA TAKES THE WHEEL"
	if _vote_names.is_empty():
		return "STEER THE SEA   #up   #down   #left   #right"
	var counts: PackedInt32Array = vote_counts()
	var lead: int = leading_side()
	var parts: PackedStringArray = PackedStringArray()
	for side: int in [Pull.UP, Pull.LEFT, Pull.DOWN, Pull.RIGHT]:
		var part: String = "#%s %d" % [COMMANDS[side], counts[side]]
		parts.append("[%s]" % part if side == lead else part)
	return "GRAVITY   " + "   ".join(parts)


## Chat's turn: after the room has settled, charge toward the side with the most votes and
## turn when the charge is full. The charge follows the leader and gives up if the vote falls
## back to the current floor.
func _follow_chat(delta: float) -> void:
	var lead: int = leading_side()
	if _pending >= 0:
		if lead < 0 or lead == pull:
			_pending = -1
			_pending_time = 0.0
			return
		_pending = lead
		_pending_time += delta
		if _pending_time >= CHAT_BUILD:
			turn_to(lead as Pull, 1.0 if _chat_rng.randf() < 0.5 else -1.0)
		return
	if _dwell >= MIN_DWELL and lead >= 0 and lead != pull:
		_pending = lead
		_pending_time = 0.0


## True while the sea has taken the wheel from chat.
func is_locked_out() -> bool:
	return _lockout > 0.0


## Looks at the fish furthest behind: if it has gone [constant STALL_SECONDS] without getting
## anywhere, chat loses the helm for [constant LOCKOUT_SECONDS] and the autopilot flips instead.
func _watch_stall(delta: float) -> void:
	if _lockout > 0.0:
		_lockout = maxf(_lockout - delta, 0.0)
		if _lockout == 0.0:
			_rear_best = -INF
			_stall_time = 0.0
		return
	if clock >= CHAT_CUTOFF:
		_start_lockout()
		_lockout = INF
		return
	_stall_time += delta
	_stall_check_in -= delta
	if _stall_check_in > 0.0:
		return
	_stall_check_in = STALL_CHECK
	var rear: float = INF
	for node: Node in get_tree().get_nodes_in_group(Marble.GROUP):
		var fish: Marble = node as Marble
		if fish.eaten or fish.has_finished or fish.is_out():
			continue
		rear = minf(rear, fish.global_position.x)
	if rear == INF or rear > _rear_best + STALL_PROGRESS:
		_rear_best = rear if rear != INF else -INF
		_stall_time = 0.0
	elif _stall_time >= STALL_SECONDS:
		_start_lockout()


func _start_lockout() -> void:
	_lockout = minf(LOCKOUT_SECONDS * pow(2.0, float(_lockouts)), LOCKOUT_MAX)
	_lockouts += 1
	_stall_time = 0.0
	_vote_names = PackedStringArray()
	_vote_sides = PackedInt32Array()
	_vote_times = PackedFloat32Array()
	_pending = -1
	_pending_time = 0.0
	_emit_tally()


func _prune_votes() -> void:
	while not _vote_times.is_empty() and clock - _vote_times[0] > VOTE_WINDOW:
		_vote_names.remove_at(0)
		_vote_sides.remove_at(0)
		_vote_times.remove_at(0)


func _emit_tally() -> void:
	var text: String = tally_text()
	if text != _last_text:
		_last_text = text
		tally_changed.emit(text)


## Turns gravity toward `side` right now.
func turn_to(side: Pull, lean_sign: float = 1.0) -> void:
	pull = side
	lean = lean_sign
	_flash = FLASH_SECONDS
	_since_flip = 0.0
	_dwell = 0.0
	_pending = -1
	_pending_time = 0.0
	_apply()
	flipped.emit(side)


## Part of the finish replay ([Replayable]): which side is the floor, where the flip clock and
## the build-up (including a turn chat asked for) stand, the wave, and the drift and scroll of
## the debris. The votes are not replayed.
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
			1.0 if _armed else 0.0,
			float(_pending),
			_pending_time,
			_dwell
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
	_pending = int(Replayable.step(from, to, blend, 11))
	_pending_time = Replayable.mix(from, to, blend, 12)
	_dwell = Replayable.mix(from, to, blend, 13)
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
	_draw_votes()
	var charge: float = warning()
	if charge > 0.0:
		_draw_charge(next_pull(), charge)
	if _flash > 0.0:
		_draw_wave()


## A band along each wall that has votes, deeper the bigger its share of the votes, and brightest
## on the side chat is leading with.
func _draw_votes() -> void:
	if _vote_names.is_empty():
		return
	var counts: PackedInt32Array = vote_counts()
	var lead: int = leading_side()
	for side: int in counts.size():
		if counts[side] == 0:
			continue
		var share: float = float(counts[side]) / float(_vote_names.size())
		var alpha: float = 0.16 + 0.22 * share + (0.14 if side == lead else 0.0)
		_draw_band(
			side as Pull, 24.0 + 80.0 * share, Color(GLOW_COLOR, alpha), Color(GLOW_COLOR, 0.0)
		)


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
