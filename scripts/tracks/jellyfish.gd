class_name Jellyfish
extends AnimatableBody2D
## A glowing jellyfish that drifts around an anchor point on a slow looping path and acts as
## a very bouncy moving bumper. The path is planned from a seed by [method configure] and the
## motion only advances in [method advance], so a seed always replays the same drift.

## Impulse, in pixels per second, given to a marble the moment it touches the bell.
const KICK: float = 260.0
const SKIRT_SEGMENTS: int = 10
const TENTACLES: int = 7
## Seconds the tentacles hold a fish, and seconds after release during which the same fish
## passes through untouched, so no fish gets stuck.
const CATCH_SECONDS: float = 0.8
const IMMUNE_SECONDS: float = 2.5
## How quickly a held fish's velocity matches the jellyfish's, per second, and how fast it
## sinks while held, in pixels per second.
const GRIP: float = 9.0
const SAG_SPEED: float = 30.0
## Fish ids a [method snapshot] keeps per jellyfish (-1 for an empty slot), and floats in it.
const HELD_SLOTS: int = 3
const SNAPSHOT_FLOATS: int = 5 + HELD_SLOTS

## Radius of the bell (the part marbles bounce off).
@export var radius: float = 42.0
## Largest distance the jellyfish strays from where it is placed, along each axis.
@export var drift: Vector2 = Vector2(55.0, 40.0)
@export var tint: Color = Color(1.0, 0.45, 0.85)

## Where the drift is centered: the position the node has in the scene.
var anchor: Vector2 = Vector2.ZERO
## 0 to 1, how strongly the bell glows.
var excite: float = 0.0
## Multiplier for the kick, raised while the swarm surges.
var kick_scale: float = 1.0

var _clock: float = 0.0
var _speed: Vector2 = Vector2(0.5, 0.6)
var _phase: Vector2 = Vector2.ZERO
var _pulse_phase: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
## Seconds left on each held fish, and seconds of immunity left on each released fish.
## Untyped because freed marbles stay behind as keys and a typed key cannot be erased.
var _held: Dictionary = {}
var _immune: Dictionary = {}
var _sting: float = 0.0
var _sting_area: Area2D
## Replay: the fish by id while a replay plays (null otherwise) and the ids shown as held.
var _replay_fish: Variant = null
var _shown_held: Array[int] = []


func _ready() -> void:
	anchor = position
	var bumper: PhysicsMaterial = PhysicsMaterial.new()
	bumper.bounce = 1.0
	bumper.friction = 0.1
	physics_material_override = bumper
	var body_shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	body_shape.shape = circle
	add_child(body_shape)
	# A thin ring just outside the bell notices marbles the moment they touch it.
	var ring: Area2D = Area2D.new()
	var ring_shape: CollisionShape2D = CollisionShape2D.new()
	var ring_circle: CircleShape2D = CircleShape2D.new()
	ring_circle.radius = radius + 4.0
	ring_shape.shape = ring_circle
	ring.add_child(ring_shape)
	ring.body_entered.connect(_on_ring_body_entered)
	add_child(ring)
	# The tentacles hang below the bell and grab marbles that touch them.
	_sting_area = Area2D.new()
	var sting_shape: CollisionShape2D = CollisionShape2D.new()
	var sting_rect: RectangleShape2D = RectangleShape2D.new()
	sting_rect.size = Vector2(radius * 1.5, radius * 0.9)
	sting_shape.shape = sting_rect
	sting_shape.position = Vector2(0.0, radius * 1.55)
	_sting_area.add_child(sting_shape)
	add_child(_sting_area)
	var glow_material: CanvasItemMaterial = CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow_material
	z_index = -1


## Picks the path for a race and rewinds to its start.
func configure(rng: RandomNumberGenerator) -> void:
	_speed = Vector2(rng.randf_range(0.35, 0.8), rng.randf_range(0.35, 0.8))
	_phase = Vector2(rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU))
	_pulse_phase = rng.randf_range(0.0, TAU)
	_clock = 0.0
	_velocity = Vector2.ZERO
	_held.clear()
	_immune.clear()
	_sting = 0.0
	position = drift_position(0.0)


## Where the jellyfish is at drift time `t`, always within `drift` of the anchor.
func drift_position(t: float) -> Vector2:
	return (
		anchor
		+ Vector2(drift.x * sin(_speed.x * t + _phase.x), drift.y * sin(_speed.y * t + _phase.y))
	)


## Where the jellyfish is heading this physics frame. The node's own position only catches up
## when the physics server syncs it, so read this to know the planned path.
func target_position() -> Vector2:
	return drift_position(_clock)


## Moves along the path. `speed_scale` speeds the drift up (1 is normal).
func advance(delta: float, speed_scale: float = 1.0) -> void:
	_clock += delta * speed_scale
	var before: Vector2 = position
	position = target_position()
	if delta > 0.0:
		_velocity = (position - before) / delta
	_update_catches(delta)


## What the finish replay needs to draw this jellyfish: position, drift clock, glow and sting,
## then the ids of the fish its tentacles hold (-1 for none), for the crackle drawn to them.
func snapshot() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array(
		[position.x, position.y, _clock, excite, _sting]
	)
	var ids: Array[int] = []
	for key: Variant in _held.keys():
		if ids.size() < HELD_SLOTS and is_instance_valid(key):
			ids.append((key as Marble).id)
	for k: int in HELD_SLOTS:
		state.append(float(ids[k]) if k < ids.size() else -1.0)
	return state


## Shows the jellyfish as a [method snapshot] recorded it. Does not move it along its path.
func show_snapshot(values: PackedFloat32Array) -> void:
	position = Vector2(values[0], values[1])
	_clock = values[2]
	excite = values[3]
	_sting = values[4]
	_shown_held.clear()
	for k: int in HELD_SLOTS:
		_shown_held.append(roundi(values[5 + k]))
	queue_redraw()


## Replay: tells the jellyfish where to find the fish (id to [Marble]) so it can draw the crackle
## to the ones the recording says it held. `null` goes back to the live fish.
func use_replay_fish(fish: Variant) -> void:
	_replay_fish = fish
	_shown_held.clear()
	queue_redraw()


## True while the tentacles are holding `marble`.
func is_holding(marble: Marble) -> bool:
	return _held.has(marble)


## True while `marble` was released recently and the tentacles ignore it.
func is_immune(marble: Marble) -> bool:
	return _immune.has(marble)


func held_count() -> int:
	return _held.size()


## Grabs the marble for a moment unless it is already held or was just released.
func catch_marble(marble: Marble) -> bool:
	if not is_instance_valid(marble) or marble.freeze:
		return false
	if _held.has(marble) or _immune.has(marble):
		return false
	_held[marble] = CATCH_SECONDS
	_sting = 1.0
	return true


## Keys are checked before they are used as marbles: a finished race frees its marbles while
## the jellyfish keep running.
func _update_catches(delta: float) -> void:
	for key: Variant in _immune.keys():
		if not is_instance_valid(key):
			_immune.erase(key)
			continue
		_immune[key] -= delta
		if _immune[key] <= 0.0:
			_immune.erase(key)
	for key: Variant in _held.keys():
		if not is_instance_valid(key) or (key as Marble).freeze:
			_held.erase(key)
			continue
		var marble: Marble = key as Marble
		_held[marble] -= delta
		if _held[marble] <= 0.0:
			_held.erase(marble)
			_immune[marble] = IMMUNE_SECONDS
			continue
		var wanted: Vector2 = _velocity + Vector2(0.0, SAG_SPEED)
		marble.apply_central_force((wanted - marble.linear_velocity) * GRIP * marble.mass)
	if _sting_area != null and is_inside_tree():
		for body: Node2D in _sting_area.get_overlapping_bodies():
			if body is Marble:
				catch_marble(body as Marble)
	if _held.is_empty():
		_sting = maxf(_sting - delta * 2.0, 0.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _on_ring_body_entered(body: Node2D) -> void:
	if not body is Marble:
		return
	var marble: Marble = body as Marble
	var away: Vector2 = marble.global_position - global_position
	if away.length_squared() < 0.0001:
		away = Vector2.UP
	marble.apply_central_impulse(away.normalized() * KICK * kick_scale * marble.mass)


func _draw() -> void:
	var beat: float = 0.5 + 0.5 * sin(_clock * 2.4 + _pulse_phase)
	var squash: float = 1.0 + 0.06 * beat
	var glow: float = 0.55 + 0.45 * excite
	# Soft halo, brighter when excited.
	for i: int in 4:
		var r: float = radius * (2.4 - 0.45 * float(i))
		draw_circle(Vector2.ZERO, r, Color(tint, (0.03 + 0.05 * excite) * float(i + 1)))
	# Bell: a dome over a scalloped skirt.
	var dome: PackedVector2Array = PackedVector2Array()
	for s: int in SKIRT_SEGMENTS + 1:
		var a: float = PI + PI * float(s) / float(SKIRT_SEGMENTS)
		dome.append(Vector2(cos(a) * radius * squash, sin(a) * radius / squash))
	dome.append(Vector2(radius * 0.85, radius * 0.18))
	dome.append(Vector2(-radius * 0.85, radius * 0.18))
	draw_colored_polygon(dome, Color(tint, 0.35 * glow))
	draw_polyline(dome, Color(tint.lightened(0.4), 0.85 * glow), 2.5, true)
	draw_circle(Vector2(0.0, -radius * 0.25), radius * 0.4, Color(tint.lightened(0.6), 0.25 * glow))
	# Tentacles trail below and sway with the drift clock.
	for i: int in TENTACLES:
		var x: float = lerpf(-radius * 0.7, radius * 0.7, float(i) / float(TENTACLES - 1))
		var length: float = radius * (1.5 + 0.5 * sin(float(i) * 2.3))
		var points: PackedVector2Array = PackedVector2Array()
		for s: int in 8:
			var t: float = float(s) / 7.0
			var sway: float = sin(_clock * 3.0 - t * 4.0 + float(i)) * radius * 0.16 * t
			points.append(Vector2(x + sway, radius * 0.15 + length * t))
		var grip: float = _sting
		var color: Color = Color(tint.lightened(0.5 * grip), (0.5 + 0.4 * grip) * glow)
		draw_polyline(points, color, 3.0 + grip, true)
	# A crackle of light from the tentacles to every fish they hold.
	for there: Vector2 in _held_points():
		var from: Vector2 = Vector2(clampf(there.x, -radius * 0.7, radius * 0.7), radius * 1.4)
		var zig: Vector2 = (there - from).orthogonal().normalized() * 6.0 * sin(_clock * 40.0)
		draw_polyline(
			PackedVector2Array([from, from.lerp(there, 0.5) + zig, there]),
			Color(tint.lightened(0.7), 0.9),
			2.0,
			true
		)
		draw_circle(there, Marble.RADIUS * 1.6, Color(tint.lightened(0.6), 0.25))


## Local positions of the fish to draw the crackle to: the ones held now, or during a replay the
## ones the recording says were held, where the replayed fish are.
func _held_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	if _replay_fish != null:
		var fish: Dictionary = _replay_fish
		for id: int in _shown_held:
			var marble: Variant = fish.get(id)
			if id >= 0 and marble != null and is_instance_valid(marble):
				if (marble as Marble).visible:
					points.append(to_local((marble as Marble).global_position))
		return points
	for key: Variant in _held.keys():
		if is_instance_valid(key):
			points.append(to_local((key as Marble).global_position))
	return points
