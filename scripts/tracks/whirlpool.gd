class_name Whirlpool
extends Hazard
## A vortex in a round basin. It always runs: every marble inside is pulled toward the middle
## and spun around it. After a short dwell a marble that swings past one of the exit gaps is
## flung out through it, so which exit a fish takes depends on when it was released. A marble
## that has been circling too long is flung toward the nearest exit, so none orbits forever.
## The hazard event is a surge: the vortex spins up for a few seconds. It always turns the
## same way. The basin is the Zone child, a circle around the whirlpool's origin. With
## gated_exits the exit gaps are shut by invisible gates that open only for a marble being
## released, so nothing drops out of the basin early.

## Inward pull in pixels per second squared at the rim, weaker toward the middle.
const PULL: float = 1300.0
## Speed in pixels per second the vortex spins marbles up to.
const SWIRL_SPEED: float = 520.0
## How fast a marble's spin catches up with SWIRL_SPEED, per second.
const SWIRL_GAIN: float = 8.0
## Damping of the inward and outward motion, per second.
const RADIAL_DAMP: float = 1.2
## Seconds in the basin before a marble may be released through an exit, plus up to
## DWELL_SPREAD more that differs from marble to marble, so they leave at different times.
const MIN_DWELL: float = 3.5
const DWELL_SPREAD: float = 6.0
## Seconds in the basin after which a marble is released whatever its position.
const MAX_DWELL: float = 12.0
## Speed in pixels per second a released marble leaves at.
const EJECT_SPEED: float = 620.0
## Seconds a released marble is left alone by the vortex.
const EJECT_COOLDOWN: float = 2.5
## How far off an exit's center, in degrees, a marble may swing and still be released there.
const EXIT_WINDOW_DEGREES: float = 10.0
## A marble must be this far out, as a fraction of the basin radius, to be released.
const EXIT_MIN_RADIUS: float = 0.55
## Strength multiplier and how quickly it fades in and out during a surge.
const SURGE_STRENGTH: float = 1.7
const SURGE_FADE: float = 0.5
const ARMS: int = 4
## Size in pixels of a gate across an exit: wide enough to overlap the rim on both sides, and
## thick enough that a fast marble cannot get through it.
const GATE_WIDTH: float = 170.0
const GATE_THICKNESS: float = 24.0

## Directions, in degrees, of the exit gaps around the basin (0 is right, 90 is down).
@export var exit_degrees: PackedFloat32Array = PackedFloat32Array()
## Race progress of a fish circling in the basin. Set to where the entry ramp reaches the rim.
@export_range(0.0, 1.0) var hold_progress: float = 0.45
## Shut each exit with a gate that only the marble released through it can pass.
@export var gated_exits: bool = false
@export var tint: Color = Color(0.45, 0.85, 1.0)

var _zone: Area2D
var _radius: float = 260.0
## +1 spins clockwise on screen.
var _spin: float = 1.0
var _surge: float = 0.0
var _turn: float = 0.0
## Seconds each marble in the basin must stay before it may leave, by marble.
var _needed: Dictionary[int, float] = {}
## Varies with the race seed so that different marbles are slow in different races.
var _salt: float = 0.0
var _dwell: Dictionary[int, float] = {}
var _cooldown: Dictionary[int, float] = {}
var _gates: Array[StaticBody2D] = []
## Marbles that are allowed through a gate until their cooldown ends, by marble.
var _passing: Dictionary[int, Variant] = {}


func _ready() -> void:
	_zone = get_node("Zone") as Area2D
	var shape: CollisionShape2D = _zone.get_node("CollisionShape2D") as CollisionShape2D
	_radius = (shape.shape as CircleShape2D).radius
	if gated_exits:
		_build_gates()


func _build_gates() -> void:
	for i: int in exit_degrees.size():
		var dir: Vector2 = get_exit_direction(i)
		var gate: StaticBody2D = StaticBody2D.new()
		var collider: CollisionShape2D = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = Vector2(GATE_THICKNESS, GATE_WIDTH)
		collider.shape = box
		gate.add_child(collider)
		gate.position = to_local(_zone.global_position) + dir * (_radius + GATE_THICKNESS * 0.33)
		gate.rotation = dir.angle()
		add_child(gate)
		_gates.append(gate)


## Current strength of the vortex, 1 at rest and higher during a surge.
func get_strength() -> float:
	return 1.0 + _surge * (SURGE_STRENGTH - 1.0)


func get_spin() -> float:
	return _spin


func get_radius() -> float:
	return _radius


## Position of the middle of the basin on the map.
func get_center() -> Vector2:
	return _zone.global_position


## A circling fish has not got anywhere yet, and the fish flung out of the basin spread out to
## the left and right of the route, so progress there is by depth below the basin. Measured
## against the route it would jump back and forth between the entry ramp and the way out.
func progress_at(global_pos: Vector2, finish: Vector2) -> float:
	var center: Vector2 = get_center()
	if global_pos.distance_to(center) <= _radius:
		return hold_progress
	var bottom: float = center.y + _radius
	# The entry ramp is up on the left, so up there only a fish on the right is past the basin.
	if global_pos.x <= center.x and global_pos.y <= center.y:
		return -1.0
	if finish.y <= bottom:
		return hold_progress
	var depth: float = clampf((global_pos.y - bottom) / (finish.y - bottom), 0.0, 1.0)
	return lerpf(hold_progress, 1.0, depth)


## Unit vector pointing out of the given exit.
func get_exit_direction(index: int) -> Vector2:
	return Vector2.from_angle(deg_to_rad(exit_degrees[index]))


func arm(seed_value: int, frequency: int) -> void:
	super(seed_value, frequency)
	_salt = float(seed_value % 9973) * 0.381966


func _physics_process(delta: float) -> void:
	super(delta)
	_turn += delta * _spin * (0.8 + 1.4 * get_strength())
	_update_surge(delta)
	_stir(delta)
	queue_redraw()


func _update_surge(delta: float) -> void:
	var target: float = 0.0
	if phase == Phase.ACTIVE:
		target = clampf(minf(phase_time, active_seconds - phase_time) / SURGE_FADE, 0.0, 1.0)
	_surge = move_toward(_surge, target, delta / SURGE_FADE)


func _stir(delta: float) -> void:
	for id: int in _cooldown.keys():
		_cooldown[id] -= delta
		if _cooldown[id] <= 0.0:
			_cooldown.erase(id)
			_close_gates_behind(id)
	var inside: Dictionary[int, bool] = {}
	var strength: float = get_strength()
	for body: Node2D in _zone.get_overlapping_bodies():
		if not body is Marble:
			continue
		var marble: Marble = body as Marble
		var key: int = marble.get_instance_id()
		if _cooldown.has(key):
			continue
		inside[key] = true
		if not _dwell.has(key):
			_needed[key] = _dwell_needed(marble)
		_dwell[key] = _dwell.get(key, 0.0) + delta
		if _try_release(marble, _dwell[key], _needed[key]):
			_dwell.erase(key)
			_needed.erase(key)
			_cooldown[key] = EJECT_COOLDOWN
			continue
		_pull(marble, strength)
	for key: int in _dwell.keys():
		if not inside.has(key):
			_dwell.erase(key)
			_needed.erase(key)


## Lets the marble through the gate of the given exit, until its cooldown ends.
func _open_gate(marble: Marble, exit: int) -> void:
	if exit >= _gates.size():
		return
	marble.add_collision_exception_with(_gates[exit])
	_passing[marble.get_instance_id()] = marble


func _close_gates_behind(key: int) -> void:
	var entry: Variant = _passing.get(key)
	_passing.erase(key)
	if not is_instance_valid(entry):
		return
	var marble: Marble = entry as Marble
	for gate: StaticBody2D in _gates:
		marble.remove_collision_exception_with(gate)


func _pull(marble: Marble, strength: float) -> void:
	var offset: Vector2 = marble.global_position - _zone.global_position
	var distance: float = maxf(offset.length(), 1.0)
	var outward: Vector2 = offset / distance
	var around: Vector2 = Vector2(-outward.y, outward.x) * _spin
	var reach: float = clampf(distance / _radius, 0.25, 1.0)
	var accel: Vector2 = -outward * PULL * reach * strength
	var speed_around: float = marble.linear_velocity.dot(around)
	var speed_out: float = marble.linear_velocity.dot(outward)
	accel += around * (SWIRL_SPEED * strength - speed_around) * SWIRL_GAIN
	accel -= outward * speed_out * RADIAL_DAMP
	marble.apply_central_force(accel * marble.mass)


## How long a marble that has just come into the basin stays. Mixes the marble, the race seed
## and how it arrived, so it differs between marbles and between races but replays exactly.
func _dwell_needed(marble: Marble) -> float:
	var arrival: float = (
		marble.global_position.y * 0.0137 + marble.linear_velocity.length() * 0.0071
	)
	var mix: float = float(marble.id) * 0.618034 + _salt + arrival
	return MIN_DWELL + fposmod(mix, 1.0) * DWELL_SPREAD


## Flings the marble out of an exit if it has been in the basin long enough and is at one.
func _try_release(marble: Marble, dwell: float, needed: float) -> bool:
	if exit_degrees.is_empty() or dwell < needed:
		return false
	var offset: Vector2 = marble.global_position - _zone.global_position
	var distance: float = offset.length()
	var best: int = -1
	var best_gap: float = 360.0
	for i: int in exit_degrees.size():
		var gap: float = rad_to_deg(
			absf(angle_difference(offset.angle(), deg_to_rad(exit_degrees[i])))
		)
		if gap < best_gap:
			best_gap = gap
			best = i
	var forced: bool = dwell >= MAX_DWELL
	if not forced and (best_gap > EXIT_WINDOW_DEGREES or distance < _radius * EXIT_MIN_RADIUS):
		return false
	# Head for the mouth of the exit, a chord across the basin that stays inside it.
	var mouth: Vector2 = _zone.global_position + get_exit_direction(best) * _radius
	var heading: Vector2 = (mouth - marble.global_position).normalized()
	var change: Vector2 = heading * EJECT_SPEED - marble.linear_velocity
	_open_gate(marble, best)
	marble.apply_central_impulse(change * marble.mass)
	return true


func _replay_extra() -> PackedFloat32Array:
	return PackedFloat32Array([_turn, _surge])


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_turn = Replayable.mix(from, to, weight, REPLAY_BASE)
	_surge = Replayable.mix(from, to, weight, REPLAY_BASE + 1)


func _reset() -> void:
	_surge = 0.0
	for key: int in _passing.keys():
		_close_gates_behind(key)
	_cooldown.clear()
	_dwell.clear()
	_needed.clear()


func _draw() -> void:
	if _zone == null:
		return
	var center: Vector2 = to_local(_zone.global_position)
	var alert: float = 0.0
	if phase == Phase.TELEGRAPH:
		alert = 0.5 + 0.5 * sin(phase_time * 14.0)
	var glow: float = _surge + alert * 0.6
	draw_circle(center, _radius * 0.98, Color(tint, 0.05 + 0.05 * glow))
	for ring: int in 3:
		var r: float = _radius * (0.3 + 0.24 * ring)
		draw_arc(center, r, 0.0, TAU, 64, Color(tint, 0.06 + 0.06 * glow), 2.0, true)
	for arm: int in ARMS:
		var base: float = _turn + TAU * float(arm) / float(ARMS)
		var points: PackedVector2Array = PackedVector2Array()
		for step: int in 26:
			var t: float = float(step) / 25.0
			var r: float = lerpf(_radius * 0.96, _radius * 0.1, t)
			var a: float = base - _spin * t * 2.6
			points.append(center + Vector2.from_angle(a) * r)
		var fade: float = 0.22 + 0.25 * glow
		draw_polyline(points, Color(tint, fade), 3.0, true)
	draw_circle(center, 22.0 + 10.0 * glow, Color(tint, 0.16 + 0.12 * glow))
	draw_circle(center, 9.0, Color(1, 1, 1, 0.5))
	for i: int in exit_degrees.size():
		var dir: Vector2 = get_exit_direction(i)
		var mouth: Vector2 = center + dir * _radius
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var pulse: float = 0.55 + 0.25 * sin(_turn * 3.0 + float(i))
		draw_line(mouth + side * 36.0, mouth - side * 36.0, Color(tint, 0.5 * pulse), 4.0, true)
		draw_polyline(
			PackedVector2Array(
				[
					mouth - dir * 26.0 + side * 16.0,
					mouth - dir * 6.0,
					mouth - dir * 26.0 - side * 16.0
				]
			),
			Color(tint, 0.6 * pulse),
			3.0,
			true
		)
