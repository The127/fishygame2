class_name AnglerHazard
extends Hazard
## Anglerfish that lurk in the dark and hunt. An event picks one lair: the lure flares and the
## eye burns red while telegraphing, then the angler waits for a fish to swim into reach and
## lunges at it, swallowing the fish caught in its jaws. A swallowed fish is out of the race for
## a moment and is spat back out at an earlier point of the map. No fish is eaten twice in one
## race. The anglers are AnglerLure children, in the order of `spit_points`.

signal fish_eaten(marble: Marble)
signal fish_spat(marble: Marble)
## A particle burst was let off (bite, swallow, spit), for the finish replay to play again.
signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)

enum Stage { HUNT, LUNGE, HOLD, RETREAT }

const LUNGE_SECONDS: float = 0.28
const HOLD_SECONDS: float = 0.25
const RETREAT_SECONDS: float = 0.6
## Time a strike takes once it has started; the hunt ends this long before the event does.
const STRIKE_SECONDS: float = LUNGE_SECONDS + HOLD_SECONDS + RETREAT_SECONDS
## Fish this close to the mouth when the jaws snap shut are swallowed.
const BITE_RADIUS: float = 95.0
## Most fish one strike swallows.
const MAX_EATEN: int = 2
## Seconds a swallowed fish stays gone; later fish of the same bite wait a little longer.
const DIGEST_SECONDS: float = 1.8
const DIGEST_STAGGER: float = 0.35
## Fish spat out in quick succession come out side by side.
const SPIT_SLOTS: int = 4
const SPIT_SPACING: float = 30.0
const SIGHT_COLOR: Color = Color(1.0, 0.3, 0.3)
const EATEN_COLOR: Color = Color(1.0, 0.35, 0.3)

## How far from its mouth an angler notices a fish.
@export var sight_radius: float = 300.0
## Where the fish of each lair are spat out, in the same order as the lures.
@export var spit_points: PackedVector2Array = PackedVector2Array()
@export var spit_velocity: Vector2 = Vector2(70.0, -170.0)

var _lures: Array[AnglerLure] = []
var _homes: Array[Vector2] = []
var _mouths: Array[Vector2] = []
var _sights: Array[Area2D] = []
var _lair: int = -1
var _stage: Stage = Stage.HUNT
var _stage_time: float = 0.0
var _offset: Vector2 = Vector2.ZERO
## One entry per swallowed fish: its `marble`, the `lair` it is spat out of and the seconds `left`.
var _swallowed: Array[Dictionary] = []
var _spat: int = 0


func _ready() -> void:
	z_index = -25
	for child: Node in get_children():
		if child is AnglerLure:
			var lure: AnglerLure = child as AnglerLure
			_lures.append(lure)
			_homes.append(lure.position)
			_mouths.append(lure.transform * lure.mouth_position())
	for mouth: Vector2 in _mouths:
		var sight: Area2D = Area2D.new()
		var shape: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = sight_radius
		shape.shape = circle
		sight.add_child(shape)
		sight.position = mouth
		add_child(sight)
		_sights.append(sight)


func _process(_delta: float) -> void:
	# The lure and the sight ring animate on their own, outside the event phases.
	if _lair >= 0:
		queue_redraw()


func get_lair_count() -> int:
	return _lures.size()


## The lair hunting right now, or -1.
func get_active_lair() -> int:
	return _lair


## Fish currently held by an anglerfish.
func get_swallowed() -> Array[Marble]:
	var result: Array[Marble] = []
	for entry: Dictionary in _swallowed:
		result.append(entry["marble"] as Marble)
	return result


## Where a fish is spat out of `lair`, before the side-by-side offset.
func get_spit_point(lair: int) -> Vector2:
	if lair >= 0 and lair < spit_points.size():
		return spit_points[lair]
	return Vector2.ZERO


func tick(delta: float) -> void:
	super.tick(delta)
	_digest(delta)


func _replay_extra() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array([float(_lair), float(_stage), _stage_time])
	for lure: AnglerLure in _lures:
		state.append_array(lure.snapshot())
	return state


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_lair = int(Replayable.step(from, to, weight, REPLAY_BASE))
	_stage = int(Replayable.step(from, to, weight, REPLAY_BASE + 1)) as Stage
	_stage_time = Replayable.step(from, to, weight, REPLAY_BASE + 2)
	for i: int in _lures.size():
		var start: int = REPLAY_BASE + 3 + i * AnglerLure.SNAPSHOT_FLOATS
		_lures[i].show_snapshot(
			Replayable.blend(from, to, weight, start, AnglerLure.SNAPSHOT_FLOATS)
		)


func _begin_telegraph(rng_for_event: RandomNumberGenerator) -> void:
	if _lures.is_empty():
		return
	_lair = rng_for_event.randi_range(0, _lures.size() - 1)
	_stage = Stage.HUNT
	_stage_time = 0.0
	_offset = Vector2.ZERO


func _process_telegraph(_delta: float) -> void:
	if _lair < 0:
		return
	var lure: AnglerLure = _lures[_lair]
	lure.excite = phase_progress()
	lure.mouth_open = 0.3 * phase_progress() * (0.5 + 0.5 * sin(clock * 11.0))


func _begin_active() -> void:
	if _lair >= 0:
		_lures[_lair].excite = 1.0


func _process_active(delta: float) -> void:
	if _lair < 0:
		return
	var lure: AnglerLure = _lures[_lair]
	match _stage:
		Stage.HUNT:
			if phase_time <= active_seconds - STRIKE_SECONDS:
				var target: Marble = _pick_target()
				if target != null:
					_start_lunge(target)
			else:
				# Nothing came close: the angler gives up and its glow fades.
				lure.excite = maxf(lure.excite - delta * 2.0, 0.0)
				lure.mouth_open = 0.0
		Stage.LUNGE:
			_stage_time += delta
			var t: float = clampf(_stage_time / LUNGE_SECONDS, 0.0, 1.0)
			lure.position = _homes[_lair] + _offset * _ease_out(t)
			lure.mouth_open = clampf(t * 2.0, 0.0, 1.0)
			if _stage_time >= LUNGE_SECONDS:
				_bite()
				_stage = Stage.HOLD
				_stage_time = 0.0
		Stage.HOLD:
			_stage_time += delta
			lure.mouth_open = 1.0 - clampf(_stage_time / (HOLD_SECONDS * 0.5), 0.0, 1.0)
			if _stage_time >= HOLD_SECONDS:
				_stage = Stage.RETREAT
				_stage_time = 0.0
		Stage.RETREAT:
			_stage_time += delta
			var t: float = clampf(_stage_time / RETREAT_SECONDS, 0.0, 1.0)
			lure.position = _homes[_lair] + _offset * (1.0 - _ease_out(t))
			lure.excite = 1.0 - t


func _end_event() -> void:
	_rest_lures()
	_lair = -1
	_stage = Stage.HUNT


func _reset() -> void:
	_end_event()
	for entry: Dictionary in _swallowed:
		_spit(entry["marble"] as Marble, int(entry["lair"]))
	_swallowed.clear()
	_spat = 0


func _rest_lures() -> void:
	for i: int in _lures.size():
		_lures[i].position = _homes[i]
		_lures[i].excite = 0.0
		_lures[i].mouth_open = 0.0


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


func _can_eat(marble: Marble) -> bool:
	return not marble.eaten and not marble.has_finished and marble.times_eaten == 0


## The fish nearest to the hunting angler's mouth within its sight, or null.
func _pick_target() -> Marble:
	var mouth: Vector2 = to_global(_mouths[_lair])
	var best: Marble = null
	var best_distance: float = INF
	for body: Node2D in _sights[_lair].get_overlapping_bodies():
		var marble: Marble = body as Marble
		if marble == null or not _can_eat(marble):
			continue
		var distance: float = mouth.distance_squared_to(marble.global_position)
		if distance < best_distance or (distance == best_distance and marble.id < best.id):
			best = marble
			best_distance = distance
	return best


func _start_lunge(target: Marble) -> void:
	# Aims where the fish will be by the time the jaws arrive.
	var aim: Vector2 = to_local(target.global_position + target.linear_velocity * LUNGE_SECONDS)
	_offset = (aim - _mouths[_lair]).limit_length(sight_radius)
	_stage = Stage.LUNGE
	_stage_time = 0.0


func _bite() -> void:
	var lure: AnglerLure = _lures[_lair]
	var mouth: Vector2 = lure.to_global(lure.mouth_position())
	var victims: Array[Marble] = []
	for body: Node2D in _sights[_lair].get_overlapping_bodies():
		var marble: Marble = body as Marble
		if (
			marble != null
			and _can_eat(marble)
			and mouth.distance_to(marble.global_position) <= BITE_RADIUS
		):
			victims.append(marble)
	victims.sort_custom(
		func(a: Marble, b: Marble) -> bool:
			var da: float = mouth.distance_squared_to(a.global_position)
			var db: float = mouth.distance_squared_to(b.global_position)
			return da < db or (da == db and a.id < b.id)
	)
	_burst(mouth, lure.tint, 18, 170.0, Vector2.ZERO)
	for i: int in mini(victims.size(), MAX_EATEN):
		_swallow(victims[i], _lair)


func _swallow(marble: Marble, lair: int) -> void:
	_burst(marble.global_position, EATEN_COLOR, 26, 220.0, Vector2.ZERO)
	marble.swallow()
	(
		_swallowed
		. append(
			{
				"marble": marble,
				"lair": lair,
				"left": DIGEST_SECONDS + DIGEST_STAGGER * float(_swallowed.size()),
			}
		)
	)
	fish_eaten.emit(marble)


## Counts down the swallowed fish and spits each out when its time is up.
func _digest(delta: float) -> void:
	var i: int = 0
	while i < _swallowed.size():
		var entry: Dictionary = _swallowed[i]
		entry["left"] = float(entry["left"]) - delta
		if float(entry["left"]) <= 0.0:
			_swallowed.remove_at(i)
			_spit(entry["marble"] as Marble, int(entry["lair"]))
		else:
			i += 1


func _spit(marble: Marble, lair: int) -> void:
	if not is_instance_valid(marble) or not marble.is_inside_tree():
		return
	var slot: float = float(_spat % SPIT_SLOTS) - float(SPIT_SLOTS - 1) * 0.5
	_spat += 1
	var spot: Vector2 = to_global(get_spit_point(lair) + Vector2(slot * SPIT_SPACING, 0.0))
	marble.release(spot, spit_velocity + Vector2(slot * 20.0, 0.0))
	_burst(spot, EATEN_COLOR.lerp(Color.WHITE, 0.5), 22, 170.0, Vector2(0.0, 60.0))
	fish_spat.emit(marble)


func _burst(at: Vector2, color: Color, amount: int, speed: float, gravity: Vector2) -> void:
	RaceFx.burst(self, at, color, amount, speed, gravity)
	burst_played.emit(at, color, amount, speed, gravity)


func _draw() -> void:
	if _lair < 0 or phase == Phase.IDLE:
		return
	var strength: float = phase_progress() if phase == Phase.TELEGRAPH else 1.0
	if phase == Phase.ACTIVE and _stage == Stage.RETREAT:
		strength = 1.0 - clampf(_stage_time / RETREAT_SECONDS, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(clock * 8.0)
	var center: Vector2 = _mouths[_lair]
	draw_circle(center, sight_radius, Color(SIGHT_COLOR, 0.035 * strength))
	draw_arc(
		center,
		sight_radius,
		0.0,
		TAU,
		64,
		Color(SIGHT_COLOR, (0.1 + 0.25 * pulse) * strength),
		3.0,
		true
	)
