class_name AftershockHazard
extends Hazard
## An aftershock rattles the whole fault. The floor seams flare as a warning, then for a couple of
## seconds the floor shudders: every fish inside the `Zone` (an Area2D over the map) is hopped up
## and sideways again and again, and the view shakes. It never opens a crack, that is the job of
## the quakes ([QuakeFault]).

## The view should shake: `strength` is in pixels.
signal shaken(strength: float)

## Seconds between hops while the floor shudders.
const HOP_INTERVAL: float = 0.35
## Speed of a hop up and at most sideways, in pixels per second.
const HOP_UP: float = 110.0
const HOP_SIDE: float = 40.0
const SHAKE_WARNING: float = 3.5
const SHAKE_ACTIVE: float = 8.0
const SHAKE_INTERVAL: float = 0.1
const GLOW: Color = Color(1.0, 0.45, 0.12)

var _zone: Area2D = null
var _size: Vector2 = Vector2.ZERO
var _hop_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hop_in: float = 0.0
var _shake_in: float = 0.0


func _ready() -> void:
	_zone = get_node_or_null("Zone") as Area2D
	if _zone != null:
		var shape: CollisionShape2D = _zone.get_node("CollisionShape2D") as CollisionShape2D
		_size = (shape.shape as RectangleShape2D).size


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	_hop_rng.seed = rng.randi()
	_hop_in = 0.0
	_shake_in = 0.0


func _process_telegraph(delta: float) -> void:
	_shake(delta, lerpf(1.0, SHAKE_WARNING, phase_progress()))


func _process_active(delta: float) -> void:
	_shake(delta, SHAKE_ACTIVE)
	_hop_in -= delta
	if _hop_in > 0.0 or _zone == null:
		return
	_hop_in = HOP_INTERVAL
	for body: Node2D in _zone.get_overlapping_bodies():
		if body is Marble:
			var marble: Marble = body as Marble
			var hop: Vector2 = Vector2(
				_hop_rng.randf_range(-HOP_SIDE, HOP_SIDE),
				-_hop_rng.randf_range(HOP_UP * 0.5, HOP_UP)
			)
			marble.sleeping = false
			marble.apply_central_impulse(hop * marble.mass)


func _shake(delta: float, strength: float) -> void:
	_shake_in -= delta
	if _shake_in <= 0.0:
		_shake_in = SHAKE_INTERVAL
		shaken.emit(strength)


func _draw() -> void:
	if _zone == null or phase == Phase.IDLE:
		return
	# A faint heat flicker over the whole map, brighter as the shudder gets closer and while it lasts.
	var strength: float = phase_progress() * 0.5 if phase == Phase.TELEGRAPH else 1.0
	var flicker: float = 0.6 + 0.4 * sin(clock * 30.0)
	var rect: Rect2 = Rect2(_zone.position - _size * 0.5, _size)
	draw_rect(rect, Color(GLOW, 0.05 * strength * flicker))
