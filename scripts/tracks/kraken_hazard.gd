class_name KrakenHazard
extends Hazard
## The kraken lashes out: one to three tentacles rise from the deep and sweep across the ramps,
## swatting every marble they touch sideways. The shove is a strong force from an Area2D rather
## than a solid body, so a marble caught in a sweep is flung along instead of being crushed
## against the deck. The telegraph shows the arc the tentacle will sweep, the tentacle
## starting to rise and the kraken's eye (a [KrakenEye] child) snapping open.

const SEGMENTS: int = 18
## Most tentacles one event uses.
const MAX_TENTACLES: int = 3
const BODY_RADIUS: float = 34.0
## The part of the tentacle that pushes, as fractions of its length from the root.
const PUSH_FROM: float = 0.3
## Shove along the swing, in pixels per second squared.
const PUSH: float = 1700.0
## Seconds the shove takes to build up when the sweep starts.
const RAMP_UP: float = 0.2
## Chance that an event uses two tentacles, and the chance that it uses three. The rest use one.
const DOUBLE_CHANCE: float = 0.4
const TRIPLE_CHANCE: float = 0.2
## How far open the eye is while it follows the leading fish between sweeps.
const WATCH_ALERT: float = 0.25
## How far behind the swing the tip trails, in radians.
const TIP_LAG: float = 0.3
const PARKED: Vector2 = Vector2(-10000.0, -10000.0)
const BURST_COLOR: Color = Color(0.7, 1.0, 0.5)

## Where each tentacle is rooted, below the frame. They rise straight up and swing about that.
@export var roots: PackedVector2Array = PackedVector2Array()
## Length of a tentacle in pixels.
@export var reach: float = 900.0
## Half the angle a tentacle swings through, in radians.
@export var half_arc: float = 0.5
@export var skin: Color = Color(0.2, 0.08, 0.3)
@export var glow: Color = Color(0.55, 1.0, 0.4)

var _areas: Array[Area2D] = []
var _eye: KrakenEye
var _lurkers: KrakenLurkers
var _sight: Area2D
## Where the leading fish is, in this node's coordinates. Zero when there is none.
var _leader: Vector2 = Vector2.ZERO
## Indices into `roots` of the tentacles in the current event, and each one's swing direction.
var _active: Array[int] = []
var _swing: Array[float] = []


func _ready() -> void:
	for i: int in roots.size():
		var area: Area2D = Area2D.new()
		var shape: CollisionShape2D = CollisionShape2D.new()
		var capsule: CapsuleShape2D = CapsuleShape2D.new()
		capsule.radius = BODY_RADIUS
		capsule.height = reach * (1.0 - PUSH_FROM)
		shape.shape = capsule
		area.add_child(shape)
		area.position = PARKED
		add_child(area)
		_areas.append(area)
	_eye = get_node_or_null("Eye") as KrakenEye
	_lurkers = get_node_or_null("Lurkers") as KrakenLurkers
	if _lurkers != null:
		_lurkers.setup(roots, reach, skin, glow)
	_sight = Area2D.new()
	var view: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(1920.0, 1080.0)
	view.shape = rect
	_sight.add_child(view)
	_sight.position = Vector2(960.0, 540.0)
	add_child(_sight)


## Indices of the tentacles in the current event, empty while idle.
func get_active_tentacles() -> Array[int]:
	return _active.duplicate()


## Replay: which tentacles are in the event and their swing directions, as MAX_TENTACLES slots
## of index (-1 for none) followed by MAX_TENTACLES slots of direction.
func _replay_extra() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array()
	state.resize(MAX_TENTACLES * 2)
	for n: int in MAX_TENTACLES:
		state[n] = float(_active[n]) if n < _active.size() else -1.0
		state[MAX_TENTACLES + n] = _swing[n] if n < _swing.size() else 0.0
	return state


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_active.clear()
	_swing.clear()
	for n: int in MAX_TENTACLES:
		var index: int = int(Replayable.step(from, to, weight, REPLAY_BASE + n))
		if index < 0 or index >= roots.size():
			continue
		_active.append(index)
		_swing.append(Replayable.step(from, to, weight, REPLAY_BASE + MAX_TENTACLES + n))


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	_active.clear()
	_swing.clear()
	if roots.is_empty():
		return
	var roll: float = rng.randf()
	var count: int = 1
	if roll < TRIPLE_CHANCE:
		count = 3
	elif roll < TRIPLE_CHANCE + DOUBLE_CHANCE:
		count = 2
	count = mini(count, mini(MAX_TENTACLES, roots.size()))
	var free: Array[int] = []
	for i: int in roots.size():
		free.append(i)
	for n: int in count:
		var pick: int = rng.randi_range(0, free.size() - 1)
		_active.append(free[pick])
		free.remove_at(pick)
		_swing.append(1.0 if rng.randf() < 0.5 else -1.0)
	_show_busy()


func _process_telegraph(_delta: float) -> void:
	_track_leader()
	_update_eye(phase_progress())


func _begin_active() -> void:
	for i: int in _active.size():
		var tip: Vector2 = _tip(_active[i], _angle(i, 0.0), 1.0)
		RaceFx.burst(self, tip, BURST_COLOR, 12, 140.0)


func _process_active(_delta: float) -> void:
	_track_leader()
	_update_eye(1.0)
	var progress: float = phase_progress()
	var strength: float = clampf(phase_time / RAMP_UP, 0.0, 1.0)
	for i: int in _active.size():
		var angle: float = _angle(i, progress)
		var area: Area2D = _areas[_active[i]]
		var root: Vector2 = roots[_active[i]]
		var middle: float = reach * (PUSH_FROM + 1.0) * 0.5
		area.position = root + Vector2.from_angle(angle) * middle
		area.rotation = angle + PI * 0.5
		var swing: Vector2 = Vector2(-sin(angle), cos(angle)) * _swing[i]
		for body: Node2D in area.get_overlapping_bodies():
			if body is Marble:
				var marble: Marble = body as Marble
				marble.apply_central_force(swing * PUSH * strength * marble.mass)


func _end_event() -> void:
	_park()
	_update_eye(0.0)
	queue_redraw()


func _reset() -> void:
	_park()
	_leader = Vector2.ZERO
	_update_eye(0.0)
	queue_redraw()


## Between sweeps the eye follows the leading fish.
func tick(delta: float) -> void:
	super.tick(delta)
	if is_armed() and phase == Phase.IDLE:
		_track_leader()
		_update_eye(0.0)


## The fish furthest along the ramps. They descend the whole way, so that is the lowest one.
func _track_leader() -> void:
	var best: Marble = null
	for body: Node2D in _sight.get_overlapping_bodies():
		var marble: Marble = body as Marble
		if marble == null or marble.is_out():
			continue
		if best == null or marble.global_position.y > best.global_position.y:
			best = marble
	_leader = to_local(best.global_position) if best != null else Vector2.ZERO


func _park() -> void:
	for area: Area2D in _areas:
		area.position = PARKED
	_active.clear()
	_swing.clear()
	_show_busy()


func _show_busy() -> void:
	if _lurkers != null:
		_lurkers.set_busy(_active)


func _update_eye(alert: float) -> void:
	if _eye == null:
		return
	var look: Vector2 = _leader
	if not _active.is_empty():
		look = _tip(_active[0], _angle(0, phase_progress() if phase == Phase.ACTIVE else 0.0), 1.0)
	if _active.is_empty() and look != Vector2.ZERO:
		alert = maxf(alert, WATCH_ALERT)
	_eye.set_alert(alert, look)


## Angle of the nth active tentacle at `progress` of the sweep. Straight up is -PI / 2.
func _angle(n: int, progress: float) -> float:
	return -PI * 0.5 + _swing[n] * half_arc * (2.0 * progress - 1.0)


func _tip(index: int, angle: float, length_fraction: float) -> Vector2:
	return roots[index] + Vector2.from_angle(angle) * reach * length_fraction


func _draw() -> void:
	if _active.is_empty() or phase == Phase.IDLE:
		return
	for i: int in _active.size():
		var index: int = _active[i]
		if phase == Phase.TELEGRAPH:
			_draw_arc_warning(index)
			var rise: float = phase_progress()
			_draw_tentacle(index, _angle(i, 0.0), 0.15 + 0.4 * rise, 0.25 + 0.5 * rise, 0.0)
		else:
			var lag: float = TIP_LAG * _swing[i] * sin(PI * phase_progress())
			var alpha: float = clampf(
				minf(phase_time, active_seconds - phase_time) / 0.25, 0.0, 1.0
			)
			_draw_tentacle(index, _angle(i, phase_progress()), 1.0, alpha, lag)


## A dashed line along the tip's path, plus a ring on each end.
func _draw_arc_warning(index: int) -> void:
	var pulse: float = 0.5 + 0.5 * sin(clock * 10.0)
	var center: float = -PI * 0.5
	var color: Color = Color(glow, 0.2 + 0.3 * pulse)
	draw_arc(roots[index], reach, center - half_arc, center + half_arc, 40, color, 4.0, true)
	for edge: float in [-1.0, 1.0]:
		var at: Vector2 = _tip(index, center + edge * half_arc, 1.0)
		draw_circle(at, 12.0 + 6.0 * pulse, Color(glow, 0.25))


## `lag` bends the tentacle backwards along its swing, so the tip trails the base.
func _draw_tentacle(
	index: int, angle: float, length_fraction: float, alpha: float, lag: float
) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var heading_now: float = angle
	var position_now: Vector2 = roots[index]
	var step: float = reach * length_fraction / float(SEGMENTS)
	points.append(position_now)
	for i: int in SEGMENTS:
		var s: float = float(i + 1) / float(SEGMENTS)
		var wave: float = sin(clock * 8.0 - s * 6.0) * 0.16 * s
		heading_now = angle - lag * s * s + wave
		position_now += Vector2.from_angle(heading_now) * step
		points.append(position_now)
	for i: int in SEGMENTS:
		var s: float = float(i) / float(SEGMENTS)
		var width: float = lerpf(BODY_RADIUS * 2.0, 6.0, pow(s, 0.85))
		draw_line(points[i], points[i + 1], Color(glow, 0.22 * alpha), width + 14.0, true)
		draw_line(points[i], points[i + 1], Color(skin, alpha), width, true)
		var side: Vector2 = (points[i + 1] - points[i]).orthogonal().normalized()
		var lit: Vector2 = side * width * 0.32
		draw_line(points[i] + lit, points[i + 1] + lit, Color(glow, 0.7 * alpha), 2.5, true)
		if i % 2 == 1 and s > 0.25:
			var sucker: Vector2 = points[i] - side * width * 0.2
			draw_circle(sucker, maxf(width * 0.13, 2.0), Color(glow, 0.55 * alpha))
