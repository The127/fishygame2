class_name RaceCamera
extends Camera2D
## Shows the whole track, or follows the leading group of fish during a race.
## Plain Camera2D, so parallax layers respond to it as usual.

const MIN_ZOOM: float = 1.0
const MAX_ZOOM: float = 2.0
## Room around the leading group, in world pixels.
const MARGIN: float = 220.0
## The frame is never smaller than this, so a lone leader does not zoom in absurdly far.
const MIN_FRAME: Vector2 = Vector2(640.0, 360.0)
const FOLLOW_POSITION_RATE: float = 3.5
const FOLLOW_ZOOM_RATE: float = 1.8
const OVERVIEW_RATE: float = 2.0
## When a fish finishes the focus target jumps to the rest of the pack. For this long
## the easing is slowed, then it ramps back up to the normal follow rates.
const HANDOVER_TIME: float = 2.5
## Fraction of the normal easing rate right after a finish.
const HANDOVER_MIN_SCALE: float = 0.25
## Caps on how fast the view may move, so no single frame can lurch.
const MAX_PAN_SPEED: float = 900.0
const MAX_ZOOM_SPEED: float = 0.6

var _bounds: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)
var _following: bool = false
var _target_center: Vector2 = Vector2(960.0, 540.0)
var _target_zoom: float = MIN_ZOOM
var _followed_count: int = 0
var _handover_left: float = 0.0


func _ready() -> void:
	_snap()


func _process(delta: float) -> void:
	_handover_left = maxf(_handover_left - delta, 0.0)
	var ease_scale: float = CameraFraming.handover_scale(
		_handover_left, HANDOVER_TIME, HANDOVER_MIN_SCALE
	)
	var position_rate: float = (FOLLOW_POSITION_RATE if _following else OVERVIEW_RATE) * ease_scale
	var zoom_rate: float = (FOLLOW_ZOOM_RATE if _following else OVERVIEW_RATE) * ease_scale
	var t_position: float = CameraFraming.damping(position_rate, delta)
	var t_zoom: float = CameraFraming.damping(zoom_rate, delta)
	var new_zoom: float = zoom.x + clampf(
		(_target_zoom - zoom.x) * t_zoom, -MAX_ZOOM_SPEED * delta, MAX_ZOOM_SPEED * delta
	)
	zoom = Vector2(new_zoom, new_zoom)
	var current: Vector2 = get_screen_center_position()
	var step: Vector2 = (_target_center - current) * t_position
	var center: Vector2 = current + step.limit_length(MAX_PAN_SPEED * delta)
	global_position = CameraFraming.clamp_center(center, new_zoom, _viewport_size(), _bounds)


## World rect the camera never looks outside of (the track's view bounds).
func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds


## Frame the whole track. With `snap` the view jumps there (new map), otherwise it glides.
func show_overview(snap: bool = false) -> void:
	_following = false
	_followed_count = 0
	_target_zoom = CameraFraming.fit_zoom(_bounds.size, _viewport_size(), MIN_ZOOM, MAX_ZOOM)
	_target_center = _bounds.get_center()
	if snap:
		_snap()


## Follow the leading group. `positions` and `progress` map marble id -> value.
## Falls back to the overview when there is nobody to follow.
func follow(positions: Dictionary, progress: Dictionary) -> void:
	if positions.size() < _followed_count:
		_handover_left = HANDOVER_TIME
	_followed_count = positions.size()
	var group: Array[Vector2] = CameraFraming.leader_group(positions, progress)
	if group.is_empty():
		show_overview()
		return
	var rect: Rect2 = CameraFraming.focus_rect(group, MARGIN, MIN_FRAME)
	_following = true
	_target_zoom = CameraFraming.fit_zoom(rect.size, _viewport_size(), MIN_ZOOM, MAX_ZOOM)
	_target_center = rect.get_center()


func _snap() -> void:
	_handover_left = 0.0
	zoom = Vector2(_target_zoom, _target_zoom)
	global_position = CameraFraming.clamp_center(
		_target_center, _target_zoom, _viewport_size(), _bounds
	)


func _viewport_size() -> Vector2:
	return get_viewport_rect().size
