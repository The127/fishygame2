class_name PortalPair
extends Node2D
## A one-way portal: a fish touching the entry reappears at the exit with the velocity it
## arrived with. A short cooldown keeps a fish from being sent again straight away. While
## `diverted` (a rift event) the fish come out at the divert point instead.

## Seconds a teleported fish is ignored by the entry portals.
const COOLDOWN: float = 0.8
## Fish arriving in quick succession come out side by side, not on top of each other.
const EXIT_SLOTS: int = 4
const EXIT_SPACING: float = 30.0
const RIFT_COLOR: Color = Color(1.0, 0.3, 0.4)
const ARCS: int = 3

@export var entry_point: Vector2 = Vector2.ZERO
@export var exit_point: Vector2 = Vector2.ZERO
@export var divert_point: Vector2 = Vector2.ZERO
@export var radius: float = 50.0
@export var tint: Color = Color(0.3, 0.9, 1.0)

## True while the exit is rerouted to the divert point.
var diverted: bool = false
## 0 to 1: how unstable the portal looks (a rift telegraph or event).
var unstable: float = 0.0

var _area: Area2D
## Instance id of a marble -> seconds of cooldown left.
var _cooldowns: Dictionary = {}
var _sent: int = 0
var _time: float = 0.0


func _ready() -> void:
	z_index = 2
	_area = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	_area.add_child(shape)
	_area.position = entry_point
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)


## Puts the portal back as it was before a race.
func reset() -> void:
	diverted = false
	unstable = 0.0
	_sent = 0
	_cooldowns.clear()


func is_cooling_down(marble: Marble) -> bool:
	return _cooldowns.has(marble.get_instance_id())


## Where the next fish arriving would come out.
func next_destination() -> Vector2:
	var base: Vector2 = divert_point if diverted else exit_point
	var slot: float = float(_sent % EXIT_SLOTS) - float(EXIT_SLOTS - 1) * 0.5
	return base + Vector2(slot * EXIT_SPACING, 0.0)


func _physics_process(delta: float) -> void:
	for key: int in _cooldowns.keys():
		var left: float = float(_cooldowns[key]) - delta
		if left <= 0.0:
			_cooldowns.erase(key)
		else:
			_cooldowns[key] = left


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not body is Marble or (body as Marble).replaying or is_cooling_down(body as Marble):
		return
	_cooldowns[body.get_instance_id()] = COOLDOWN
	# Bodies can only be moved safely outside the physics callback.
	_send.call_deferred(body as Marble)


func _send(marble: Marble) -> void:
	if not is_instance_valid(marble) or not marble.is_inside_tree():
		return
	var from: Vector2 = marble.global_position
	var to: Vector2 = to_global(next_destination())
	_sent += 1
	marble.global_position = to
	var color: Color = tint.lerp(RIFT_COLOR, 1.0 if diverted else 0.0)
	RaceFx.burst(self, from, tint, 14, 120.0, Vector2.ZERO)
	RaceFx.burst(self, to, color, 14, 120.0, Vector2.ZERO)


func _draw() -> void:
	_draw_ring(entry_point, tint.lerp(RIFT_COLOR, unstable), 1.0, 1.0)
	_draw_ring(exit_point, tint, -1.0, 0.0 if diverted else 1.0)
	if unstable > 0.0:
		_draw_ring(divert_point, RIFT_COLOR, -1.0, unstable)


func _draw_ring(center: Vector2, color: Color, spin: float, strength: float) -> void:
	if strength <= 0.0:
		return
	var flicker: float = 1.0 - 0.5 * unstable * (0.5 + 0.5 * sin(_time * 40.0))
	var size: float = radius * 4.6
	draw_texture_rect(
		RaceFx.glow_texture(),
		Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size),
		false,
		Color(color, 0.4 * strength * flicker)
	)
	draw_circle(center, radius * 0.5, Color(color, 0.16 * strength * flicker))
	for i: int in ARCS:
		var ring_radius: float = radius * (1.0 - 0.24 * float(i))
		var start: float = _time * spin * (1.6 + 0.9 * float(i)) + float(i) * 2.1
		var alpha: float = (0.95 - 0.2 * float(i)) * strength * flicker
		for k: int in 3:
			var from: float = start + float(k) * TAU / 3.0
			draw_arc(
				center, ring_radius, from, from + 1.5, 20, Color(color, alpha), 4.0 - float(i), true
			)
