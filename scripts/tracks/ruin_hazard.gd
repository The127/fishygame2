class_name RuinHazard
extends Hazard
## Ruined towers give way one after another. Each event picks a tower that still stands, shakes
## it and lets dust fall (the telegraph), then the tower topples and crashes down. The crash
## changes the floor for good, until the race is over:
## - an "open" ruin (metadata `mode`) has a cap stone in the floor. It crumbles away and leaves a
##   gap, a shortcut to the lane below.
## - a "close" ruin starts with that gap open and a slab hanging above it. The slab drops into
##   the gap and seals it, so fish stay on the long way round.
## Every child is a ruin: a Node2D with a `Tower` (the scenery that topples, `lie_degrees` and
## `height` metadata), a `Slab` (AnimatableBody2D with a `Collider` and a `Visual`) and, on
## "close" ruins, `hang_height` and `hang_degrees` metadata plus `Chains` (Line2D children). The
## ruin sits at the gap and the slab's own position is where it lies when the gap is sealed.

## A burst of dust or debris: what [method RaceFx.burst] was given, so the finish replay can play
## the same burst.
signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)

## Seconds the tower takes to fall, from the start of the active phase.
const TOPPLE_SECONDS: float = 1.1
## Seconds a cap stone takes to crumble away after the crash.
const CRUMBLE_SECONDS: float = 0.7
## Seconds a hanging slab takes to drop into its gap after the crash.
const DROP_SECONDS: float = 0.3
## How far a crumbling cap stone sinks, in pixels.
const CRUMBLE_DROP: float = 150.0
const SHAKE_ANGLE: float = deg_to_rad(1.4)
const DUST_INTERVAL: float = 0.4
const RIM_COLOR: Color = Color(1.0, 0.78, 0.42)
const DUST_COLOR: Color = Color(0.55, 0.62, 0.78)
const RUBBLE_COLOR: Color = Color(0.75, 0.68, 0.55)

var _ruins: Array[Node2D] = []
var _towers: Array[Node2D] = []
var _slabs: Array[AnimatableBody2D] = []
var _colliders: Array[CollisionPolygon2D] = []
var _cracks: Array[Line2D] = []
var _chains: Array[Array] = []
var _opens: Array[bool] = []
## Per ruin: how far its tower has fallen (0 standing, 1 lying), how strongly its runes glow
## and how far its slab has gone from where it started to where it ends up.
var _tower_fall: PackedFloat32Array = PackedFloat32Array()
var _glow: PackedFloat32Array = PackedFloat32Array()
var _slab_move: PackedFloat32Array = PackedFloat32Array()
var _fallen: Array[bool] = []
var _current: int = -1
var _crashed: bool = false
var _dust_timer: float = 0.0
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
		_colliders.append(slab.get_node("Collider") as CollisionPolygon2D)
		_opens.append(String(child.get_meta("mode", "open")) == "open")
		var chains: Array = []
		var chain_root: Node = child.get_node_or_null("Chains")
		if chain_root != null:
			chains = chain_root.get_children()
		_chains.append(chains)
		_cracks.append(_add_rim(slab, _opens[i]))
		_tower_fall.append(0.0)
		_glow.append(0.0)
		_slab_move.append(0.0)
		_fallen.append(false)
	for i: int in _ruins.size():
		_pose(i)


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
	for down: bool in _fallen:
		if down:
			count += 1
	return count


func ruin_count() -> int:
	return _ruins.size()


## The ruins, in scene order. (The hazard's other children are bursts of dust.)
func get_ruins() -> Array[Node2D]:
	return _ruins


## Whether the gap of ruin `index` lets fish through right now.
func is_gap_open(index: int) -> bool:
	return _opens[index] == (_slab_move[index] > 0.5)


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	_current = -1
	_crashed = false
	_dust_timer = 0.0
	var standing: Array[int] = []
	for i: int in _ruins.size():
		if not _fallen[i]:
			standing.append(i)
	if standing.is_empty():
		return
	_current = standing[rng.randi_range(0, standing.size() - 1)]


func _process_telegraph(delta: float) -> void:
	if _current < 0:
		return
	var pulse: float = 0.5 + 0.5 * sin(clock * 14.0)
	_glow[_current] = phase_progress() * (0.5 + 0.5 * pulse)
	_dust_timer += delta
	if _dust_timer >= DUST_INTERVAL:
		_dust_timer = 0.0
		_dust(_tower_top(_current), 5, 60.0, Vector2(0, 160))
	_pose(_current)


func _begin_active() -> void:
	_crashed = false


func _process_active(_delta: float) -> void:
	if _current < 0:
		return
	_tower_fall[_current] = clampf(phase_time / TOPPLE_SECONDS, 0.0, 1.0)
	var after: float = phase_time - TOPPLE_SECONDS
	_glow[_current] = 1.0 - clampf(after / 0.5, 0.0, 1.0)
	if after >= 0.0 and not _crashed:
		_crashed = true
		_crash(_current)
	var length: float = CRUMBLE_SECONDS if _opens[_current] else DROP_SECONDS
	_slab_move[_current] = clampf(after / length, 0.0, 1.0)
	_pose(_current)


func _end_event() -> void:
	if _current >= 0:
		_tower_fall[_current] = 1.0
		_glow[_current] = 0.0
		_slab_move[_current] = 1.0
		_fallen[_current] = true
		_pose(_current)
	_current = -1


func _reset() -> void:
	for i: int in _ruins.size():
		_tower_fall[i] = 0.0
		_glow[i] = 0.0
		_slab_move[i] = 0.0
		_fallen[i] = false
		_pose(i)
	_repose = true
	_current = -1
	_crashed = false


## The tower hits the ground and the stone at the gap gives way or slams shut.
func _crash(index: int) -> void:
	_dust(_tower_tip(index), 26, 140.0, Vector2(0, 120))
	var gap: Vector2 = _ruins[index].global_position
	if _opens[index]:
		_dust(gap, 22, 170.0, Vector2(0, 260), RUBBLE_COLOR)
	else:
		# The slab lands a moment later, so the dust comes with it.
		_dust(gap, 12, 110.0, Vector2(0, 120))


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
	if _opens[index]:
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


func _set_collider(index: int, enabled: bool) -> void:
	if _colliders[index].disabled == enabled:
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
