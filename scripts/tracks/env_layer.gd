class_name EnvLayer
extends Node2D
## One procedurally drawn silhouette layer of a track's environment (rock spires,
## kelp, crystal shards). Deterministic for a given seed, so a map always looks the same.
## The shapes are tessellated once into a single mesh (one draw call per layer) instead of
## thousands of canvas draw commands.

enum Kind { SPIRES, KELP, SHARDS, MASTS, BLOOMS, CORAL }

const WIDTH: float = 2400.0
const FLOOR_Y: float = 1080.0
## Ceiling shapes start this far above the frame and are lengthened by the same amount
## (past the overview's top edge), so they still hang the same distance into it.
const CEILING_Y: float = -220.0
const CEILING_EXTRA: float = 160.0
const SWAY_SHADER: Shader = preload("res://assets/shaders/env/sway.gdshader")

var kind: Kind = Kind.SPIRES
var color: Color = Color.BLACK
var highlight: Color = Color(1, 1, 1, 0)
var seed_value: int = 1
var count: int = 12
var min_height: float = 120.0
var max_height: float = 320.0
var from_top: bool = false
## Sideways sway in pixels at the far end, done in a shader. Zero keeps the layer static.
var sway: float = 0.0
## Fixed shapes as Vector2(x, height), replacing the seeded scatter. Heights are total lengths from the
## anchor line (they include CEILING_EXTRA or the floor offset). Empty scatters `count`.
var placements: Array[Vector2] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mesh: ArrayMesh
var _vertices: PackedVector2Array = PackedVector2Array()
var _colors: PackedColorArray = PackedColorArray()
var _indices: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	if sway > 0.0:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SWAY_SHADER
		material.set_shader_parameter("amplitude", sway)
		material.set_shader_parameter("anchor_y", CEILING_Y if from_top else FLOOR_Y + 60.0)
		material.set_shader_parameter("reach", max_height)
		self.material = material
	_build()
	queue_redraw()


func _draw() -> void:
	if _mesh != null:
		draw_mesh(_mesh, null)


## Tessellates every shape into `_mesh`.
func _build() -> void:
	_vertices.clear()
	_colors.clear()
	_indices.clear()
	_rng.seed = seed_value
	var flip: float = -1.0 if from_top else 1.0
	var base_y: float = CEILING_Y if from_top else FLOOR_Y + 60.0
	var total: int = placements.size() if not placements.is_empty() else count
	for i: int in total:
		var x: float = -200.0 + WIDTH * (float(i) + _rng.randf_range(0.1, 0.9)) / float(count)
		var h: float = _rng.randf_range(min_height, max_height)
		if from_top:
			h += CEILING_EXTRA
		var w: float = _rng.randf_range(0.5, 1.0)
		if not placements.is_empty():
			x = placements[i].x
			h = placements[i].y
		match kind:
			Kind.SPIRES:
				_draw_spire(Vector2(x, base_y), h * flip, w)
			Kind.KELP:
				_draw_kelp(Vector2(x, base_y), h * flip, float(i))
			Kind.SHARDS:
				_draw_shard(Vector2(x, base_y), h * flip, w)
			Kind.MASTS:
				_draw_mast(Vector2(x, base_y), h * flip, i)
			Kind.BLOOMS:
				_draw_bloom(Vector2(x, base_y), h * flip)
			Kind.CORAL:
				_draw_coral(Vector2(x, base_y), h * flip)
	if _vertices.is_empty():
		_mesh = null
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_vertices = PackedVector2Array()
	_colors = PackedColorArray()
	_indices = PackedInt32Array()


func _draw_spire(base: Vector2, height: float, width_scale: float) -> void:
	var half: float = 90.0 * width_scale + absf(height) * 0.12
	var points: PackedVector2Array = PackedVector2Array()
	points.append(base + Vector2(-half, 0.0))
	points.append(base + Vector2(-half * 0.7, -height * 0.45))
	points.append(base + Vector2(-half * 0.25, -height * 0.8))
	points.append(base + Vector2(0.0, -height))
	points.append(base + Vector2(half * 0.3, -height * 0.7))
	points.append(base + Vector2(half * 0.75, -height * 0.4))
	points.append(base + Vector2(half, 0.0))
	_add_polygon(points, color)
	if highlight.a > 0.0:
		_add_polyline(
			PackedVector2Array([points[1], points[2], points[3], points[4]]), highlight, 2.0
		)


func _draw_kelp(base: Vector2, height: float, phase: float) -> void:
	var segments: int = 12
	var width: float = 9.0 + absf(height) * 0.03
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	var spine: PackedVector2Array = PackedVector2Array()
	for s: int in segments + 1:
		var t: float = float(s) / float(segments)
		var p: Vector2 = base + Vector2(sin(t * 3.2 + phase) * 16.0 * t, -height * t)
		var half: float = width * (1.0 - t * 0.85) * 0.5
		spine.append(p)
		left.append(p + Vector2(-half, 0.0))
		right.append(p + Vector2(half, 0.0))
	right.reverse()
	_add_polygon(left + right, color)
	# Broad leaves along the stem, alternating sides.
	for s: int in range(2, segments - 1, 3):
		var side: float = 1.0 if (s / 3) % 2 == 0 else -1.0
		var p: Vector2 = spine[s]
		var reach: float = 46.0 * (1.0 - float(s) / float(segments)) + 18.0
		var up: float = -signf(height)
		var leaf: PackedVector2Array = PackedVector2Array(
			[
				p + Vector2(0.0, 0.0),
				p + Vector2(side * reach * 0.5, up * reach * 0.25),
				p + Vector2(side * reach, up * reach * 0.9),
				p + Vector2(side * reach * 0.25, up * reach * 0.45),
			]
		)
		_add_polygon(leaf, color)


func _draw_shard(base: Vector2, height: float, width_scale: float) -> void:
	var half: float = 40.0 * width_scale
	var tip: Vector2 = base + Vector2(_rng.randf_range(-30.0, 30.0), -height)
	var left: Vector2 = base + Vector2(-half, 0.0)
	var right: Vector2 = base + Vector2(half, 0.0)
	var mid: Vector2 = base + Vector2(_rng.randf_range(-8.0, 8.0), -height * 0.25)
	_add_polygon(PackedVector2Array([left, tip, right]), color)
	if highlight.a > 0.0:
		_add_polygon(PackedVector2Array([mid, tip, right]), highlight)


## A branching coral: a trunk that forks a few times, each fork thinner and shorter.
func _draw_coral(base: Vector2, height: float) -> void:
	var up: Vector2 = Vector2(0.0, -signf(height))
	_draw_coral_branch(base, up.rotated(_rng.randf_range(-0.15, 0.15)), absf(height) * 0.42, 5)


func _draw_coral_branch(from: Vector2, direction: Vector2, length: float, depth: int) -> void:
	var to: Vector2 = from + direction * length
	var width: float = 3.0 + float(depth) * 2.6
	_add_line(from, to, color, width)
	_add_circle(to, width * 0.5, color)
	if highlight.a > 0.0 and depth == 0:
		_add_circle(to, width * 0.5 + 2.0, highlight)
	if depth == 0:
		return
	var spread: float = _rng.randf_range(0.35, 0.65)
	var shrink: float = _rng.randf_range(0.66, 0.8)
	_draw_coral_branch(to, direction.rotated(-spread), length * shrink, depth - 1)
	_draw_coral_branch(to, direction.rotated(spread * 0.9), length * shrink, depth - 1)
	if depth >= 3:
		_draw_coral_branch(
			to, direction.rotated(_rng.randf_range(-0.15, 0.15)), length * 0.55, depth - 2
		)


## A broken mast with a yard and a torn sail, or every third one a curved hull rib.
func _draw_mast(base: Vector2, height: float, index: int) -> void:
	var lean: float = _rng.randf_range(-0.12, 0.12)
	var tip: Vector2 = base + Vector2(height * lean, -height)
	if index % 3 == 2:
		var rib: PackedVector2Array = PackedVector2Array()
		for s: int in 9:
			var t: float = float(s) / 8.0
			rib.append(base + Vector2(sin(t * 1.9) * height * 0.45, -height * t * 0.8))
		_add_polyline(rib, color, 14.0)
		return
	var half: float = 7.0 + absf(height) * 0.012
	_add_polygon(
		PackedVector2Array(
			[
				base + Vector2(-half * 1.6, 0.0),
				base + Vector2(half * 1.6, 0.0),
				tip + Vector2(half * 0.5, 0.0),
				tip + Vector2(-half * 0.5, 0.0)
			]
		),
		color
	)
	var yard_at: Vector2 = base.lerp(tip, 0.72)
	var yard: float = 40.0 + absf(height) * 0.18
	var tilt: float = _rng.randf_range(-0.2, 0.2) * yard
	_add_line(yard_at + Vector2(-yard, -tilt), yard_at + Vector2(yard, tilt), color, 8.0)
	# The sail hangs from the yard, away from the top (toward the floor for floor layers).
	var down: float = signf(height)
	var sail: PackedVector2Array = PackedVector2Array(
		[
			yard_at + Vector2(-yard * 0.9, -tilt),
			yard_at + Vector2(yard * 0.9, tilt),
			yard_at + Vector2(yard * 0.6, tilt + down * yard * 0.9),
			yard_at + Vector2(yard * 0.1, down * yard * 0.5),
			yard_at + Vector2(-yard * 0.5, -tilt + down * yard * 1.1),
		]
	)
	_add_polygon(sail, color)
	if highlight.a > 0.0:
		_add_line(yard_at + Vector2(-yard, -tilt), yard_at + Vector2(yard, tilt), highlight, 2.0)


## A giant jellyfish silhouette drifting in the murk: a dome with tentacles trailing below.
func _draw_bloom(base: Vector2, height: float) -> void:
	var radius: float = 26.0 + absf(height) * 0.16
	var center: Vector2 = base + Vector2(0.0, -height)
	var dome: PackedVector2Array = PackedVector2Array()
	for s: int in 13:
		var a: float = PI + PI * float(s) / 12.0
		dome.append(center + Vector2(cos(a) * radius, sin(a) * radius * 0.8))
	dome.append(center + Vector2(radius * 0.85, radius * 0.14))
	dome.append(center + Vector2(-radius * 0.85, radius * 0.14))
	_add_polygon(dome, color)
	if highlight.a > 0.0:
		_add_polyline(dome.slice(0, 13), highlight, 2.0)
	var strands: int = 6
	for i: int in strands:
		var x: float = lerpf(-radius * 0.7, radius * 0.7, float(i) / float(strands - 1))
		var length: float = radius * _rng.randf_range(1.6, 2.8)
		var phase: float = _rng.randf_range(0.0, TAU)
		var points: PackedVector2Array = PackedVector2Array()
		for s: int in 9:
			var t: float = float(s) / 8.0
			points.append(
				(
					center
					+ Vector2(
						x + sin(t * 4.0 + phase) * radius * 0.18 * t, radius * 0.1 + length * t
					)
				)
			)
		_add_polyline(points, color, maxf(3.0, radius * 0.06))


func _add_polygon(points: PackedVector2Array, fill: Color) -> void:
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	var first: int = _vertices.size()
	for i: int in triangles.size():
		_indices.append(first + triangles[i])
	_push_vertices(points, fill)


func _add_line(from: Vector2, to: Vector2, line_color: Color, width: float) -> void:
	_add_polyline(PackedVector2Array([from, to]), line_color, width)


## A stroke of constant `width` with mitered joints. The miter length is capped at twice the half
## width, so very sharp turns get a slightly narrower corner instead of a long spike.
func _add_polyline(points: PackedVector2Array, line_color: Color, width: float) -> void:
	var count: int = points.size()
	if count < 2:
		return
	var half: float = width * 0.5
	var first: int = _vertices.size()
	for i: int in count:
		var before: Vector2 = (points[i] - points[maxi(i - 1, 0)]).normalized()
		var after: Vector2 = (points[mini(i + 1, count - 1)] - points[i]).normalized()
		var tangent: Vector2 = (before + after).normalized()
		if tangent == Vector2.ZERO:
			tangent = after if after != Vector2.ZERO else before
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		var facing: Vector2 = Vector2(-after.y, after.x) if after != Vector2.ZERO else normal
		var miter: float = minf(1.0 / maxf(normal.dot(facing), 0.001), 2.0)
		_vertices.append(points[i] + normal * half * miter)
		_vertices.append(points[i] - normal * half * miter)
		_colors.append(line_color)
		_colors.append(line_color)
	for i: int in count - 1:
		var a: int = first + i * 2
		_indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))


func _add_circle(center: Vector2, radius: float, fill: Color) -> void:
	var segments: int = clampi(int(radius * 2.0), 8, 24)
	var first: int = _vertices.size()
	_vertices.append(center)
	_colors.append(fill)
	for i: int in segments:
		var angle: float = TAU * float(i) / float(segments)
		_vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)
		_colors.append(fill)
	for i: int in segments:
		_indices.append_array(
			PackedInt32Array([first, first + 1 + i, first + 1 + (i + 1) % segments])
		)


func _push_vertices(points: PackedVector2Array, fill: Color) -> void:
	_vertices.append_array(points)
	for i: int in points.size():
		_colors.append(fill)
