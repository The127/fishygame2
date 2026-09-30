class_name KrakenEye
extends Node2D
## The kraken's head and eye, a huge dim silhouette behind the map. The lid is half shut and the
## pupil drifts while all is quiet, and it snaps wide open and locks onto the tentacle when the
## kraken strikes. Purely visual.

const MANTLE_SIZE: Vector2 = Vector2(470.0, 380.0)
const EYE_WIDTH: float = 250.0
const EYE_HEIGHT: float = 120.0
const IRIS_RADIUS: float = 84.0
const IDLE_OPEN: float = 0.3
const OUTLINE_POINTS: int = 32
## How fast the lid and pupil follow their targets, per second.
const FOLLOW: float = 6.0
const MANTLE_COLOR: Color = Color(0.02, 0.005, 0.045, 0.6)
const SCLERA_COLOR: Color = Color(0.09, 0.03, 0.02, 0.9)
const IRIS_COLOR: Color = Color(1.0, 0.72, 0.16)
const RIM_COLOR: Color = Color(0.6, 1.0, 0.45)

var _alert: float = 0.0
var _target_alert: float = 0.0
## Where the eye looks, in the parent's coordinates. Zero means "nowhere in particular".
var _target_look: Vector2 = Vector2.ZERO
var _look: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _shown_alert: float = -1.0
var _shown_look: Vector2 = Vector2(1e9, 1e9)
var _shown_wobble: float = 1e9


## `alert` in [0, 1] opens the eye; `look_at_point` is a point in the parent's coordinates that
## the pupil turns toward, Vector2.ZERO to let it drift.
func set_alert(alert: float, look_at_point: Vector2) -> void:
	_target_alert = clampf(alert, 0.0, 1.0)
	_target_look = look_at_point


func get_alert() -> float:
	return _alert


func _process(delta: float) -> void:
	_time += delta
	var follow: float = minf(FOLLOW * delta, 1.0)
	_alert = lerpf(_alert, _target_alert, follow)
	var goal: Vector2 = Vector2(sin(_time * 0.3) * 0.6, sin(_time * 0.21 + 1.0) * 0.3)
	if _target_look != Vector2.ZERO:
		goal = ((_target_look - position) / 500.0).limit_length(1.0)
	_look = _look.lerp(goal, follow)
	var wobble: float = snappedf(sin(_time * 0.8), 0.05)
	if (
		absf(_alert - _shown_alert) > 0.005
		or _look.distance_to(_shown_look) > 0.005
		or wobble != _shown_wobble
	):
		_shown_alert = _alert
		_shown_look = _look
		_shown_wobble = wobble
		queue_redraw()


func _draw() -> void:
	_draw_mantle()
	var open: float = lerpf(IDLE_OPEN, 1.0, _alert)
	var almond: PackedVector2Array = _almond(open)
	draw_colored_polygon(almond, SCLERA_COLOR)
	var iris_center: Vector2 = _look * Vector2(EYE_WIDTH * 0.32, EYE_HEIGHT * 0.3)
	var iris: PackedVector2Array = _circle(iris_center, IRIS_RADIUS, 28)
	for clipped: PackedVector2Array in Geometry2D.intersect_polygons(almond, iris):
		draw_colored_polygon(clipped, Color(IRIS_COLOR, 0.35 + 0.5 * _alert))
	var glow: Color = Color(IRIS_COLOR, 0.04 + 0.07 * _alert)
	for i: int in 3:
		draw_circle(iris_center, IRIS_RADIUS * (1.5 + 0.35 * float(i)), glow)
	var pupil_width: float = lerpf(0.34, 0.13, _alert) * IRIS_RADIUS
	var pupil: PackedVector2Array = PackedVector2Array()
	for i: int in 16:
		var a: float = TAU * float(i) / 16.0
		pupil.append(iris_center + Vector2(cos(a) * pupil_width, sin(a) * IRIS_RADIUS * 0.95))
	for clipped: PackedVector2Array in Geometry2D.intersect_polygons(almond, pupil):
		draw_colored_polygon(clipped, Color(0.01, 0.0, 0.02, 0.95))
	var outline: PackedVector2Array = almond + PackedVector2Array([almond[0]])
	draw_polyline(outline, Color(RIM_COLOR, 0.25 + 0.4 * _alert), 3.0, true)


## The dome of the head with a few faintly glowing spots, behind the eye.
func _draw_mantle() -> void:
	var dome: PackedVector2Array = _ellipse(Vector2(0.0, -20.0), MANTLE_SIZE, 48)
	draw_colored_polygon(dome, MANTLE_COLOR)
	draw_polyline(
		dome + PackedVector2Array([dome[0]]), Color(RIM_COLOR, 0.1 + 0.05 * _alert), 3.0, true
	)
	var spots: Array[Vector3] = [
		Vector3(-260.0, -190.0, 16.0),
		Vector3(-150.0, -250.0, 11.0),
		Vector3(170.0, -240.0, 14.0),
		Vector3(280.0, -140.0, 10.0),
		Vector3(-320.0, -60.0, 9.0),
		Vector3(300.0, 30.0, 13.0),
	]
	for i: int in spots.size():
		var pulse: float = 0.5 + 0.5 * sin(_time * 0.9 + float(i) * 1.7)
		var spot: Vector3 = spots[i]
		draw_circle(Vector2(spot.x, spot.y), spot.z, Color(RIM_COLOR, 0.05 + 0.06 * pulse))


func _almond(open: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var half: float = EYE_WIDTH * 0.5
	var height: float = EYE_HEIGHT * open
	for i: int in OUTLINE_POINTS + 1:
		var x: float = lerpf(-half, half, float(i) / float(OUTLINE_POINTS))
		var shape: float = pow(maxf(1.0 - pow(x / half, 2.0), 0.0), 0.8)
		points.append(Vector2(x, -height * shape))
	for i: int in range(OUTLINE_POINTS - 1, 0, -1):
		var x: float = lerpf(-half, half, float(i) / float(OUTLINE_POINTS))
		var shape: float = pow(maxf(1.0 - pow(x / half, 2.0), 0.0), 0.8)
		points.append(Vector2(x, height * 0.75 * shape))
	return points


func _circle(center: Vector2, radius: float, count: int) -> PackedVector2Array:
	return _ellipse(center, Vector2(radius, radius), count)


func _ellipse(center: Vector2, radii: Vector2, count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in count:
		var a: float = TAU * float(i) / float(count)
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points
