class_name EelHazard
extends Hazard
## An eel sweeps along a lane against the flow, shoving every marble it touches ahead of it.
## The shove is a strong force from an Area2D rather than a solid body, so a marble caught
## against the lane is swept along instead of being crushed through it. Routes are short and
## the events few, or marbles could be pushed back for good. The telegraph shows its glowing
## eyes at the start of the route and a dotted trail to follow.

const BODY_RADIUS: float = 30.0
## Length of the part that pushes marbles (the whole eel is drawn longer).
const BODY_LENGTH: float = 150.0
## Shove along the route, in pixels per second squared.
const PUSH: float = 4500.0
## Where the idle eel waits, far from every map.
const PARKED: Vector2 = Vector2(-10000.0, -10000.0)
const SEGMENTS: int = 16
const DRAWN_LENGTH: float = 300.0
const HEAD_OFFSET: float = 90.0

## Where each possible route begins and ends, index by index. The eel is centered on them.
@export var route_starts: PackedVector2Array = PackedVector2Array()
@export var route_ends: PackedVector2Array = PackedVector2Array()
## Pixels per second along the route.
@export var speed: float = 300.0
@export var skin: Color = Color(0.15, 0.11, 0.34)
@export var glow: Color = Color(0.55, 0.65, 1.0)
@export var eyes: Color = Color(1.0, 0.4, 0.6)

var _area: Area2D
var _start: Vector2 = Vector2.ZERO
var _end: Vector2 = Vector2.ZERO
var _angle: float = 0.0
var _head: Vector2 = Vector2.ZERO
var _on_route: bool = false


func _ready() -> void:
	_area = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var capsule: CapsuleShape2D = CapsuleShape2D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_LENGTH
	shape.shape = capsule
	shape.rotation = PI * 0.5
	_area.add_child(shape)
	_area.position = PARKED
	add_child(_area)


func event_seconds() -> float:
	var longest: float = 0.0
	for i: int in mini(route_starts.size(), route_ends.size()):
		longest = maxf(longest, route_starts[i].distance_to(route_ends[i]))
	return telegraph_seconds + longest / speed


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	var count: int = mini(route_starts.size(), route_ends.size())
	if count == 0:
		return
	var index: int = rng.randi_range(0, count - 1)
	_start = route_starts[index]
	_end = route_ends[index]
	_angle = (_end - _start).angle()
	_on_route = true
	_head = _start
	active_seconds = _start.distance_to(_end) / speed


func _begin_active() -> void:
	_area.position = _head
	_area.rotation = _angle


func _process_active(_delta: float) -> void:
	_head = _start.lerp(_end, phase_time / maxf(active_seconds, 0.001))
	_area.position = _head
	var push: Vector2 = Vector2.from_angle(_angle) * PUSH
	for body: Node2D in _area.get_overlapping_bodies():
		if body is Marble:
			var marble: Marble = body as Marble
			marble.apply_central_force(push * marble.mass)


func _end_event() -> void:
	_park()


func _reset() -> void:
	_park()


func _park() -> void:
	if _area != null:
		_area.position = PARKED
	_on_route = false


func _draw() -> void:
	if not _on_route or phase == Phase.IDLE:
		return
	if phase == Phase.TELEGRAPH:
		_draw_telegraph()
		_draw_eel(_start, 0.55 * phase_progress())
	else:
		_draw_eel(_head, 1.0)


func _draw_telegraph() -> void:
	var pulse: float = 0.5 + 0.5 * sin(clock * 9.0)
	draw_dashed_line(_start, _end, Color(glow, 0.25 + 0.3 * pulse), 4.0, 16.0, true)
	var ripple: float = fposmod(clock * 1.2, 1.0)
	for i: int in 2:
		var r: float = 20.0 + 70.0 * fposmod(ripple + 0.5 * float(i), 1.0)
		var alpha: float = 0.8 * (1.0 - (r - 20.0) / 70.0)
		draw_arc(_start, r, 0.0, TAU, 32, Color(eyes, alpha), 2.5, true)
	draw_circle(_end, 10.0 + 4.0 * pulse, Color(glow, 0.2))


func _draw_eel(at: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var flip: float = -1.0 if absf(_angle) > PI * 0.5 else 1.0
	draw_set_transform(at, _angle, Vector2(1.0, flip))
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in SEGMENTS + 1:
		var s: float = float(i) / float(SEGMENTS)
		var x: float = HEAD_OFFSET - s * DRAWN_LENGTH
		var wave: float = sin(clock * 9.0 - s * 7.0) * 9.0 * s
		points.append(Vector2(x, wave))
	for i: int in SEGMENTS:
		var s: float = float(i) / float(SEGMENTS)
		var width: float = lerpf(BODY_RADIUS * 2.0, 4.0, s * s)
		draw_line(points[i], points[i + 1], Color(glow, 0.3 * alpha), width + 16.0, true)
		draw_line(points[i], points[i + 1], Color(skin, alpha), width, true)
		draw_line(
			points[i] + Vector2(0.0, -width * 0.3),
			points[i + 1] + Vector2(0.0, -width * 0.3),
			Color(glow, 0.9 * alpha),
			2.5,
			true
		)
		if i % 3 == 1:
			draw_circle(points[i] + Vector2(0.0, width * 0.15), 2.5, Color(glow, 0.9 * alpha))
	var head: Vector2 = points[0]
	for side: float in [-1.0, 1.0]:
		var eye: Vector2 = head + Vector2(-4.0, side * 8.0)
		draw_circle(eye, 13.0, Color(eyes, 0.35 * alpha))
		draw_circle(eye, 3.5, Color(1.0, 0.85, 0.9, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)
