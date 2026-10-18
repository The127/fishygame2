class_name Trophy
extends RefCounted
## A gold cup drawn from code, so any CanvasItem can draw one at any size.

## Height of the winner's cup on the podium. The participation trophy is three times this.
const WINNER_HEIGHT: float = 56.0
const GOLD: Color = Color(1.0, 0.8, 0.25)
const GOLD_DARK: Color = Color(0.7, 0.47, 0.08)
const GOLD_LIGHT: Color = Color(1.0, 0.95, 0.7)
const OUTLINE: Color = Color(0.0, 0.03, 0.08, 0.95)
const BOWL_POINTS: int = 12


## Draws a cup `height` tall standing on `bottom` (the middle of its base).
static func draw(canvas: CanvasItem, bottom: Vector2, height: float) -> void:
	var h: float = height
	var line: float = maxf(2.0, h * 0.035)
	# Base and plinth.
	var base := Rect2(bottom.x - h * 0.31, bottom.y - h * 0.12, h * 0.62, h * 0.12)
	var plinth := Rect2(bottom.x - h * 0.22, base.position.y - h * 0.08, h * 0.44, h * 0.08)
	for rect: Rect2 in [base, plinth]:
		canvas.draw_rect(rect.grow(line * 0.5), OUTLINE)
		canvas.draw_rect(rect, GOLD_DARK)
	# Stem with a knot.
	var stem := Rect2(bottom.x - h * 0.05, bottom.y - h * 0.47, h * 0.1, h * 0.27)
	canvas.draw_rect(stem.grow(line * 0.5), OUTLINE)
	canvas.draw_rect(stem, GOLD)
	var knot := Rect2(bottom.x - h * 0.1, bottom.y - h * 0.4, h * 0.2, h * 0.05)
	canvas.draw_rect(knot.grow(line * 0.5), OUTLINE)
	canvas.draw_rect(knot, GOLD_DARK)
	# Handles behind the bowl.
	for side: float in [-1.0, 1.0]:
		var center := Vector2(bottom.x + side * h * 0.33, bottom.y - h * 0.82)
		var from: float = PI * 0.5 if side < 0.0 else -PI * 0.5
		canvas.draw_arc(center, h * 0.13, from, from + PI, 16, OUTLINE, h * 0.07 + line)
		canvas.draw_arc(center, h * 0.13, from, from + PI, 16, GOLD_DARK, h * 0.07)
	# Bowl: a U from the rim down to the stem.
	var bowl := PackedVector2Array()
	var top: float = bottom.y - h
	var depth: float = h * 0.53
	for i: int in BOWL_POINTS + 1:
		var t: float = float(i) / BOWL_POINTS
		var half: float = maxf(h * 0.06, h * 0.36 * sqrt(1.0 - t * t))
		bowl.append(Vector2(bottom.x + half, top + t * depth))
	for i: int in range(BOWL_POINTS, -1, -1):
		bowl.append(Vector2(bottom.x - (bowl[i].x - bottom.x), bowl[i].y))
	canvas.draw_colored_polygon(bowl, GOLD)
	var closed: PackedVector2Array = bowl.duplicate()
	closed.append(bowl[0])
	canvas.draw_polyline(closed, OUTLINE, line)
	# Shine down the left side, and the rim.
	var shine := Rect2(bottom.x - h * 0.24, top + h * 0.08, h * 0.07, h * 0.28)
	canvas.draw_rect(shine, Color(GOLD_LIGHT, 0.85))
	var rim := Rect2(bottom.x - h * 0.38, top - h * 0.02, h * 0.76, h * 0.05)
	canvas.draw_rect(rim.grow(line * 0.5), OUTLINE)
	canvas.draw_rect(rim, GOLD_LIGHT)
