class_name CardboardFish
extends Node2D
## A flat cardboard cutout of a fish, drawn in place of a [FishVisual] for a filler racer. It
## tumbles with the roll instead of facing where it goes, and now and then flips over to show
## its plain back.

## Half extents of the cutout, about the size of a real fish.
const LENGTH: float = 17.0
const HEIGHT: float = 10.0
## Outline points round the body; each point is nudged a little, like a scissor cut.
const CUT_STEPS: int = 26
const CUT_JITTER: float = 1.1
## Middle of the body; the snout points right.
const CENTER: Vector2 = Vector2(LENGTH * 0.15, 0.0)
const FRONT: Color = Color("d2a46c")
const BACK: Color = Color("a87a4a")
const EDGE: Color = Color("6b4a2b")
const RIBS: Color = Color(0.42, 0.27, 0.13, 0.28)
const MARKER: Color = Color(0.08, 0.06, 0.05)
const TAPE: Color = Color(0.93, 0.9, 0.78, 0.8)
## Rolling speed is turned into this much spin, so the cutout tumbles rather than rolls cleanly.
const SPIN: float = 0.6
const MAX_SPIN: float = 9.0
## Seconds between two flips of its own, and how fast a flip turns (radians per second).
const FLIP_MIN_SECONDS: float = 0.7
const FLIP_MAX_SECONDS: float = 2.2
const FLIP_SPEED: float = 10.0

## Seeds the cut and the flips, so each cutout keeps its own wobbly outline.
var cut_seed: int = 0:
	set(value):
		cut_seed = value
		_rng.seed = value
		_build_outline()
		queue_redraw()

## Size of the drawing, 1 on the track.
var unit_scale: float = 1.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _outline: PackedVector2Array = PackedVector2Array()
var _angle: float = 0.0
var _flip: float = 0.0
var _flip_target: float = 0.0
var _next_flip: float = 1.0
var _showing_back: bool = false


func _init() -> void:
	z_index = 5
	_build_outline()


func _process(delta: float) -> void:
	_next_flip -= delta
	if _next_flip <= 0.0:
		flop()
	_flip = move_toward(_flip, _flip_target, FLIP_SPEED * delta)
	scale = Vector2(cos(_flip), 1.0) * unit_scale
	var back: bool = scale.x < 0.0
	if back != _showing_back:
		_showing_back = back
		queue_redraw()


## Follows the marble at [param at], spinning with its sideways speed.
func tumble(at: Vector2, velocity: Vector2, delta: float) -> void:
	global_position = at
	_angle += clampf(velocity.x / Marble.RADIUS * SPIN, -MAX_SPIN, MAX_SPIN) * delta
	global_rotation = _angle


## Flips over once more and lurches to a new angle.
func flop() -> void:
	_flip_target += PI
	_angle += _rng.randf_range(-1.2, 1.2)
	_next_flip = _rng.randf_range(FLIP_MIN_SECONDS, FLIP_MAX_SECONDS)


## Whether the plain back faces the camera right now.
func is_showing_back() -> bool:
	return _showing_back


func _build_outline() -> void:
	# Nudged along the ray from the middle only: the points keep their order round it, so the
	# wobbly outline never crosses itself.
	_outline = PackedVector2Array()
	for p: Vector2 in _silhouette():
		var ray: Vector2 = (p - CENTER).normalized()
		_outline.append(p + ray * _rng.randf_range(-CUT_JITTER, CUT_JITTER))


## The fish shape, snout to the right: an oval body from the top of its back round the snout to
## its belly, then a forked tail.
func _silhouette() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in CUT_STEPS + 1:
		var t: float = lerpf(-PI * 0.83, PI * 0.83, float(i) / float(CUT_STEPS))
		points.append(CENTER + Vector2(cos(t) * LENGTH * 0.7, sin(t) * HEIGHT))
	points.append(Vector2(-LENGTH, HEIGHT * 1.05))
	points.append(Vector2(-LENGTH * 0.72, 0.0))
	points.append(Vector2(-LENGTH, -HEIGHT * 1.05))
	return points


func _draw() -> void:
	draw_colored_polygon(_outline, BACK if _showing_back else FRONT)
	# Corrugation ribs show through on both sides.
	for i: int in 7:
		var x: float = lerpf(-LENGTH * 0.6, LENGTH * 0.7, float(i) / 6.0)
		draw_line(Vector2(x, -HEIGHT * 0.7), Vector2(x, HEIGHT * 0.7), RIBS, 1.2)
	draw_polyline(_outline + PackedVector2Array([_outline[0]]), EDGE, 1.6)
	if _showing_back:
		# Two strips of tape holding the stick that is not there.
		draw_line(Vector2(-4.0, -HEIGHT * 0.8), Vector2(-1.0, HEIGHT * 0.8), TAPE, 3.0)
		draw_line(Vector2(5.0, -HEIGHT * 0.7), Vector2(3.0, HEIGHT * 0.7), TAPE, 3.0)
		return
	# Marker face: a wonky eye and a smile, and a few scribbled scales.
	var eye := Vector2(LENGTH * 0.5, -HEIGHT * 0.25)
	draw_circle(eye, 2.8, Color.WHITE)
	draw_arc(eye, 2.8, 0.0, TAU, 12, MARKER, 1.0)
	draw_circle(eye + Vector2(0.7, 0.4), 1.2, MARKER)
	draw_arc(Vector2(LENGTH * 0.62, HEIGHT * 0.2), 2.6, 0.2, PI - 0.4, 6, MARKER, 1.0)
	for i: int in 3:
		var x: float = LENGTH * (0.1 - 0.22 * float(i))
		draw_arc(Vector2(x, 0.0), 3.0, -PI * 0.5, PI * 0.5, 5, MARKER, 0.9)
