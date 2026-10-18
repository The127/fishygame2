class_name LurkerEyes
extends RefCounted
## The pair of eyes a lurker watches the race with. Every lurker gets one style for good, picked
## at random on their first "#lurk" (see [Lurkers]); the style is a shop item of kind
## [constant ShopStore.KIND_EYES].

const PLAIN: String = "plain"
const GOOGLY: String = "googly"
const ANIME: String = "anime"
const SHADES: String = "shades"
const SLEEPY: String = "sleepy"
const ANGRY: String = "angry"
const STYLES: Array[String] = [PLAIN, GOOGLY, ANIME, SHADES, SLEEPY, ANGRY]

const WHITE: Color = Color(0.95, 0.97, 1.0)
const PUPIL: Color = Color(0.02, 0.03, 0.05)
const GLOW: Color = Color(1.0, 0.95, 0.6)
const LID: Color = Color(0.03, 0.04, 0.07)
const FRAME: Color = Color(0.85, 0.88, 0.95)


## A random style for a first-time lurker.
static func random_style(rng: RandomNumberGenerator) -> String:
	return STYLES[rng.randi_range(0, STYLES.size() - 1)]


## Draws the pair centered on [param at], [param size] the radius of one eye. [param look] is
## where the pupils point (length 0 to 1), [param blink] how far the lids are shut (0 to 1) and
## [param wobble] a per-frame offset the googly pupils lag behind with.
static func draw(
	canvas: CanvasItem,
	style: String,
	at: Vector2,
	size: float,
	look: Vector2,
	blink: float,
	wobble: Vector2 = Vector2.ZERO
) -> void:
	var gap: float = size * 1.25
	var eyes: Array[Vector2] = [at + Vector2(-gap, 0.0), at + Vector2(gap, 0.0)]
	match style:
		SHADES:
			_draw_shades(canvas, eyes, size, look)
			return
		GOOGLY:
			for eye: Vector2 in eyes:
				canvas.draw_circle(eye, size * 1.25, PUPIL)
				canvas.draw_circle(eye, size * 1.1, WHITE)
				var pupil: Vector2 = eye + (look * 0.5 + wobble).limit_length(0.6) * size
				canvas.draw_circle(pupil, size * 0.5, PUPIL)
		ANIME:
			for eye: Vector2 in eyes:
				_draw_eye(canvas, eye, size * 1.1, look, 0.62, Color(0.25, 0.55, 1.0))
				var shine: Vector2 = eye + look * size * 0.25
				canvas.draw_circle(shine + Vector2(-0.3, -0.35) * size, size * 0.24, WHITE)
				canvas.draw_circle(shine + Vector2(0.25, 0.3) * size, size * 0.11, WHITE)
		_:
			for eye: Vector2 in eyes:
				_draw_eye(canvas, eye, size, look, 0.42, PUPIL)
	var shut: float = blink
	if style == SLEEPY:
		shut = maxf(shut, 0.55)
	if shut > 0.0:
		for eye: Vector2 in eyes:
			_draw_lid(canvas, eye, size * (1.25 if style == ANIME else 1.05), shut)
	if style == ANGRY:
		for side: int in 2:
			var eye: Vector2 = eyes[side]
			var inner: float = 1.0 if side == 0 else -1.0
			var brow := PackedVector2Array(
				[
					eye + Vector2(-inner * size * 1.1, -size * 1.5),
					eye + Vector2(inner * size * 0.9, -size * 0.85),
				]
			)
			canvas.draw_polyline(brow, LID, size * 0.45)


## A round eye that glows a little in the dark, with its pupil turned towards [param look].
static func _draw_eye(
	canvas: CanvasItem, eye: Vector2, size: float, look: Vector2, pupil_scale: float, iris: Color
) -> void:
	canvas.draw_circle(eye, size * 1.35, Color(GLOW.r, GLOW.g, GLOW.b, 0.12))
	canvas.draw_circle(eye, size, WHITE)
	var pupil: Vector2 = eye + look.limit_length(1.0) * size * (1.0 - pupil_scale) * 0.9
	if iris != PUPIL:
		canvas.draw_circle(pupil, size * pupil_scale, iris)
		canvas.draw_circle(pupil, size * pupil_scale * 0.5, PUPIL)
	else:
		canvas.draw_circle(pupil, size * pupil_scale, PUPIL)


## The upper lid, covering the top [param shut] of the eye.
static func _draw_lid(canvas: CanvasItem, eye: Vector2, size: float, shut: float) -> void:
	if shut < 0.05:
		return
	var radius: float = size * 1.08
	# The lid's edge cuts the eye at this height, -1 the top and 1 the bottom.
	var edge: float = clampf(shut * 2.0 - 1.0, -1.0, 1.0)
	var from: float = PI - asin(edge)
	var to: float = TAU + asin(edge)
	var lid := PackedVector2Array()
	for i: int in 13:
		var angle: float = lerpf(from, to, float(i) / 12.0)
		lid.append(eye + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_colored_polygon(lid, LID)


## Cool sunglasses: no pupils, just a glint that slides towards where they are looking.
static func _draw_shades(
	canvas: CanvasItem, eyes: Array[Vector2], size: float, look: Vector2
) -> void:
	# A bright frame, so the shades read on a shadow in the dark.
	canvas.draw_line(eyes[0], eyes[1], FRAME, size * 0.35)
	for eye: Vector2 in eyes:
		var lens := Rect2(eye - Vector2(size * 1.2, size * 0.8), Vector2(size * 2.4, size * 1.5))
		canvas.draw_rect(lens.grow(size * 0.2), FRAME)
		canvas.draw_rect(lens, Color(0.1, 0.12, 0.22))
		var glint: Vector2 = eye + Vector2(look.x * size * 0.6 - size * 0.4, -size * 0.35)
		canvas.draw_line(glint, glint + Vector2(size * 0.6, size * 0.4), Color(1, 1, 1, 0.85), 2.0)
