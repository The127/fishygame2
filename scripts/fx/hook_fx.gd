class_name HookFx
extends Node2D
## The streamer's fishing rod: a line and hook drop from above the screen to a spot with a
## splash, the hook swings and glints, then it reels back up with bubbles. Visual only; Race
## moves the fish.

const DROP_SECONDS: float = 0.25
## The hook hangs at the target this long, swinging, before it reels up.
const HOLD_SECONDS: float = 0.2
const REEL_SECONDS: float = 0.5
const LINE_HEIGHT: float = 1400.0
const LINE_COLOR: Color = Color(0.9, 0.9, 0.8, 0.9)
const GLINT_COLOR: Color = Color(1.0, 1.0, 0.9)
const SWING_PIXELS: float = 9.0
const LINE_POINTS: int = 8

var _age: float = 0.0
var _landed: bool = false
var _reeling: bool = false


func _ready() -> void:
	z_index = 9


func _process(delta: float) -> void:
	_age += delta
	if not _landed and _age >= DROP_SECONDS:
		_landed = true
		_splash()
	if not _reeling and _age >= DROP_SECONDS + HOLD_SECONDS:
		_reeling = true
		RaceFx.burst(get_parent(), global_position, RaceFx.SPLASH_COLOR, 6, 50.0, Vector2(0, -30))
	queue_redraw()
	if _age >= DROP_SECONDS + HOLD_SECONDS + REEL_SECONDS:
		queue_free()


## How far below its resting spot the hook hangs, in pixels (negative is above).
func hook_offset() -> float:
	if _age < DROP_SECONDS:
		return -LINE_HEIGHT * (1.0 - _age / DROP_SECONDS)
	var reel: float = _age - DROP_SECONDS - HOLD_SECONDS
	if reel <= 0.0:
		return 0.0
	return -LINE_HEIGHT * reel / REEL_SECONDS


## Sideways swing of the hook in pixels: a damped wobble that starts when it lands.
func swing() -> float:
	var since: float = _age - DROP_SECONDS
	if since < 0.0:
		return 0.0
	return sin(since * 22.0) * SWING_PIXELS * exp(-since * 5.0)


## 0..1 flicker of the glint on the hook, only while it hangs at the target.
func glint() -> float:
	var since: float = _age - DROP_SECONDS
	if since < 0.0 or since > HOLD_SECONDS + 0.15:
		return 0.0
	return pow(maxf(sin(since * 40.0), 0.0), 4.0)


func _splash() -> void:
	var host: Node = get_parent()
	RaceFx.burst(host, global_position, RaceFx.SPLASH_COLOR, 10, 110.0, Vector2(0, 160))
	ShockRing.spawn(host, global_position, 46.0, 0.4, RaceFx.SPLASH_COLOR, 3.0)


func _draw() -> void:
	var tip: Vector2 = Vector2(swing(), hook_offset())
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in LINE_POINTS + 1:
		var along: float = float(i) / float(LINE_POINTS)
		# The line bows a little more the nearer it is to the hook.
		points.append(Vector2(tip.x * along * along, tip.y - LINE_HEIGHT * (1.0 - along)))
	draw_polyline(points, LINE_COLOR, 2.0)
	draw_arc(tip + Vector2(0, 10), 10.0, 0.0, PI, 12, LINE_COLOR, 3.0)
	draw_circle(tip, 3.0, LINE_COLOR)
	var shine: float = glint()
	if shine > 0.0:
		var spot: Vector2 = tip + Vector2(6.0, 16.0)
		var size: float = 9.0 * shine
		var color: Color = Color(GLINT_COLOR, shine)
		draw_line(spot - Vector2(size, 0), spot + Vector2(size, 0), color, 2.0)
		draw_line(spot - Vector2(0, size), spot + Vector2(0, size), color, 2.0)
