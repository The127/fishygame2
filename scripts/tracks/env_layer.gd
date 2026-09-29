class_name EnvLayer
extends Node2D
## One procedurally drawn silhouette layer of a track's environment (rock spires,
## kelp, crystal shards). Deterministic for a given seed, so a map always looks the same.

enum Kind { SPIRES, KELP, SHARDS }

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

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if sway > 0.0:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SWAY_SHADER
		material.set_shader_parameter("amplitude", sway)
		material.set_shader_parameter("anchor_y", CEILING_Y if from_top else FLOOR_Y + 60.0)
		material.set_shader_parameter("reach", max_height)
		self.material = material
	queue_redraw()


func _draw() -> void:
	_rng.seed = seed_value
	var flip: float = -1.0 if from_top else 1.0
	var base_y: float = CEILING_Y if from_top else FLOOR_Y + 60.0
	for i: int in count:
		var x: float = -200.0 + WIDTH * (float(i) + _rng.randf_range(0.1, 0.9)) / float(count)
		var h: float = _rng.randf_range(min_height, max_height)
		if from_top:
			h += CEILING_EXTRA
		var w: float = _rng.randf_range(0.5, 1.0)
		match kind:
			Kind.SPIRES:
				_draw_spire(Vector2(x, base_y), h * flip, w)
			Kind.KELP:
				_draw_kelp(Vector2(x, base_y), h * flip, float(i))
			Kind.SHARDS:
				_draw_shard(Vector2(x, base_y), h * flip, w)


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
	draw_colored_polygon(points, color)
	if highlight.a > 0.0:
		draw_polyline(
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
	draw_colored_polygon(left + right, color)
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
		draw_colored_polygon(leaf, color)


func _draw_shard(base: Vector2, height: float, width_scale: float) -> void:
	var half: float = 40.0 * width_scale
	var tip: Vector2 = base + Vector2(_rng.randf_range(-30.0, 30.0), -height)
	var left: Vector2 = base + Vector2(-half, 0.0)
	var right: Vector2 = base + Vector2(half, 0.0)
	var mid: Vector2 = base + Vector2(_rng.randf_range(-8.0, 8.0), -height * 0.25)
	draw_colored_polygon(PackedVector2Array([left, tip, right]), color)
	if highlight.a > 0.0:
		draw_colored_polygon(PackedVector2Array([mid, tip, right]), highlight)
