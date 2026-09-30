class_name CurrentHazard
extends Hazard
## A current surges through one lane-shaped zone (an Area2D child), pushing every marble in it
## along the lane, or against it. The telegraph shows glowing wisps drifting the way it will flow.

## Push in pixels per second squared.
const PUSH: float = 420.0
## Chance that the current runs against the lane's direction.
const AGAINST_CHANCE: float = 0.4
## Seconds the push takes to fade in and out.
const FADE: float = 0.4
const WISPS: int = 18
const WISP_LENGTH: float = 90.0
const CHEVRON_SPACING: float = 150.0

@export var tint: Color = Color(0.4, 0.95, 0.85)
## Chance that a current runs against its lane. A map that already strands slow fish sets 0.
@export_range(0.0, 1.0) var against_chance: float = AGAINST_CHANCE

var _zones: Array[Area2D] = []
var _zone: Area2D = null
var _size: Vector2 = Vector2.ZERO
## +1 pushes along the zone's x axis, -1 against it.
var _flow: float = 1.0


func _ready() -> void:
	for child: Node in get_children():
		if child is Area2D:
			_zones.append(child as Area2D)


## Unit vector the current pushes toward while an event is running.
func get_direction() -> Vector2:
	if _zone == null:
		return Vector2.ZERO
	return _zone.global_transform.x.normalized() * _flow


## Which zone is running (-1 for none) and which way the water flows.
func _replay_extra() -> PackedFloat32Array:
	return PackedFloat32Array([float(_zones.find(_zone)), _flow])


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	var index: int = int(Replayable.step(from, to, weight, REPLAY_BASE))
	_zone = _zones[index] if index >= 0 and index < _zones.size() else null
	_flow = Replayable.step(from, to, weight, REPLAY_BASE + 1)
	if _zone != null:
		var shape: CollisionShape2D = _zone.get_node("CollisionShape2D") as CollisionShape2D
		_size = (shape.shape as RectangleShape2D).size


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	if _zones.is_empty():
		return
	_zone = _zones[rng.randi_range(0, _zones.size() - 1)]
	_flow = -1.0 if rng.randf() < against_chance else 1.0
	var shape: CollisionShape2D = _zone.get_node("CollisionShape2D") as CollisionShape2D
	_size = (shape.shape as RectangleShape2D).size


func _process_active(_delta: float) -> void:
	if _zone == null:
		return
	var fade: float = minf(phase_time, active_seconds - phase_time) / FADE
	var push: Vector2 = get_direction() * PUSH * clampf(fade, 0.0, 1.0)
	for body: Node2D in _zone.get_overlapping_bodies():
		if body is Marble:
			var marble: Marble = body as Marble
			marble.apply_central_force(push * marble.mass)


func _end_event() -> void:
	_zone = null


func _reset() -> void:
	_zone = null


func _draw() -> void:
	if _zone == null or phase == Phase.IDLE:
		return
	var strength: float = 0.55 + 0.2 * sin(clock * 6.0)
	var speed: float = 40.0
	if phase == Phase.ACTIVE:
		strength = clampf(minf(phase_time, active_seconds - phase_time) / FADE, 0.0, 1.0)
		speed = 520.0
	draw_set_transform_matrix(_zone.transform)
	var half: Vector2 = _size * 0.5
	draw_rect(Rect2(-half, _size), Color(tint, 0.1 * strength))
	for edge: float in [-half.y, half.y]:
		draw_line(Vector2(-half.x, edge), Vector2(half.x, edge), Color(tint, 0.3 * strength), 2.0)
	for i: int in WISPS:
		var lane: float = fposmod(float(i) * 0.618034, 1.0)
		var y: float = (lane - 0.5) * _size.y * 0.8
		var pace: float = speed * (0.6 + 0.8 * fposmod(float(i) * 0.37, 1.0))
		var x: float = fposmod(clock * pace * _flow + float(i) * 97.0, _size.x)
		var fade: float = sin(PI * x / _size.x)
		var head: Vector2 = Vector2(x - half.x, y)
		var tail: Vector2 = head - Vector2(WISP_LENGTH * _flow, 0.0)
		draw_line(tail, head, Color(tint, 0.7 * strength * fade), 3.0, true)
		draw_circle(head, 2.5, Color(tint, 0.7 * strength * fade))
	var count: int = int(_size.x / CHEVRON_SPACING)
	for i: int in count:
		var x: float = fposmod(clock * speed * 0.5 * _flow + float(i) * CHEVRON_SPACING, _size.x)
		var alpha: float = 0.6 * strength * sin(PI * x / _size.x)
		var tip: Vector2 = Vector2(x - half.x, 0.0)
		var back: float = -16.0 * _flow
		draw_polyline(
			PackedVector2Array([tip + Vector2(back, -14.0), tip, tip + Vector2(back, 14.0)]),
			Color(tint, alpha),
			3.0,
			true
		)
	draw_set_transform_matrix(Transform2D.IDENTITY)
