class_name WheelView
extends Control
## The random-event wheel: slices turn under a fixed pointer at the top and slow down until
## the chosen slice sits under it. Purely visual, the result is decided by the caller.

const SIZE: float = 260.0
const TURNS: int = 4
const ARC_STEPS: int = 10
const IDLE_COLORS: Array[Color] = [Color(0.06, 0.16, 0.26), Color(0.09, 0.22, 0.34)]

var _slices: Array[String] = []
var _target: float = 0.0
var _duration: float = 1.0
var _elapsed: float = 0.0
var _rotation: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Turns the wheel so that slice `index` ends under the pointer after `seconds`.
func spin(slices: Array[String], index: int, seconds: float) -> void:
	_slices = slices.duplicate()
	_target = angle_for(index, _slices.size()) + TAU * float(TURNS)
	_duration = maxf(seconds, 0.01)
	_elapsed = 0.0
	_rotation = 0.0
	set_process(true)
	queue_redraw()


## Rotation that puts slice `index` (of `count`) under the pointer, modulo a full turn.
static func angle_for(index: int, count: int) -> float:
	return -float(index) * TAU / float(maxi(count, 1))


func is_settled() -> bool:
	return not _slices.is_empty() and _elapsed >= _duration


## Index of the slice under the pointer right now.
func current_index() -> int:
	if _slices.is_empty():
		return -1
	var span: float = TAU / float(_slices.size())
	return posmod(roundi(-_rotation / span), _slices.size())


func _process(delta: float) -> void:
	_elapsed = minf(_elapsed + delta, _duration)
	var t: float = _elapsed / _duration
	_rotation = _target * (1.0 - pow(1.0 - t, 3.0))
	queue_redraw()
	if _elapsed >= _duration:
		set_process(false)


func _draw() -> void:
	if _slices.is_empty():
		return
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 8.0
	var span: float = TAU / float(_slices.size())
	var font: Font = UiStyle.font(800)
	for i: int in _slices.size():
		var mid: float = float(i) * span + _rotation
		var color: Color = IDLE_COLORS[i % 2]
		if RaceEvent.is_event(_slices[i]):
			color = RaceEvent.color_of(_slices[i]).darkened(0.25)
		var points: PackedVector2Array = [center]
		for step: int in ARC_STEPS + 1:
			var a: float = mid - span * 0.5 + span * float(step) / float(ARC_STEPS) - PI * 0.5
			points.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(points, color)
		if RaceEvent.is_event(_slices[i]):
			var a: float = mid - PI * 0.5
			draw_set_transform(center + Vector2(cos(a), sin(a)) * radius * 0.6, mid, Vector2.ONE)
			var text: String = RaceEvent.short_of(_slices[i])
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, Vector2(-width * 0.5, 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_arc(center, radius, 0.0, TAU, 64, UiStyle.CYAN, 3.0, true)
	# Pointer at the top, pointing down into the wheel.
	var tip: Vector2 = center + Vector2(0.0, -radius + 18.0)
	draw_colored_polygon(
		PackedVector2Array([tip, tip + Vector2(-13.0, -30.0), tip + Vector2(13.0, -30.0)]),
		Color.WHITE
	)
