class_name AnglerLure
extends Node2D
## Scenery: a glowing anglerfish lure on a curved stalk, optionally with the fish's dark
## silhouette behind it. On the Abyss map these are the light of the place. Flip with a
## negative scale.x.

const STALK_POINTS: int = 12
const TEETH: int = 7
const HUNT_COLOR: Color = Color(1.0, 0.25, 0.2)
## Hinge of the lower jaw and its widest opening, in radians.
const JAW_PIVOT: Vector2 = Vector2(30.0, 30.0)
const JAW_OPEN_ANGLE: float = 0.75

@export var tint: Color = Color(0.4, 1.0, 0.85)
@export var stalk_length: float = 90.0
## Radius of the pool of light the lure casts around itself.
@export var light_radius: float = 260.0
## Draw the fish's body, jaw and eye as well.
@export var show_body: bool = false
## Size of the fish's body (the stalk and light stay the same).
@export var body_scale: float = 1.0
@export var phase: float = 0.0

## 0 to 1: the lure flares and the eye burns red, while an angler hunts.
var excite: float = 0.0
## 0 to 1: how wide the jaw gapes.
var mouth_open: float = 0.0

var _time: float = 0.0


func _ready() -> void:
	z_index = -30


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## The bulb's position in this node's local space.
func bulb_position() -> Vector2:
	return _stalk()[STALK_POINTS]


## Where the jaws meet, in this node's local space.
func mouth_position() -> Vector2:
	return (Vector2(-60.0, 40.0) + Vector2(100.0, 14.0)) * body_scale


func _stalk() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in STALK_POINTS + 1:
		var t: float = float(i) / float(STALK_POINTS)
		points.append(
			Vector2(t * stalk_length * 0.8, -stalk_length * sin(t * 1.7) * 0.75 + t * t * 24.0)
		)
	return points


func _draw() -> void:
	var pulse: float = (0.8 + 0.2 * sin(_time * 1.7 + phase)) * (1.0 + 0.9 * excite)
	var stalk: PackedVector2Array = _stalk()
	var bulb: Vector2 = stalk[STALK_POINTS]
	var dark: Color = Color(0.01, 0.02, 0.035)
	if show_body:
		_draw_body(dark)
	draw_polyline(stalk, dark, 4.0, true)
	draw_polyline(stalk, Color(tint, 0.25), 1.2, true)
	var size: float = light_radius * 2.0
	draw_texture_rect(
		RaceFx.glow_texture(),
		Rect2(bulb - Vector2.ONE * light_radius, Vector2.ONE * size),
		false,
		Color(tint, minf(0.2 * pulse, 0.5))
	)
	var halo: float = 34.0 * pulse
	draw_texture_rect(
		RaceFx.glow_texture(),
		Rect2(bulb - Vector2.ONE * halo, Vector2.ONE * halo * 2.0),
		false,
		Color(tint, 0.85)
	)
	draw_circle(bulb, 6.0, tint.lightened(0.6))


func _draw_body(dark: Color) -> void:
	# The forehead (where the stalk grows) sits at this node's origin.
	var size: float = body_scale
	var origin: Vector2 = Vector2(-60.0, 40.0) * size
	draw_set_transform(origin, 0.0, Vector2(size, size))
	var body: PackedVector2Array = PackedVector2Array(
		[
			Vector2(-20, 24),
			Vector2(-10, -18),
			Vector2(20, -44),
			Vector2(60, -40),
			Vector2(96, -14),
			Vector2(100, 8),
			Vector2(74, 22),
			Vector2(20, 40),
		]
	)
	draw_colored_polygon(body, dark)
	draw_polyline(body + PackedVector2Array([body[0]]), Color(tint, 0.16 + 0.4 * excite), 1.5, true)
	if mouth_open > 0.02:
		_draw_open_jaws(origin, size, dark)
		draw_set_transform(origin, 0.0, Vector2(size, size))
	else:
		for i: int in TEETH:
			var x: float = 70.0 - float(i) * 12.0
			draw_colored_polygon(
				PackedVector2Array(
					[Vector2(x, 14.0), Vector2(x - 4.0, 30.0), Vector2(x - 8.0, 16.0)]
				),
				Color(0.75, 0.9, 0.95, 0.75)
			)
	var eye: Color = tint.lerp(HUNT_COLOR, excite)
	draw_circle(Vector2(66, -14), 6.0 + 3.0 * excite, Color(eye, 0.5 + 0.4 * excite))
	draw_circle(Vector2(67, -14), 2.5, dark)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## The mouth gapes: a glowing throat, the lower jaw swung down on its hinge, and teeth on both.
func _draw_open_jaws(origin: Vector2, size: float, dark: Color) -> void:
	var angle: float = JAW_OPEN_ANGLE * mouth_open
	var tooth: Color = Color(0.85, 0.95, 1.0, 0.9)
	var throat: PackedVector2Array = PackedVector2Array(
		[
			Vector2(40.0, 20.0),
			Vector2(98.0, 12.0),
			JAW_PIVOT + Vector2(72.0, 12.0).rotated(angle),
			JAW_PIVOT + Vector2(0.0, 10.0).rotated(angle),
		]
	)
	draw_colored_polygon(throat, Color(0.35, 0.03, 0.06))
	draw_colored_polygon(throat, Color(HUNT_COLOR, 0.25 * mouth_open))
	for i: int in TEETH:
		var x: float = 94.0 - float(i) * 10.0
		draw_colored_polygon(
			PackedVector2Array([Vector2(x, 12.0), Vector2(x - 4.0, 26.0), Vector2(x - 8.0, 13.0)]),
			tooth
		)
	# Rotating about the hinge: draw relative to it under a rotated transform.
	draw_set_transform(origin + JAW_PIVOT * size, angle, Vector2(size, size))
	var jaw: PackedVector2Array = PackedVector2Array(
		[
			Vector2(0.0, -4.0),
			Vector2(68.0, -8.0),
			Vector2(70.0, 8.0),
			Vector2(34.0, 16.0),
			Vector2(-8.0, 12.0),
		]
	)
	draw_colored_polygon(jaw, dark)
	draw_polyline(jaw + PackedVector2Array([jaw[0]]), Color(tint, 0.16), 1.5, true)
	for i: int in TEETH - 2:
		var x: float = 64.0 - float(i) * 11.0
		draw_colored_polygon(
			PackedVector2Array([Vector2(x, -8.0), Vector2(x - 4.0, -22.0), Vector2(x - 8.0, -9.0)]),
			tooth
		)
