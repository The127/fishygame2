class_name TiltHazard
extends Hazard
## Somebody bumps the cabinet. The rails flash as a warning, then everything inside the `Zone`
## (an Area2D over the table) is shoved back and forth sideways for a couple of seconds.

## Sideways push in pixels per second squared at full strength.
const SHAKE: float = 900.0
## Shoves per second (each one swings the push to the other side).
const SHAKE_HZ: float = 2.5
## Seconds the push takes to fade in and out.
const FADE: float = 0.3

@export var tint: Color = Color(1.0, 0.85, 0.5)

var _zone: Area2D = null
var _size: Vector2 = Vector2.ZERO
## +1 if the first shove goes right, -1 if it goes left.
var _lead: float = 1.0


func _ready() -> void:
	_zone = get_node_or_null("Zone") as Area2D
	if _zone != null:
		var shape: CollisionShape2D = _zone.get_node("CollisionShape2D") as CollisionShape2D
		_size = (shape.shape as RectangleShape2D).size


## Which way the current shove goes, +1 right or -1 left. Zero outside the event.
func get_shove() -> float:
	if phase != Phase.ACTIVE:
		return 0.0
	var fade: float = clampf(minf(phase_time, active_seconds - phase_time) / FADE, 0.0, 1.0)
	return signf(sin(phase_time * TAU * SHAKE_HZ)) * _lead * fade


func _replay_extra() -> PackedFloat32Array:
	return PackedFloat32Array([_lead])


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_lead = Replayable.step(from, to, weight, REPLAY_BASE)


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	_lead = -1.0 if rng.randf() < 0.5 else 1.0


func _process_active(_delta: float) -> void:
	if _zone == null:
		return
	var push: Vector2 = Vector2(get_shove() * SHAKE, 0.0)
	for body: Node2D in _zone.get_overlapping_bodies():
		if body is Marble:
			var marble: Marble = body as Marble
			marble.apply_central_force(push * marble.mass)


func _end_event() -> void:
	_lead = 1.0


func _reset() -> void:
	_lead = 1.0


func _draw() -> void:
	if _zone == null or phase == Phase.IDLE:
		return
	var center: Vector2 = _zone.position
	var half: Vector2 = _size * 0.5
	var strength: float = 0.4 + 0.4 * sin(clock * 14.0)
	if phase == Phase.ACTIVE:
		strength = clampf(minf(phase_time, active_seconds - phase_time) / FADE, 0.0, 1.0)
	var swing: float = signf(sin(phase_time * TAU * SHAKE_HZ)) if phase == Phase.ACTIVE else 0.0
	# Rails down both sides, with arrows that point where the cabinet is being thrown.
	for edge: float in [-half.x, half.x]:
		draw_line(
			center + Vector2(edge, -half.y),
			center + Vector2(edge, half.y),
			Color(tint, 0.5 * strength),
			6.0
		)
	var direction: float = swing * _lead
	for row: int in 7:
		var y: float = center.y + (float(row) - 3.0) * 140.0
		var x: float = center.x + direction * 30.0
		var lean: float = direction if direction != 0.0 else _lead
		draw_polyline(
			PackedVector2Array(
				[
					Vector2(x - lean * 40.0, y - 26.0),
					Vector2(x, y),
					Vector2(x - lean * 40.0, y + 26.0),
				]
			),
			Color(tint, 0.3 * strength),
			5.0,
			true
		)
