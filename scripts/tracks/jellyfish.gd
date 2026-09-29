class_name Jellyfish
extends AnimatableBody2D
## A glowing jellyfish that drifts around an anchor point on a slow looping path and acts as
## a very bouncy moving bumper. The path is planned from a seed by [method configure] and the
## motion only advances in [method advance], so a seed always replays the same drift.

## Impulse, in pixels per second, given to a marble the moment it touches the bell.
const KICK: float = 260.0
const SKIRT_SEGMENTS: int = 10
const TENTACLES: int = 7

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
	position = target_position()


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
		draw_polyline(points, Color(tint, 0.5 * glow), 3.0, true)
