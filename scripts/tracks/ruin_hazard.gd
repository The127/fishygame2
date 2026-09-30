class_name RuinHazard
extends Hazard
## Ruined towers give way as the fish come. Every ruin has an invisible trigger zone (an Area2D
## named `Trigger`) on the lane just upstream of it: the first fish to enter it sets the ruin off,
## so things only change where and when the field actually arrives. The tower shakes and lets dust
## fall (the telegraph), then topples, shoving fish caught in its sweep (an Area2D named `Sweep`),
## and crashes. The crash changes the floor for good, until the race is over:
## - an "open" ruin (metadata `mode`) has a cap stone in the floor. It crumbles away and leaves a
##   gap, a shortcut to the lane below.
## - a "close" ruin starts with that gap open and a slab hanging above it. The slab drops into
##   the gap and seals it, so fish stay on the long way round.
## - a "topple" ruin has no gap. The tower shatters on the lane and leaves a heap of rubble (the
##   slab, scenery only: a fish at rest cannot climb any step, so nothing on a lane may block it).
## Every child is a ruin: a Node2D with a `Tower` (the scenery that topples, `lie_degrees` and
## `height` metadata), a `Slab` (AnimatableBody2D with a `Collider` and a `Visual`) and, on
## "close" ruins, `hang_height` and `hang_degrees` metadata plus `Chains` (Line2D children). The
## ruin sits at the gap and the slab's own position is where it lies when the gap is sealed.
## Ruins run independently, so several can be coming down at once. The race seed only decides
## which ruins are live in a race and how long each one hesitates after its trigger.

## A burst of dust or debris: what [method RaceFx.burst] was given, so the finish replay can play
## the same burst.
signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)

enum Stage { STANDING, TELEGRAPH, TOPPLE, FALLEN }

## Seconds the tower takes to fall, from the start of the topple.
const TOPPLE_SECONDS: float = 1.0
## Seconds a cap stone takes to crumble away after the crash.
const CRUMBLE_SECONDS: float = 0.7
## Seconds a hanging slab takes to drop into its gap after the crash.
const DROP_SECONDS: float = 0.45
## Seconds the rubble of a toppled tower takes to heap up after the crash.
const RUBBLE_SECONDS: float = 0.5
## How far a crumbling cap stone sinks, in pixels.
const CRUMBLE_DROP: float = 150.0
## How deep the rubble heap of a "topple" ruin starts under the lane, in pixels.
const RUBBLE_SINK: float = 40.0
## Most the telegraph of a ruin is stretched by, drawn from the seed (seconds).
const HESITATION: float = 0.4
## Velocity a falling tower gives a fish in its sweep, per second, at full speed.
const KNOCK_SPEED: float = 700.0
## Velocity of the shock a crash gives fish near the tower's tip, and how far it reaches.
const SHOCK_SPEED: float = 260.0
const SHOCK_RADIUS: float = 130.0
## Chance a ruin is live in a race: `BASE_LIVE` plus `LIVE_PER_LEVEL` for every hazard level.
const BASE_LIVE: float = 0.2
const LIVE_PER_LEVEL: float = 0.2
const SHAKE_ANGLE: float = deg_to_rad(1.4)
const DUST_INTERVAL: float = 0.4
const RIM_COLOR: Color = Color(1.0, 0.78, 0.42)
const DUST_COLOR: Color = Color(0.55, 0.62, 0.78)
const RUBBLE_COLOR: Color = Color(0.75, 0.68, 0.55)

var _ruins: Array[Node2D] = []
var _towers: Array[Node2D] = []
var _slabs: Array[AnimatableBody2D] = []
var _colliders: Array[CollisionPolygon2D] = []
var _triggers: Array[Area2D] = []
var _sweeps: Array[Area2D] = []
var _cracks: Array[Line2D] = []
var _chains: Array[Array] = []
## Per ruin: "open", "close" or "topple".
var _modes: Array[String] = []
## Per ruin: how far its tower has fallen (0 standing, 1 lying), how strongly its runes glow
## and how far its slab has gone from where it started to where it ends up.
var _tower_fall: PackedFloat32Array = PackedFloat32Array()
var _glow: PackedFloat32Array = PackedFloat32Array()
var _slab_move: PackedFloat32Array = PackedFloat32Array()
## Per ruin: where it is in its fall, for how long, whether this race can set it off at all, how
## much longer than usual it hesitates, and whether its crash has happened.
var _stage: Array[int] = []
var _stage_time: PackedFloat32Array = PackedFloat32Array()
var _live: Array[bool] = []
var _hesitation: PackedFloat32Array = PackedFloat32Array()
var _crashed: Array[bool] = []
var _dust_timer: PackedFloat32Array = PackedFloat32Array()
## Whether each slab's collider is switched on, as last asked for.
var _collider_on: Array[bool] = []
## Set when every ruin must be posed again: an AnimatableBody2D only takes a new transform inside
## a physics frame, and ruins are put back from anywhere (arming, disarming, the end of a replay).
var _repose: bool = true


func _ready() -> void:
	for child: Node in get_children():
		var slab: AnimatableBody2D = child.get_node_or_null("Slab") as AnimatableBody2D
		if slab == null:
			continue
		var i: int = _ruins.size()
		_ruins.append(child as Node2D)
		_towers.append(child.get_node("Tower") as Node2D)
		_slabs.append(slab)
		_colliders.append(slab.get_node_or_null("Collider") as CollisionPolygon2D)
		_triggers.append(child.get_node_or_null("Trigger") as Area2D)
		_sweeps.append(child.get_node_or_null("Sweep") as Area2D)
		_modes.append(String(child.get_meta("mode", "open")))
		var chains: Array = []
		var chain_root: Node = child.get_node_or_null("Chains")
		if chain_root != null:
			chains = chain_root.get_children()
		_chains.append(chains)
		_cracks.append(_add_rim(slab, _modes[i] == "open"))
		_tower_fall.append(0.0)
		_glow.append(0.0)
		_slab_move.append(0.0)
		_stage.append(Stage.STANDING)
		_stage_time.append(0.0)
		_live.append(false)
		_hesitation.append(0.0)
		_crashed.append(false)
		_dust_timer.append(0.0)
		_collider_on.append(true)
	for i: int in _ruins.size():
		_pose(i)


## Decides which ruins a race can set off, from the seed. Every ruin draws its values whether or
## not it is live, so a ruin's hesitation does not depend on the others. A hazard level of 0 or
## less arms nothing.
func arm(seed_value: int, frequency: int) -> void:
	disarm()
	if frequency <= 0:
		return
	_rng.seed = seed_value
	var chance: float = BASE_LIVE + LIVE_PER_LEVEL * float(frequency)
	for i: int in _ruins.size():
		_live[i] = _rng.randf() < chance
		_hesitation[i] = _rng.randf_range(0.0, HESITATION)
	_armed = true


## Ruins are set off by fish, not by a plan.
func is_scheduled() -> bool:
	return false


## Every ruin runs on its own. The base class's single event clock only keeps time and reports the
## busiest stage, for the signals and the replay.
func tick(delta: float) -> void:
	if not _armed:
		return
	clock += delta
	var before: Phase = phase
	for i: int in _ruins.size():
		if _stage[i] == Stage.STANDING and _live[i] and _fish_in_trigger(i):
			trigger(i)
		_advance(i, delta)
	_sync_phase(before, delta)
	if phase != Phase.IDLE:
		queue_redraw()


func _physics_process(delta: float) -> void:
	super(delta)
	if _repose:
		_repose = false
		for i: int in _ruins.size():
			_pose(i)


## Part of the finish replay: the slabs are synced to physics again, so pose them in the next frame.
func replay_end() -> void:
	_repose = true


## Per ruin: tower fall, rune glow and slab movement.
func _replay_extra() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array()
	for i: int in _ruins.size():
		state.append(_tower_fall[i])
		state.append(_glow[i])
		state.append(_slab_move[i])
	return state


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	for i: int in _ruins.size():
		var at: int = REPLAY_BASE + i * 3
		_tower_fall[i] = Replayable.mix(from, to, weight, at)
		_glow[i] = Replayable.mix(from, to, weight, at + 1)
		_slab_move[i] = Replayable.mix(from, to, weight, at + 2)
		_pose(i)


## How many ruins have already come down in this race.
func fallen_count() -> int:
	var count: int = 0
	for stage: int in _stage:
		if stage == Stage.FALLEN:
			count += 1
	return count


func ruin_count() -> int:
	return _ruins.size()


## The ruins, in scene order. (The hazard's other children are bursts of dust.)
func get_ruins() -> Array[Node2D]:
	return _ruins


## Where ruin `index` is in its fall, a [enum Stage].
func stage_of(index: int) -> int:
	return _stage[index]


## Whether this race can set ruin `index` off.
func is_live(index: int) -> bool:
	return _live[index]


## Whether the gap of ruin `index` lets fish through right now. A "topple" ruin has no gap.
func is_gap_open(index: int) -> bool:
	if _modes[index] == "topple":
		return false
	return (_modes[index] == "open") == (_slab_move[index] >= 0.05)


## Sets ruin `index` off, as a fish entering its trigger zone does. Does nothing unless the hazard
## is armed and the ruin still stands. Returns whether it started.
func trigger(index: int) -> bool:
	if not _armed or _stage[index] != Stage.STANDING:
		return false
	_stage[index] = Stage.TELEGRAPH
	_stage_time[index] = 0.0
	_dust_timer[index] = 0.0
	_crashed[index] = false
	telegraph_started.emit(kind)
	return true


func _fish_in_trigger(index: int) -> bool:
	var zone: Area2D = _triggers[index]
	if zone == null:
		return false
	for body: Node2D in zone.get_overlapping_bodies():
		if body is Marble:
			return true
	return false


func _advance(index: int, delta: float) -> void:
	match _stage[index]:
		Stage.TELEGRAPH:
			_stage_time[index] += delta
			var length: float = telegraph_seconds + _hesitation[index]
			var pulse: float = 0.5 + 0.5 * sin(clock * 14.0 + float(index))
			_glow[index] = clampf(_stage_time[index] / length, 0.0, 1.0) * (0.5 + 0.5 * pulse)
			_dust_timer[index] += delta
			if _dust_timer[index] >= DUST_INTERVAL:
				_dust_timer[index] = 0.0
				_dust(_tower_top(index), 5, 60.0, Vector2(0, 160))
			_pose(index)
			if _stage_time[index] >= length:
				_stage[index] = Stage.TOPPLE
				_stage_time[index] = 0.0
				active_started.emit(kind)
		Stage.TOPPLE:
			_stage_time[index] += delta
			var t: float = _stage_time[index]
			_tower_fall[index] = clampf(t / TOPPLE_SECONDS, 0.0, 1.0)
			if t < TOPPLE_SECONDS:
				_knock(index, delta)
			var after: float = t - TOPPLE_SECONDS
			_glow[index] = 1.0 - clampf(after / 0.5, 0.0, 1.0)
			if after >= 0.0 and not _crashed[index]:
				_crashed[index] = true
				_crash(index)
			var length: float = _settle_seconds(index)
			_slab_move[index] = clampf(after / length, 0.0, 1.0)
			_pose(index)
			if after >= maxf(length, 0.5):
				_land(index)


## Puts ruin `index` in the state it keeps for the rest of the race.
func _land(index: int) -> void:
	_stage[index] = Stage.FALLEN
	_tower_fall[index] = 1.0
	_glow[index] = 0.0
	_slab_move[index] = 1.0
	_pose(index)


func _settle_seconds(index: int) -> float:
	match _modes[index]:
		"open":
			return CRUMBLE_SECONDS
		"close":
			return DROP_SECONDS
	return RUBBLE_SECONDS


## Keeps the base class's phase in step with the ruins: a telegraph or a topple is going on
## somewhere, or nothing is.
func _sync_phase(before: Phase, delta: float) -> void:
	var busiest: Phase = Phase.IDLE
	for stage: int in _stage:
		if stage == Stage.TOPPLE:
			busiest = Phase.ACTIVE
		elif stage == Stage.TELEGRAPH and busiest == Phase.IDLE:
			busiest = Phase.TELEGRAPH
	phase = busiest
	phase_time = 0.0 if phase != before else phase_time + delta


## Disarming puts every ruin back, so an event cut short has nothing to finish.
func _end_event() -> void:
	pass


func _reset() -> void:
	for i: int in _ruins.size():
		_stage[i] = Stage.STANDING
		_stage_time[i] = 0.0
		_live[i] = false
		_crashed[i] = false
		_tower_fall[i] = 0.0
		_glow[i] = 0.0
		_slab_move[i] = 0.0
		_pose(i)
	_repose = true


## The tower hits the ground and the stone at the gap gives way or slams shut.
func _crash(index: int) -> void:
	_dust(_tower_tip(index), 26, 140.0, Vector2(0, 120))
	_shock(index)
	var gap: Vector2 = _ruins[index].global_position
	if _modes[index] == "close":
		# The slab lands a moment later, so the dust comes with it.
		_dust(gap, 12, 110.0, Vector2(0, 120))
	else:
		_dust(gap, 22, 170.0, Vector2(0, 260), RUBBLE_COLOR)


## A falling tower sweeps the fish in its way along with it, and a little up so they ride over
## the lane instead of being pressed into it.
func _knock(index: int, delta: float) -> void:
	var sweep: Area2D = _sweeps[index]
	if sweep == null:
		return
	var push: Vector2 = _fall_direction(index)
	push = (push + Vector2(0.0, -0.45)).normalized()
	var speed: float = KNOCK_SPEED * _tower_fall[index] * delta
	for body: Node2D in sweep.get_overlapping_bodies():
		var marble: Marble = body as Marble
		if marble != null:
			marble.apply_central_impulse(push * speed * marble.mass)


## The crash throws the fish near the tower's tip up and away from it.
func _shock(index: int) -> void:
	var sweep: Area2D = _sweeps[index]
	if sweep == null:
		return
	var tip: Vector2 = _tower_tip(index)
	for body: Node2D in sweep.get_overlapping_bodies():
		var marble: Marble = body as Marble
		if marble == null:
			continue
		var away: Vector2 = marble.global_position - tip
		if away.length() > SHOCK_RADIUS:
			continue
		var out: Vector2 = (away.normalized() + Vector2(0.0, -1.2)).normalized()
		marble.apply_central_impulse(out * SHOCK_SPEED * marble.mass)


## Unit vector the top of the tower of ruin `index` moves along as it falls, in world space.
func _fall_direction(index: int) -> Vector2:
	var lie: float = deg_to_rad(float(_ruins[index].get_meta("lie_degrees", 90.0)))
	return _ruins[index].global_transform.basis_xform(Vector2(0.0, -1.0).rotated(lie)).normalized()


func _dust(
	at: Vector2, amount: int, speed: float, gravity: Vector2, color: Color = DUST_COLOR
) -> void:
	RaceFx.burst(self, at, color, amount, speed, gravity)
	burst_played.emit(at, color, amount, speed, gravity)


## Puts everything of ruin `index` where its state says it is.
func _pose(index: int) -> void:
	var ruin: Node2D = _ruins[index]
	var tower: Node2D = _towers[index]
	var glow: float = _glow[index]
	var fall: float = _tower_fall[index]
	var move: float = _slab_move[index]
	var lie: float = deg_to_rad(float(ruin.get_meta("lie_degrees", 90.0)))
	var shake: float = sin(clock * 70.0 + float(index) * 1.7) * SHAKE_ANGLE * glow * (1.0 - fall)
	tower.rotation = lie * fall * fall + shake
	var runes: CanvasItem = tower.get_node_or_null("Runes") as CanvasItem
	if runes != null:
		runes.modulate.a = 0.3 + 0.7 * glow
	# A slab is given position and angle in one go: set one after the other, the body ignores the first.
	var slab: AnimatableBody2D = _slabs[index]
	var rest: Vector2 = _slab_rest(index)
	var visual: Polygon2D = slab.get_node("Visual") as Polygon2D
	var mode: String = _modes[index]
	tower.modulate.a = 1.0 - 0.7 * move if mode == "topple" else 1.0
	if mode == "topple":
		slab.transform = Transform2D(0.0, rest + Vector2(0.0, RUBBLE_SINK * (1.0 - move)))
		visual.modulate.a = clampf(move * 3.0, 0.0, 1.0)
	elif mode == "open":
		slab.transform = Transform2D(
			shake * 0.8 + deg_to_rad(9.0) * move * _side(ruin),
			rest + Vector2(0.0, CRUMBLE_DROP * move * move)
		)
		visual.modulate.a = 1.0 - clampf(move * 1.6, 0.0, 1.0)
		_cracks[index].modulate.a = glow
		_cracks[index].visible = glow > 0.01 and move < 0.01
		_set_collider(index, move < 0.05)
	else:
		var drop: float = float(ruin.get_meta("hang_height", 150.0))
		var tilt: float = deg_to_rad(float(ruin.get_meta("hang_degrees", 8.0)))
		var land: float = move * move
		slab.transform = Transform2D(
			tilt * (1.0 - land) + shake, rest + Vector2(0.0, -drop * (1.0 - land))
		)
		var hanging: bool = move < 0.01
		for chain: Variant in _chains[index]:
			(chain as Line2D).visible = hanging
			(chain as Line2D).default_color = Color(0.4, 0.45, 0.6).lerp(RIM_COLOR, glow)


## Remembers what was asked for: `disabled` only changes at the end of the frame, so reading it
## back is stale when a ruin is posed twice in one frame (an event cut short, then reset).
func _set_collider(index: int, enabled: bool) -> void:
	if _colliders[index] != null and _collider_on[index] != enabled:
		_collider_on[index] = enabled
		_colliders[index].set_deferred("disabled", not enabled)


## Where the slab of ruin `index` lies when its gap is sealed (its position in the scene).
func _slab_rest(index: int) -> Vector2:
	return _slabs[index].get_meta("rest", Vector2.ZERO) as Vector2


func _side(ruin: Node2D) -> float:
	return signf(float(ruin.get_meta("lie_degrees", 90.0)))


## World position of the top of the tower of ruin `index` as it stands right now.
func _tower_top(index: int) -> Vector2:
	var height: float = float(_ruins[index].get_meta("height", 200.0))
	return _towers[index].to_global(Vector2(0.0, -height))


## World position of the top of the tower of ruin `index` once it lies on the ground.
func _tower_tip(index: int) -> Vector2:
	var height: float = float(_ruins[index].get_meta("height", 200.0))
	var lie: float = deg_to_rad(float(_ruins[index].get_meta("lie_degrees", 90.0)))
	var base: Node2D = _towers[index]
	return base.get_parent().to_global(base.position + Vector2(0.0, -height).rotated(lie))


## Gives the slab a lit edge, and an "open" slab a crack that glows before it gives way. Returns
## the crack, or null for a "close" slab.
func _add_rim(slab: AnimatableBody2D, open: bool) -> Line2D:
	slab.set_meta("rest", slab.position)
	var visual: Polygon2D = slab.get_node("Visual") as Polygon2D
	var ring: PackedVector2Array = visual.polygon + PackedVector2Array([visual.polygon[0]])
	var line: Line2D = Line2D.new()
	line.points = ring
	line.width = 2.0
	line.default_color = Color(RIM_COLOR, 0.7)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	visual.add_child(line)
	if not open:
		return null
	var crack: Line2D = Line2D.new()
	crack.points = _crack_points(visual.polygon)
	crack.width = 3.0
	crack.default_color = Color(1.0, 0.88, 0.55)
	crack.antialiased = true
	crack.visible = false
	visual.add_child(crack)
	return crack


func _crack_points(polygon: PackedVector2Array) -> PackedVector2Array:
	var low: Vector2 = polygon[0]
	var high: Vector2 = polygon[0]
	for point: Vector2 in polygon:
		low = Vector2(minf(low.x, point.x), minf(low.y, point.y))
		high = Vector2(maxf(high.x, point.x), maxf(high.y, point.y))
	var center: Vector2 = (low + high) * 0.5
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 7:
		var s: float = float(i) / 6.0 - 0.5
		var zig: float = (high.y - low.y) * 0.25 * (1.0 if i % 2 == 0 else -1.0)
		points.append(center + Vector2(s * (high.x - low.x) * 0.85, zig))
	return points
