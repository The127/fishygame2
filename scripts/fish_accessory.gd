class_name FishAccessory
extends RefCounted
## Funny cosmetic accessories drawn on a [FishVisual]. Purely visual: drawn in the fish's own
## space (head towards +x, up is -y), so they follow its rotation and flip. Sizes are small
## so a full lobby stays readable.

## The accessories, in the order of [constant ShopCatalog.HAT_NAMES]; NONE draws nothing.
enum Kind {
	NONE, TOP_HAT, PARTY_HAT, SHADES, CROWN, BOW_TIE, PIRATE_HAT, CAT_EARS, SNORKEL, FLOWER, DUCK
}

const RIM: Color = Color(0.01, 0.02, 0.035, 0.95)
const GOLD: Color = Color(1.0, 0.82, 0.25)
const RED: Color = Color(0.95, 0.2, 0.3)
const PINK: Color = Color(1.0, 0.55, 0.75)
const YELLOW: Color = Color(1.0, 0.9, 0.3)
const DARK: Color = Color(0.13, 0.13, 0.17)


## Draws accessory [param kind] on [param canvas] (during its draw). [param top] is a point on
## the back of the head, [param eye] the eye and [param chin] a point under the head.
static func draw(canvas: CanvasItem, kind: int, top: Vector2, eye: Vector2, chin: Vector2) -> void:
	match kind:
		Kind.TOP_HAT:
			_top_hat(canvas, top)
		Kind.PARTY_HAT:
			_party_hat(canvas, top)
		Kind.SHADES:
			_shades(canvas, eye)
		Kind.CROWN:
			_crown(canvas, top)
		Kind.BOW_TIE:
			_bow_tie(canvas, chin)
		Kind.PIRATE_HAT:
			_pirate_hat(canvas, top)
		Kind.CAT_EARS:
			_cat_ears(canvas, top)
		Kind.SNORKEL:
			_snorkel(canvas, top, eye)
		Kind.FLOWER:
			_flower(canvas, top)
		Kind.DUCK:
			_duck(canvas, top)


static func _poly(canvas: CanvasItem, points: PackedVector2Array, fill: Color) -> void:
	canvas.draw_colored_polygon(points, fill)
	canvas.draw_polyline(points + PackedVector2Array([points[0]]), RIM, 1.3)


static func _ball(canvas: CanvasItem, at: Vector2, radius: float, fill: Color) -> void:
	canvas.draw_circle(at, radius + 0.9, RIM)
	canvas.draw_circle(at, radius, fill)


static func _top_hat(canvas: CanvasItem, p: Vector2) -> void:
	_poly(canvas, _box(p + Vector2(0, -0.5), 6.0, 1.6), DARK)
	_poly(canvas, _box(p + Vector2(0, -5.5), 3.8, 5.0), DARK)
	canvas.draw_rect(Rect2(p + Vector2(-3.8, -3.6), Vector2(7.6, 1.6)), RED)


static func _party_hat(canvas: CanvasItem, p: Vector2) -> void:
	var tip: Vector2 = p + Vector2(-1.0, -12.0)
	_poly(canvas, PackedVector2Array([p + Vector2(-4.5, 0.0), tip, p + Vector2(4.5, 0.0)]), PINK)
	canvas.draw_circle(p + Vector2(-1.5, -4.0), 1.0, YELLOW)
	canvas.draw_circle(p + Vector2(1.2, -6.5), 0.9, Color.WHITE)
	_ball(canvas, tip, 1.6, YELLOW)


static func _shades(canvas: CanvasItem, eye: Vector2) -> void:
	canvas.draw_line(eye + Vector2(-2.0, 0.0), eye + Vector2(-9.0, -1.0), RIM, 2.2)
	canvas.draw_circle(eye, 4.6, RIM)
	canvas.draw_circle(eye, 3.7, Color(0.03, 0.03, 0.06))
	canvas.draw_line(eye + Vector2(-2.2, -1.6), eye + Vector2(0.0, -2.8), Color(1, 1, 1, 0.8), 1.0)


static func _crown(canvas: CanvasItem, p: Vector2) -> void:
	var base: Vector2 = p + Vector2(0.0, 0.5)
	_poly(
		canvas,
		PackedVector2Array(
			[
				base + Vector2(-4.5, 0.0),
				base + Vector2(-4.5, -7.0),
				base + Vector2(-2.2, -3.8),
				base + Vector2(0.0, -8.0),
				base + Vector2(2.2, -3.8),
				base + Vector2(4.5, -7.0),
				base + Vector2(4.5, 0.0),
			]
		),
		GOLD
	)
	canvas.draw_circle(base + Vector2(0.0, -1.8), 1.0, RED)


static func _bow_tie(canvas: CanvasItem, c: Vector2) -> void:
	_poly(canvas, PackedVector2Array([c, c + Vector2(-5.0, -3.0), c + Vector2(-5.0, 3.0)]), RED)
	_poly(canvas, PackedVector2Array([c, c + Vector2(5.0, -3.0), c + Vector2(5.0, 3.0)]), RED)
	_ball(canvas, c, 1.6, Color(0.7, 0.1, 0.2))


static func _pirate_hat(canvas: CanvasItem, p: Vector2) -> void:
	_poly(
		canvas,
		PackedVector2Array(
			[
				p + Vector2(-8.0, 0.5),
				p + Vector2(-5.0, -6.5),
				p + Vector2(0.0, -8.0),
				p + Vector2(5.0, -6.5),
				p + Vector2(8.0, 0.5),
				p + Vector2(0.0, -2.0),
			]
		),
		DARK
	)
	canvas.draw_circle(p + Vector2(0.0, -4.4), 1.6, Color.WHITE)
	canvas.draw_line(p + Vector2(-2.6, -2.6), p + Vector2(2.6, -2.6), Color.WHITE, 0.9)


static func _cat_ears(canvas: CanvasItem, p: Vector2) -> void:
	for x: float in [-3.5, 3.0]:
		var base: Vector2 = p + Vector2(x, 0.5)
		_poly(
			canvas,
			PackedVector2Array(
				[base + Vector2(-3.0, 0.0), base + Vector2(0.0, -8.0), base + Vector2(3.0, 0.0)]
			),
			DARK
		)
		canvas.draw_colored_polygon(
			PackedVector2Array(
				[base + Vector2(-1.4, -0.4), base + Vector2(0.0, -4.8), base + Vector2(1.4, -0.4)]
			),
			PINK
		)


static func _snorkel(canvas: CanvasItem, p: Vector2, eye: Vector2) -> void:
	var tube := PackedVector2Array(
		[eye + Vector2(-3.0, -3.0), p + Vector2(-4.0, -3.0), p + Vector2(-6.0, -9.0)]
	)
	canvas.draw_polyline(tube, RIM, 3.4)
	canvas.draw_polyline(tube, Color(1.0, 0.6, 0.15), 2.0)
	canvas.draw_line(p + Vector2(-6.0, -9.0), p + Vector2(-9.0, -9.0), Color(1.0, 0.6, 0.15), 2.0)
	canvas.draw_circle(eye, 5.4, RIM)
	canvas.draw_circle(eye, 4.5, Color(0.6, 0.9, 1.0, 0.85))
	canvas.draw_circle(eye, 2.3, RIM)
	canvas.draw_circle(eye, 1.5, Color.WHITE)


static func _flower(canvas: CanvasItem, p: Vector2) -> void:
	var c: Vector2 = p + Vector2(-1.0, -4.5)
	canvas.draw_line(p, c, Color(0.2, 0.7, 0.3), 1.4)
	for i: int in 5:
		_ball(canvas, c + Vector2.from_angle(TAU * float(i) / 5.0) * 2.7, 1.9, PINK)
	_ball(canvas, c, 1.7, YELLOW)


static func _duck(canvas: CanvasItem, p: Vector2) -> void:
	var body: Vector2 = p + Vector2(-1.0, -3.6)
	var head: Vector2 = body + Vector2(2.6, -3.0)
	_ball(canvas, body, 4.0, YELLOW)
	_ball(canvas, head, 2.6, YELLOW)
	_poly(
		canvas,
		PackedVector2Array(
			[head + Vector2(2.0, -0.6), head + Vector2(4.4, 0.4), head + Vector2(2.0, 1.2)]
		),
		Color(1.0, 0.5, 0.1)
	)
	canvas.draw_circle(head + Vector2(0.6, -0.7), 0.6, RIM)


## A rectangle of half width [param hw] and half height [param hh] around [param c].
static func _box(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array(
		[c + Vector2(-hw, -hh), c + Vector2(hw, -hh), c + Vector2(hw, hh), c + Vector2(-hw, hh)]
	)
