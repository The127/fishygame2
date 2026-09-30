class_name HookFx
extends Node2D
## The streamer's fishing rod: a line and hook drop from above the screen to a spot, then
## reel back up (with the fish, if one was caught). Visual only; Race moves the fish.

const DROP_SECONDS: float = 0.25
const REEL_SECONDS: float = 0.5
const LINE_HEIGHT: float = 1400.0
const LINE_COLOR: Color = Color(0.9, 0.9, 0.8, 0.9)

var _age: float = 0.0


func _ready() -> void:
	z_index = 9


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= DROP_SECONDS + REEL_SECONDS:
		queue_free()


## How far below its resting spot the hook hangs, in pixels (negative is above).
func hook_offset() -> float:
	if _age < DROP_SECONDS:
		return -LINE_HEIGHT * (1.0 - _age / DROP_SECONDS)
	return -LINE_HEIGHT * ((_age - DROP_SECONDS) / REEL_SECONDS)


func _draw() -> void:
	var tip: Vector2 = Vector2(0.0, hook_offset())
	draw_line(tip + Vector2(0, -LINE_HEIGHT), tip, LINE_COLOR, 2.0)
	draw_arc(tip + Vector2(0, 10), 10.0, 0.0, PI, 12, LINE_COLOR, 3.0)
	draw_circle(tip, 3.0, LINE_COLOR)
