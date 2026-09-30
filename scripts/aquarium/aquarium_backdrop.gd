class_name AquariumBackdrop
extends Node2D
## The water around the fish, drawn from nothing but the time and the camera: a dark gradient,
## light shafts, far and near seabed with kelp, drifting specks. [member layer] picks what is
## drawn: the water and seabed, the additive light, or the front layer (fog and a vignette)
## that sits over the fish.

enum Layer { BACK, LIGHT, FRONT }

const TOP_COLOR: Color = Color(0.03, 0.16, 0.26)
const MID_COLOR: Color = Color(0.012, 0.075, 0.15)
const DEEP_COLOR: Color = Color(0.004, 0.02, 0.05)
const SHAFT_COUNT: int = 7
const KELP_LAYERS: int = 3
const KELP_PER_LAYER: int = 12
const SPECK_COUNT: int = 40
const FOG_EDGE: float = 0.22

var layer: Layer = Layer.BACK
var view: Vector2 = Vector2(1280.0, 720.0)
var cam_x: float = 0.0
var time: float = 0.0


func _ready() -> void:
	if layer == Layer.LIGHT:
		material = RaceFx.additive_material()


func _draw() -> void:
	match layer:
		Layer.BACK:
			_draw_water()
			for i: int in KELP_LAYERS:
				_draw_seabed(i)
		Layer.LIGHT:
			_draw_shafts()
			_draw_specks()
		Layer.FRONT:
			_draw_vignette()


func _draw_water() -> void:
	var points := PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(view.x, 0.0),
			Vector2(view.x, view.y * 0.5),
			Vector2(0.0, view.y * 0.5)
		]
	)
	draw_polygon(points, PackedColorArray([TOP_COLOR, TOP_COLOR, MID_COLOR, MID_COLOR]))
	points = PackedVector2Array(
		[
			Vector2(0.0, view.y * 0.5),
			Vector2(view.x, view.y * 0.5),
			Vector2(view.x, view.y),
			Vector2(0.0, view.y),
		]
	)
	draw_polygon(points, PackedColorArray([MID_COLOR, MID_COLOR, DEEP_COLOR, DEEP_COLOR]))


## Slanted beams from the surface that sway slowly and slide against the camera.
func _draw_shafts() -> void:
	for i: int in SHAFT_COUNT:
		var seed_value: float = float(i) * 1.7
		var x: float = (
			fposmod(view.x * (float(i) + 0.5) / float(SHAFT_COUNT) - cam_x * 0.12, view.x * 1.4)
			- view.x * 0.2
		)
		var sway: float = sin(time * 0.15 + seed_value) * 40.0
		var width: float = 60.0 + 50.0 * fposmod(seed_value, 1.0)
		var slant: float = view.y * 0.45
		var strength: float = 0.05 + 0.04 * sin(time * 0.3 + seed_value * 2.0)
		var shaft := PackedVector2Array(
			[
				Vector2(x + sway, 0.0),
				Vector2(x + sway + width, 0.0),
				Vector2(x + sway + width * 2.4 - slant, view.y),
				Vector2(x + sway - width * 0.4 - slant, view.y),
			]
		)
		var top: Color = Color(0.5, 0.92, 1.0, strength)
		var bottom: Color = Color(0.5, 0.92, 1.0, 0.0)
		draw_polygon(shaft, PackedColorArray([top, top, bottom, bottom]))


## One depth of seabed: a ridge of the ground and kelp growing from it. Farther layers are
## darker, bluer and follow the camera less.
func _draw_seabed(depth: int) -> void:
	var k: float = float(depth) / float(KELP_LAYERS - 1)
	var parallax: float = lerpf(0.15, 0.7, k)
	var ground: float = view.y * lerpf(0.86, 0.94, k)
	var shade: float = lerpf(0.2, 0.55, k)
	var rock: Color = Color(0.02 + 0.05 * shade, 0.05 + 0.1 * shade, 0.09 + 0.13 * shade)
	var ridge := PackedVector2Array([Vector2(0.0, view.y)])
	var steps: int = 24
	for i: int in steps + 1:
		var x: float = view.x * float(i) / float(steps)
		var world: float = x + cam_x * parallax
		ridge.append(
			Vector2(
				x,
				(
					ground
					- 18.0 * (1.0 + sin(world * 0.011 + float(depth) * 2.0))
					- 8.0 * sin(world * 0.03)
				)
			)
		)
	ridge.append(Vector2(view.x, view.y))
	draw_colored_polygon(ridge, rock)
	var kelp_color: Color = Color(0.03 + 0.05 * shade, 0.16 + 0.22 * shade, 0.16 + 0.2 * shade)
	var tip_color: Color = Color(0.2, 0.9, 0.7, 0.18 * shade + 0.05)
	var span: float = view.x * 1.5
	for i: int in KELP_PER_LAYER:
		var seed_value: float = float(i * 7 + depth * 3)
		var x: float = (
			fposmod(span * float(i) / float(KELP_PER_LAYER) - cam_x * parallax, span)
			- view.x * 0.25
		)
		var height: float = view.y * lerpf(0.22, 0.4, fposmod(seed_value * 0.37, 1.0))
		var blade := PackedVector2Array()
		for j: int in 6:
			var u: float = float(j) / 5.0
			var sway: float = sin(time * 0.8 + seed_value + u * 2.4) * 16.0 * u
			blade.append(Vector2(x + sway, ground - 10.0 - height * u))
		draw_polyline(blade, kelp_color, lerpf(5.0, 9.0, k))
		draw_circle(blade[5], lerpf(3.0, 5.0, k), tip_color)


## Marine snow: tiny specks that sink slowly and follow the camera a little.
func _draw_specks() -> void:
	for i: int in SPECK_COUNT:
		var h: float = fposmod(float(i) * 0.6180339, 1.0)
		var depth: float = fposmod(float(i) * 0.4142136, 1.0)
		var x: float = (
			fposmod(h * view.x * 1.3 - cam_x * lerpf(0.9, 0.3, depth), view.x * 1.3) - view.x * 0.15
		)
		var y: float = fposmod(depth * view.y * 1.7 + time * lerpf(14.0, 5.0, depth), view.y)
		var glint: float = 0.5 + 0.5 * sin(time * 1.5 + float(i))
		draw_circle(
			Vector2(x, y),
			lerpf(2.0, 0.8, depth),
			Color(0.7, 0.95, 1.0, 0.05 + 0.12 * glint * (1.0 - depth))
		)


## Fog that thickens toward the top and the bottom, and dark corners.
func _draw_vignette() -> void:
	var edge: float = view.y * FOG_EDGE
	var dark: Color = Color(0.0, 0.01, 0.03, 0.55)
	var clear: Color = Color(0.0, 0.01, 0.03, 0.0)
	draw_polygon(
		PackedVector2Array(
			[Vector2.ZERO, Vector2(view.x, 0.0), Vector2(view.x, edge), Vector2(0.0, edge)]
		),
		PackedColorArray([dark, dark, clear, clear])
	)
	draw_polygon(
		PackedVector2Array(
			[
				Vector2(0.0, view.y - edge),
				Vector2(view.x, view.y - edge),
				Vector2(view.x, view.y),
				Vector2(0.0, view.y)
			]
		),
		PackedColorArray([clear, clear, dark, dark])
	)
	var side: float = view.x * 0.16
	draw_polygon(
		PackedVector2Array(
			[Vector2.ZERO, Vector2(side, 0.0), Vector2(side, view.y), Vector2(0.0, view.y)]
		),
		PackedColorArray([dark, clear, clear, dark])
	)
	draw_polygon(
		PackedVector2Array(
			[
				Vector2(view.x - side, 0.0),
				Vector2(view.x, 0.0),
				Vector2(view.x, view.y),
				Vector2(view.x - side, view.y)
			]
		),
		PackedColorArray([clear, dark, dark, clear])
	)
