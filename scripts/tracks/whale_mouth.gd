class_name WhaleMouth
extends Node2D
## The whale's mouth, far behind the map: a huge maw seen from the inside, with the daylight of the
## open sea beyond the teeth. The jaws open and close slowly, the tongue wobbles and a hazard can
## make the whale yawn wide ([member yawn]). Purely visual, dim and large so it reads as far away.
##
## It runs on the physics clock, so it is part of the finish replay.

const FLESH: Color = Color(0.34, 0.08, 0.22)
const FLESH_DARK: Color = Color(0.17, 0.03, 0.12)
const TONGUE: Color = Color(0.72, 0.26, 0.42)
const TOOTH: Color = Color(0.95, 0.9, 0.82)
const DAYLIGHT: Color = Color(0.55, 0.88, 0.95)
## Half width of the mouth and how far the jaws reach up and down, in pixels.
const HALF_WIDTH: float = 520.0
const JAW_REACH: float = 420.0
const TEETH: int = 12
const EDGE_STEPS: int = 24

## How wide the whale yawns on top of its slow breathing, 0 to 1. A hazard sets it.
var yawn: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	Replayable.join(self)


func _physics_process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## Makes the whale yawn `amount` wide (0 to 1). A gulp hazard calls it through a signal.
func set_yawn(amount: float) -> void:
	yawn = clampf(amount, 0.0, 1.0)


## How far the jaws are open at race time `t` (0 to 1) when the whale is not yawning: a slow
## breath.
static func breath_at(t: float) -> float:
	return 0.35 + 0.15 * sin(t * 0.55) + 0.05 * sin(t * 1.7 + 1.0)


## Half the gap between the jaws at the middle of the mouth, in pixels.
func gap_at(t: float) -> float:
	var open: float = clampf(breath_at(t) + yawn * 0.6, 0.0, 1.0)
	return lerpf(40.0, 260.0, open)


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([_clock, yawn])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_clock = Replayable.mix(from, to, weight, 0)
	yawn = Replayable.mix(from, to, weight, 1)
	queue_redraw()


func _draw() -> void:
	var gap: float = gap_at(_clock)
	_draw_daylight(gap)
	_draw_tongue(gap)
	_draw_jaw(gap, -1.0)
	_draw_jaw(gap, 1.0)


## Where the edge of a jaw lies at `x`: a curve closing to the corners of the mouth.
func _edge(gap: float, x: float, side: float) -> float:
	var u: float = x / HALF_WIDTH
	return side * gap * maxf(1.0 - u * u, 0.0)


func _draw_daylight(gap: float) -> void:
	var rim: Color = Color(DAYLIGHT, 0.0)
	var core: Color = Color(DAYLIGHT, 0.85)
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	var colors: PackedColorArray = PackedColorArray([core])
	for i: int in EDGE_STEPS + 1:
		var angle: float = TAU * float(i) / float(EDGE_STEPS)
		points.append(Vector2(cos(angle) * HALF_WIDTH * 0.95, sin(angle) * gap * 1.05))
		colors.append(rim)
	draw_polygon(points, colors)


func _draw_tongue(gap: float) -> void:
	var sway: float = sin(_clock * 1.3) * 16.0
	var center: Vector2 = Vector2(sway, gap * 0.9)
	var points: PackedVector2Array = PackedVector2Array([center])
	var colors: PackedColorArray = PackedColorArray([Color(TONGUE, 0.95)])
	for i: int in EDGE_STEPS + 1:
		var angle: float = TAU * float(i) / float(EDGE_STEPS)
		points.append(
			center + Vector2(cos(angle) * HALF_WIDTH * 0.55, sin(angle) * (gap * 0.7 + 50.0))
		)
		colors.append(Color(TONGUE.darkened(0.4), 0.5))
	draw_polygon(points, colors)


## One jaw: flesh from the edge outward, fading into the dark, with teeth along the edge. `side`
## is -1 for the upper jaw, +1 for the lower one.
func _draw_jaw(gap: float, side: float) -> void:
	var span: float = HALF_WIDTH + 700.0
	var outer: float = side * (JAW_REACH + 260.0)
	var columns: int = EDGE_STEPS * 2
	var last_edge: Vector2 = Vector2.ZERO
	var last_outer: Vector2 = Vector2.ZERO
	for i: int in columns + 1:
		var x: float = lerpf(-span, span, float(i) / float(columns))
		var edge: Vector2 = Vector2(x, _edge(gap, x, side))
		var far: Vector2 = Vector2(x, outer)
		if i > 0:
			draw_polygon(
				PackedVector2Array([last_edge, edge, far, last_outer]),
				PackedColorArray(
					[
						Color(FLESH, 1.0),
						Color(FLESH, 1.0),
						Color(FLESH_DARK, 0.0),
						Color(FLESH_DARK, 0.0)
					]
				)
			)
		last_edge = edge
		last_outer = far
	for i: int in TEETH:
		var u: float = (float(i) + 0.5) / float(TEETH)
		var x: float = lerpf(-HALF_WIDTH * 0.75, HALF_WIDTH * 0.75, u)
		var size: float = 34.0 + 26.0 * fposmod(float(i) * 0.61803, 1.0)
		var base: float = _edge(gap, x, side)
		var width: float = 22.0
		draw_colored_polygon(
			PackedVector2Array(
				[Vector2(x - width, base), Vector2(x + width, base), Vector2(x, base - side * size)]
			),
			Color(TOOTH, 0.95)
		)
