class_name PlankHazard
extends Hazard
## A plank in the deck gives way like a trapdoor and swings down, so marbles rolling over it
## fall to the deck below, then it swings shut again. The planks are AnimatableBody2D
## children whose origin is the hinge at the downhill end. The telegraph shakes the plank and
## cracks it open with a warm glow.

## How far a plank swings open unless its `open_degrees` metadata says otherwise. A plank
## must stop short of whatever lies under it, or it would crush the marbles down there.
const DEFAULT_OPEN_DEGREES: float = 70.0
const OPEN_SECONDS: float = 0.3
const CLOSE_SECONDS: float = 0.6
const SHAKE_ANGLE: float = deg_to_rad(1.6)
const RIM_COLOR: Color = Color(1.0, 0.72, 0.32)
const DUST_COLOR: Color = Color(0.85, 0.65, 0.4)

var _planks: Array[AnimatableBody2D] = []
var _plank: AnimatableBody2D = null
## Wood color of each plank's Visual, by plank.
var _wood: Dictionary[AnimatableBody2D, Color] = {}
var _cracks: Dictionary[AnimatableBody2D, Line2D] = {}
## +1 or -1, whichever swings the plank's free end downward.
var _open_sign: float = 1.0
## Set when planks must be put back: an AnimatableBody2D only takes a new transform inside
## a physics frame, and an event can be cut short from anywhere.
var _settle: bool = false


func _ready() -> void:
	for child: Node in get_children():
		if child is AnimatableBody2D:
			var plank: AnimatableBody2D = child as AnimatableBody2D
			_planks.append(plank)
			_add_rim(plank)


func _physics_process(delta: float) -> void:
	super(delta)
	if _settle:
		_settle = false
		for plank: AnimatableBody2D in _planks:
			plank.rotation = 0.0


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	if _planks.is_empty():
		return
	_plank = _planks[rng.randi_range(0, _planks.size() - 1)]
	var free_end: Vector2 = _centroid(_plank)
	_open_sign = 1.0 if free_end.x > 0.0 else -1.0


func _process_telegraph(_delta: float) -> void:
	if _plank == null:
		return
	_plank.rotation = sin(clock * 90.0) * SHAKE_ANGLE * phase_progress()
	var pulse: float = 0.5 + 0.5 * sin(clock * 14.0)
	var glow: float = phase_progress() * (0.4 + 0.6 * pulse)
	(_plank.get_node("Visual") as Polygon2D).color = _wood[_plank].lerp(RIM_COLOR, 0.5 * glow)
	_cracks[_plank].modulate.a = glow
	_cracks[_plank].visible = true


func _begin_active() -> void:
	if _plank != null:
		_restore_look(_plank)
		_plank.rotation = 0.0
		RaceFx.burst(
			self, _plank.global_position + _centroid(_plank), DUST_COLOR, 18, 110.0, Vector2(0, 90)
		)


func _process_active(_delta: float) -> void:
	if _plank == null:
		return
	var open: float = 1.0
	if phase_time < OPEN_SECONDS:
		open = phase_time / OPEN_SECONDS
	elif phase_time > active_seconds - CLOSE_SECONDS:
		open = (active_seconds - phase_time) / CLOSE_SECONDS
	_plank.rotation = _open_sign * open_angle(_plank) * smoothstep(0.0, 1.0, clampf(open, 0.0, 1.0))


## Radians the plank swings open.
func open_angle(plank: AnimatableBody2D) -> float:
	return deg_to_rad(float(plank.get_meta("open_degrees", DEFAULT_OPEN_DEGREES)))


func _end_event() -> void:
	if _plank != null:
		_restore_look(_plank)
		_plank.rotation = 0.0
	_settle = true
	_plank = null


func _reset() -> void:
	for plank: AnimatableBody2D in _planks:
		_restore_look(plank)
		plank.rotation = 0.0
	_settle = true
	_plank = null


func _restore_look(plank: AnimatableBody2D) -> void:
	(plank.get_node("Visual") as Polygon2D).color = _wood[plank]
	_cracks[plank].visible = false


func _add_rim(plank: AnimatableBody2D) -> void:
	var visual: Polygon2D = plank.get_node_or_null("Visual") as Polygon2D
	if visual == null:
		return
	var ring: PackedVector2Array = visual.polygon + PackedVector2Array([visual.polygon[0]])
	var line: Line2D = Line2D.new()
	line.points = ring
	line.width = 2.0
	line.default_color = Color(RIM_COLOR, 0.7)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	visual.add_child(line)
	_wood[plank] = visual.color
	var crack: Line2D = Line2D.new()
	crack.points = _crack_points(plank)
	crack.width = 3.0
	crack.default_color = Color(1.0, 0.85, 0.5)
	crack.antialiased = true
	crack.visible = false
	visual.add_child(crack)
	_cracks[plank] = crack


func _crack_points(plank: AnimatableBody2D) -> PackedVector2Array:
	var center: Vector2 = _centroid(plank)
	var along: Vector2 = center.normalized() if center.length() > 0.001 else Vector2.RIGHT
	var across: Vector2 = Vector2(-along.y, along.x)
	var span: float = _extent(plank) * 0.8
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 7:
		var s: float = float(i) / 6.0 - 0.5
		var zig: float = 7.0 * (1.0 if i % 2 == 0 else -1.0)
		points.append(center + along * s * span + across * zig)
	return points


func _centroid(plank: AnimatableBody2D) -> Vector2:
	var polygon: PackedVector2Array = (plank.get_node("Visual") as Polygon2D).polygon
	var sum: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		sum += point
	return sum / float(polygon.size())


func _extent(plank: AnimatableBody2D) -> float:
	var polygon: PackedVector2Array = (plank.get_node("Visual") as Polygon2D).polygon
	var far: float = 0.0
	for point: Vector2 in polygon:
		far = maxf(far, point.length())
	return far
