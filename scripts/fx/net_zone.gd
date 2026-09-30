class_name NetZone
extends Node2D
## A net the streamer cast: a round patch of the track that holds fish for a few seconds.
## It flies out and spreads, hangs as a rippling rope mesh, tightens when it catches a fish and
## fades with a shimmer. Race does the holding; `radius` and `life` are the only gameplay part.

const CAST_SECONDS: float = 0.3
const TIGHTEN_SECONDS: float = 0.35
const TIGHTEN_AMOUNT: float = 0.12
const FADE_SECONDS: float = 0.5
## Mesh lines per direction, and samples along each line.
const MESH_LINES: int = 9
const LINE_SAMPLES: int = 9
const ROPE_COLOR: Color = Color(0.85, 0.95, 1.0)

var radius: float = 170.0
var life: float = 2.5

var _age: float = 0.0
var _tighten_start: float = -10.0
var _held: Dictionary = {}


func _ready() -> void:
	z_index = 6


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= life:
		queue_free()


func contains(point: Vector2) -> bool:
	return global_position.distance_to(point) <= radius


## 1 while the net is fully there, fading to 0 in its last half second.
func strength() -> float:
	return clampf((life - _age) / FADE_SECONDS, 0.0, 1.0)


## 0 when the net leaves the hand, 1 once it is fully cast.
func cast_progress() -> float:
	return clampf(_age / CAST_SECONDS, 0.0, 1.0)


## Drawn size relative to `radius`: the net spreads out with a little overshoot.
func spread() -> float:
	var p: float = cast_progress() - 1.0
	var back: float = 1.9
	return maxf(1.0 + (back + 1.0) * p * p * p + back * p * p, 0.15)


## Remembers a fish inside the net. True only the first time, so the caller can react once.
func catch_fish(id: int) -> bool:
	if _held.has(id):
		return false
	_held[id] = true
	return true


## Squeezes the mesh for a moment (a fish was caught). Waits for the cast to finish.
func tighten() -> void:
	_tighten_start = maxf(_age, CAST_SECONDS)


## 1 normally, dipping below 1 while the net squeezes.
func tighten_scale() -> float:
	var t: float = (_age - _tighten_start) / TIGHTEN_SECONDS
	if t < 0.0 or t > 1.0:
		return 1.0
	return 1.0 - TIGHTEN_AMOUNT * sin(PI * t)


## Sideways wobble of a rope point `local` (relative to the centre), travelling outward.
func ripple(local: Vector2) -> Vector2:
	if local.length() < 0.001:
		return Vector2.ZERO
	var calm: float = 1.0 + 2.0 * (1.0 - cast_progress())
	var wave: float = sin(local.length() * 0.045 - _age * 7.0) * 3.0 * calm
	return local.normalized() * wave


func _draw() -> void:
	var alpha: float = strength()
	var p: float = cast_progress()
	# The net drops in from above while it spreads and untwists.
	var lift: Vector2 = Vector2(0.0, -(1.0 - p) * radius * 0.8)
	var scale_factor: float = spread() * tighten_scale()
	draw_set_transform(lift, (1.0 - p) * 0.6, Vector2(scale_factor, scale_factor))
	var rope: Color = Color(ROPE_COLOR, 0.8 * alpha)
	draw_circle(Vector2.ZERO, radius, Color(0.6, 0.85, 1.0, 0.08 * alpha))
	var rim: PackedVector2Array = PackedVector2Array()
	for i: int in 41:
		var edge: Vector2 = Vector2.from_angle(TAU * float(i) / 40.0) * radius
		rim.append(edge + ripple(edge))
	draw_polyline(rim, Color(ROPE_COLOR, 0.9 * alpha), 3.0)
	var knots: PackedVector2Array = PackedVector2Array()
	for i: int in MESH_LINES:
		var offset: float = lerpf(-radius, radius, (float(i) + 0.5) / float(MESH_LINES))
		var half: float = sqrt(maxf(radius * radius - offset * offset, 0.0))
		var row: PackedVector2Array = PackedVector2Array()
		var column: PackedVector2Array = PackedVector2Array()
		for j: int in LINE_SAMPLES:
			var along: float = lerpf(-half, half, float(j) / float(LINE_SAMPLES - 1))
			var a: Vector2 = Vector2(along, offset)
			var b: Vector2 = Vector2(offset, along)
			row.append(a + ripple(a))
			column.append(b + ripple(b))
		draw_polyline(row, rope, 1.5)
		draw_polyline(column, rope, 1.5)
		knots.append(row[i % LINE_SAMPLES])
		knots.append(column[(i * 2 + 1) % LINE_SAMPLES])
	if alpha < 1.0:
		_draw_shimmer(knots, alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Glints that twinkle over the mesh while it fades out.
func _draw_shimmer(points: PackedVector2Array, alpha: float) -> void:
	for i: int in points.size():
		var twinkle: float = maxf(sin(_age * 26.0 + float(i) * 1.9), 0.0)
		var size: float = 7.0 * twinkle * (1.0 - alpha * 0.5)
		if size < 1.0:
			continue
		var color: Color = Color(1.0, 1.0, 1.0, twinkle)
		draw_line(points[i] - Vector2(size, 0), points[i] + Vector2(size, 0), color, 1.5)
		draw_line(points[i] - Vector2(0, size), points[i] + Vector2(0, size), color, 1.5)
