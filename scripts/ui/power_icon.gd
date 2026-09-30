class_name PowerIcon
extends RefCounted
## The drawn icons of the streamer powers: a rod with a hook, a net and a bubble blast.
## Drawn with line primitives so there are no image assets. Sizes are the icon's half extent.


## Draws the icon of [param kind] (a [enum StreamerPowers.Kind]) centred on [param center].
static func draw(
	canvas: CanvasItem,
	kind: int,
	center: Vector2,
	half: float,
	color: Color,
	width: float = 2.0,
) -> void:
	match kind:
		StreamerPowers.Kind.ROD:
			_draw_rod(canvas, center, half, color, width)
		StreamerPowers.Kind.NET:
			_draw_net(canvas, center, half, color, width)
		StreamerPowers.Kind.BLAST:
			_draw_blast(canvas, center, half, color, width)


static func _draw_rod(canvas: CanvasItem, c: Vector2, h: float, color: Color, width: float) -> void:
	var handle: Vector2 = c + Vector2(-h, h * 0.6)
	var tip: Vector2 = c + Vector2(h * 0.7, -h * 0.9)
	canvas.draw_line(handle, tip, color, width + 0.5)
	var bottom: Vector2 = tip + Vector2(0.0, h * 1.0)
	canvas.draw_line(tip, bottom, Color(color, color.a * 0.8), width * 0.6)
	# The hook: a half circle opening upwards, with a small barb.
	var hook_r: float = h * 0.3
	var hook_c: Vector2 = bottom + Vector2(-hook_r, 0.0)
	canvas.draw_arc(hook_c, hook_r, 0.0, PI, 10, color, width)
	var barb: Vector2 = hook_c + Vector2(-hook_r, 0.0)
	canvas.draw_line(barb, barb + Vector2(-2.0, -3.0), color, width)


static func _draw_net(canvas: CanvasItem, c: Vector2, h: float, color: Color, width: float) -> void:
	canvas.draw_arc(c, h, 0.0, TAU, 24, color, width)
	var thin: Color = Color(color, color.a * 0.7)
	for k: int in [-1, 0, 1]:
		var offset: float = float(k) * h * 0.5
		var reach: float = sqrt(maxf(0.0, h * h - offset * offset))
		canvas.draw_line(c + Vector2(-reach, offset), c + Vector2(reach, offset), thin, width * 0.6)
		canvas.draw_line(c + Vector2(offset, -reach), c + Vector2(offset, reach), thin, width * 0.6)


static func _draw_blast(
	canvas: CanvasItem, c: Vector2, h: float, color: Color, width: float
) -> void:
	var big: Vector2 = c + Vector2(-h * 0.15, h * 0.1)
	canvas.draw_arc(big, h * 0.55, 0.0, TAU, 20, color, width)
	canvas.draw_arc(c + Vector2(h * 0.6, -h * 0.5), h * 0.3, 0.0, TAU, 14, color, width)
	canvas.draw_arc(c + Vector2(h * 0.5, h * 0.65), h * 0.22, 0.0, TAU, 12, color, width)
	canvas.draw_arc(c + Vector2(-h * 0.75, -h * 0.65), h * 0.18, 0.0, TAU, 12, color, width)
	# A glint on the big bubble.
	canvas.draw_arc(big, h * 0.35, PI * 1.1, PI * 1.45, 6, Color(color, 0.7), width * 0.7)
