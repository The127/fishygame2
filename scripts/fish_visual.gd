class_name FishVisual
extends Node2D
## Procedural fish drawing. It faces its `heading` (radians) and never spins
## with the rolling body, so the fish stays right side up.

## Markings that tell fish apart without color; see [FishPalette].
enum Pattern { SOLID, STRIPES, SPOTS, LINES, CHEVRONS }

## Body shapes, picked per marble so fish read by outline. `length` and `height` are
## half extents, `peak` shifts the deepest point (below 1 toward the head), `tail` is
## the tail fin length, `dorsal` and `belly` the fin heights.
const SPECIES: Array[Dictionary] = [
	{
		"length": 15.0,
		"height": 8.0,
		"peak": 0.85,
		"tail": 9.0,
		"spread": 7.0,
		"dorsal": 6.0,
		"belly": 3.0
	},
	{
		"length": 12.0,
		"height": 11.0,
		"peak": 1.0,
		"tail": 6.0,
		"spread": 6.0,
		"dorsal": 9.0,
		"belly": 6.0
	},
	{
		"length": 17.0,
		"height": 5.5,
		"peak": 1.1,
		"tail": 8.0,
		"spread": 4.0,
		"dorsal": 4.0,
		"belly": 2.0
	},
	{
		"length": 14.0,
		"height": 10.0,
		"peak": 0.7,
		"tail": 7.0,
		"spread": 8.0,
		"dorsal": 10.0,
		"belly": 8.0
	},
]
const OUTLINE: Color = Color(0.01, 0.02, 0.035, 0.95)
const MARK: Color = Color(0.96, 0.98, 1.0, 0.95)
const BODY_STEPS: int = 20

var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()

## Index into SPECIES, wrapped.
var species: int = 0
## A [enum Pattern], wrapped.
var pattern: int = 0:
	set(value):
		pattern = value
		queue_redraw()
var heading: float = 0.0
## Steady glow tint, e.g. a curse. Transparent means the glow follows `color`.
var aura: Color = Color.TRANSPARENT
## While true the glow pulses gold.
var celebrating: bool = false

var _time: float = randf() * TAU
var _speed: float = 0.0
var _flash_color: Color = Color.WHITE
var _flash_total: float = 0.0
var _flash_left: float = 0.0
var _glow: Sprite2D


func _ready() -> void:
	top_level = true
	z_index = 5
	_glow = Sprite2D.new()
	_glow.texture = RaceFx.glow_texture()
	_glow.material = RaceFx.additive_material()
	_glow.show_behind_parent = true
	add_child(_glow)
	_update_glow()


func _process(delta: float) -> void:
	_time += delta
	_flash_left = maxf(_flash_left - delta, 0.0)
	_update_glow()
	queue_redraw()


## A short bright pulse of the glow in `flash_tint`, fading over `seconds`.
func flash(flash_tint: Color, seconds: float = 0.6) -> void:
	_flash_color = flash_tint
	_flash_total = seconds
	_flash_left = seconds


## Points the fish along a travel direction. Slow or still marbles keep their last heading.
func face(velocity: Vector2, delta: float) -> void:
	_speed = velocity.length()
	if velocity.length() > 20.0:
		heading = lerp_angle(heading, velocity.angle(), clampf(delta * 10.0, 0.0, 1.0))
	global_position = get_parent().global_position
	# Flip vertically when swimming left so the dorsal fin stays on top.
	var facing_left: bool = absf(wrapf(heading, -PI, PI)) > PI * 0.5
	rotation = heading
	scale = Vector2(1.0, -1.0 if facing_left else 1.0)


func _update_glow() -> void:
	var tint: Color = color.lightened(0.3)
	tint.a = 0.28
	var glow_scale: float = 1.0
	if aura.a > 0.0:
		tint = Color(aura.r, aura.g, aura.b, 0.5)
	if celebrating:
		var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
		tint = RaceFx.WINNER_COLOR
		tint.a = 0.4 + 0.4 * pulse
		glow_scale += 0.5 * pulse
	if _flash_left > 0.0 and _flash_total > 0.0:
		var k: float = _flash_left / _flash_total
		tint = tint.lerp(Color(_flash_color.r, _flash_color.g, _flash_color.b, 0.95), k)
		glow_scale += 0.9 * k
	_glow.modulate = tint
	_glow.scale = Vector2.ONE * glow_scale * 1.1


func _draw() -> void:
	var sp: Dictionary = SPECIES[posmod(species, SPECIES.size())]
	var length: float = sp["length"]
	var height: float = sp["height"]
	var swim: float = clampf(_speed / 300.0, 0.0, 1.0)
	var wag: float = sin(_time * (7.0 + 5.0 * swim)) * (1.5 + 2.5 * swim)
	var flutter: float = sin(_time * 6.0 + 1.3) * 1.5
	# Dark, desaturated body; the viewer color lives in the glowing accents.
	var back: Color = Color.from_hsv(color.h, color.s * 0.95, color.v * 0.5)
	var belly_col: Color = Color.from_hsv(color.h, color.s * 0.7, color.v * 0.85)
	var fin_col: Color = Color.from_hsv(color.h, color.s, color.v * 0.7, 0.92)
	var accent: Color = color.lightened(0.25)
	var pulse: float = 0.75 + 0.25 * sin(_time * 2.5)
	_draw_tail(sp, fin_col, accent, wag)
	_draw_fins(sp, fin_col, accent, flutter)
	# Body: shaded back to belly, dark rim so it separates from the background.
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i: int in BODY_STEPS + 1:
		var u: float = float(i) / float(BODY_STEPS)
		var h: float = _body_half_height(sp, u)
		var x: float = length - 2.0 * length * u
		top.append(Vector2(x, -h))
		bottom.append(Vector2(x, h * 0.9))
	var body := PackedVector2Array(top)
	var colors := PackedColorArray()
	for i: int in bottom.size():
		body.append(bottom[bottom.size() - 1 - i])
	for p: Vector2 in body:
		colors.append(back.lerp(belly_col, clampf(p.y / height * 0.5 + 0.5, 0.0, 1.0)))
	draw_polygon(body, colors)
	draw_polyline(body + PackedVector2Array([body[0]]), OUTLINE, 2.5)
	_draw_pattern(sp)
	# Glowing lateral stripe and back edge.
	var stripe := PackedVector2Array()
	for i: int in 9:
		var x: float = lerpf(length * 0.55, -length * 0.75, float(i) / 8.0)
		stripe.append(Vector2(x, -height * 0.05 + sin(float(i) * 0.9 + _time * 3.0) * 0.5))
	draw_polyline(stripe, Color(accent.r, accent.g, accent.b, pulse), 1.8)
	draw_polyline(top, Color(accent.r, accent.g, accent.b, 0.55), 1.0)
	# Glowing eye.
	var eye := Vector2(length * 0.5, -height * 0.25)
	draw_circle(eye, 3.2, OUTLINE)
	draw_circle(eye, 2.2, accent.lightened(0.5))
	draw_circle(eye + Vector2(0.6, 0), 1.0, OUTLINE)


## Half the body height at [param u], 0 at the snout and 1 at the tail.
func _body_half_height(sp: Dictionary, u: float) -> float:
	var height: float = sp["height"]
	return maxf(height * pow(sin(PI * pow(u, sp["peak"])), 0.8), height * 0.16)


## Markings on the body: a bright core over a dark edge so they read on any body color.
func _draw_pattern(sp: Dictionary) -> void:
	var length: float = sp["length"]
	match posmod(pattern, Pattern.size()):
		Pattern.STRIPES:
			for u: float in [0.34, 0.5, 0.66]:
				var x: float = length - 2.0 * length * u
				var h: float = _body_half_height(sp, u)
				_mark_line(PackedVector2Array([Vector2(x, -h * 0.85), Vector2(x, h * 0.75)]), 2.4)
		Pattern.SPOTS:
			var side: float = -1.0
			for u: float in [0.3, 0.42, 0.54, 0.66, 0.78]:
				var x: float = length - 2.0 * length * u
				_mark_dot(Vector2(x, side * _body_half_height(sp, u) * 0.45), 2.0)
				side = -side
		Pattern.LINES:
			for side: float in [-0.5, 0.5]:
				var line := PackedVector2Array()
				for i: int in 6:
					var u: float = lerpf(0.28, 0.8, float(i) / 5.0)
					var x: float = length - 2.0 * length * u
					line.append(Vector2(x, side * _body_half_height(sp, u)))
				_mark_line(line, 1.6)
		Pattern.CHEVRONS:
			for u: float in [0.4, 0.6]:
				var x: float = length - 2.0 * length * u
				var h: float = _body_half_height(sp, u) * 0.6
				var back: float = length * 0.22
				_mark_line(
					PackedVector2Array(
						[Vector2(x - back, -h), Vector2(x, 0.0), Vector2(x - back, h)]
					),
					1.8
				)


func _mark_line(points: PackedVector2Array, width: float) -> void:
	draw_polyline(points, OUTLINE, width + 1.8)
	draw_polyline(points, MARK, width)


func _mark_dot(at: Vector2, radius: float) -> void:
	draw_circle(at, radius + 0.9, OUTLINE)
	draw_circle(at, radius, MARK)


func _draw_tail(sp: Dictionary, fin_col: Color, accent: Color, wag: float) -> void:
	var length: float = sp["length"]
	var tail: float = sp["tail"]
	var spread: float = sp["spread"]
	var base := Vector2(-length * 0.85, 0.0)
	var points := PackedVector2Array(
		[
			base + Vector2(0.0, -1.5),
			Vector2(-length - tail, -spread + wag),
			Vector2(-length - tail * 0.55, wag * 0.5),
			Vector2(-length - tail, spread + wag),
			base + Vector2(0.0, 1.5),
		]
	)
	draw_colored_polygon(points, fin_col)
	draw_polyline(points.slice(1, 4), Color(accent.r, accent.g, accent.b, 0.8), 1.2)
	draw_polyline(points, OUTLINE, 1.5)


func _draw_fins(sp: Dictionary, fin_col: Color, accent: Color, flutter: float) -> void:
	var length: float = sp["length"]
	var height: float = sp["height"]
	var dorsal: float = sp["dorsal"]
	var belly: float = sp["belly"]
	var edge := Color(accent.r, accent.g, accent.b, 0.8)
	var top_fin := PackedVector2Array(
		[
			Vector2(length * 0.2, -height * 0.8),
			Vector2(-length * 0.15 + flutter, -height - dorsal),
			Vector2(-length * 0.55, -height * 0.7),
		]
	)
	var bottom_fin := PackedVector2Array(
		[
			Vector2(length * 0.05, height * 0.8),
			Vector2(-length * 0.25 - flutter, height + belly),
			Vector2(-length * 0.5, height * 0.65),
		]
	)
	for fin: PackedVector2Array in [top_fin, bottom_fin]:
		draw_colored_polygon(fin, fin_col)
		draw_polyline(fin, OUTLINE, 1.5)
		draw_line(fin[0], fin[1], edge, 1.2)
