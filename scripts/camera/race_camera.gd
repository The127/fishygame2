class_name RaceCamera
extends Camera2D
## Shows the whole track, or follows the leading group of fish during a race.
## Plain Camera2D, so parallax layers respond to it as usual.

const MIN_ZOOM: float = 1.0
const MAX_ZOOM: float = 2.0
## The overview may zoom out further, so tall maps fit the frame.
const OVERVIEW_MIN_ZOOM: float = 0.35
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
## Caps on how fast the view may move during a hand-over, so no single frame can lurch.
const MAX_PAN_SPEED: float = 900.0
const MAX_ZOOM_SPEED: float = 0.6

## When the followed group is sent far away in one go (a portal) the view glides after it:
## the easing starts gentle and ramps up over JUMP_TIME, and the pan speed is capped.
const JUMP_DISTANCE: float = 450.0
const JUMP_TIME: float = 0.8
const JUMP_MIN_SCALE: float = 0.6
const JUMP_PAN_SPEED: float = 2600.0
const JUMP_ZOOM_SPEED: float = 0.8

## Zoom used on the finish gate during a photo finish, before the play-area fit.
const PHOTO_FRAME: Vector2 = Vector2(480.0, 270.0)
## Easing rate during the hold. Applied in real time, not slowed with the game.
const PHOTO_RATE: float = 4.0

## Pixels a punch shakes the view by at most, and how fast it dies away (per second).
const PUNCH_DECAY: float = 5.0
const PUNCH_CUTOFF: float = 0.3

var _holding: bool = false
var _punch: float = 0.0
var _punch_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bounds: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)
var _following: bool = false
var _target_center: Vector2 = Vector2(960.0, 540.0)
var _target_zoom: float = MIN_ZOOM
var _followed_count: int = 0
var _handover_left: float = 0.0
var _jump_left: float = 0.0
var _focus_size: Vector2 = Vector2(1920.0, 1080.0)
## Where the camera looks (the middle of the play area), before the padding shift.
var _center: Vector2 = Vector2(960.0, 540.0)
## Part of the screen the track may use, as fractions of the viewport (streamer padding).
var _play_fraction: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)


func _ready() -> void:
	_snap()


func _process(delta: float) -> void:
	_update_punch(delta)
	if _holding:
		_process_hold(delta)
		return
	_handover_left = maxf(_handover_left - delta, 0.0)
	_jump_left = maxf(_jump_left - delta, 0.0)
	var ease_scale: float = minf(
		CameraFraming.handover_scale(_handover_left, HANDOVER_TIME, HANDOVER_MIN_SCALE),
		CameraFraming.handover_scale(_jump_left, JUMP_TIME, JUMP_MIN_SCALE)
	)
	var position_rate: float = (FOLLOW_POSITION_RATE if _following else OVERVIEW_RATE) * ease_scale
	var zoom_rate: float = (FOLLOW_ZOOM_RATE if _following else OVERVIEW_RATE) * ease_scale
	var t_position: float = CameraFraming.damping(position_rate, delta)
	var t_zoom: float = CameraFraming.damping(zoom_rate, delta)
	var zoom_step: float = (_target_zoom - zoom.x) * t_zoom
	if _handover_left > 0.0:
		zoom_step = clampf(zoom_step, -MAX_ZOOM_SPEED * delta, MAX_ZOOM_SPEED * delta)
	elif _jump_left > 0.0:
		zoom_step = clampf(zoom_step, -JUMP_ZOOM_SPEED * delta, JUMP_ZOOM_SPEED * delta)
	var new_zoom: float = zoom.x + zoom_step
	zoom = Vector2(new_zoom, new_zoom)
	var current: Vector2 = _center
	var step: Vector2 = (_target_center - current) * t_position
	if _handover_left > 0.0:
		step = step.limit_length(MAX_PAN_SPEED * delta)
	elif _jump_left > 0.0:
		step = step.limit_length(JUMP_PAN_SPEED * delta)
	_center = CameraFraming.clamp_center(current + step, new_zoom, _play_size(), _bounds)
	_place(new_zoom)


## A brief shake of the view, `strength` pixels at first. Only moves the camera offset, so
## framing and follow easing are untouched.
func punch(strength: float) -> void:
	_punch = maxf(_punch, strength)


## Current shake strength in pixels (0 when calm).
func punch_strength() -> float:
	return _punch


func _update_punch(delta: float) -> void:
	if _punch <= 0.0:
		return
	# The game may be slowed (photo finish); the shake dies away in real time.
	_punch *= exp(-PUNCH_DECAY * delta / maxf(Engine.time_scale, 0.05))
	if _punch < PUNCH_CUTOFF:
		_punch = 0.0
		offset = Vector2.ZERO
		return
	offset = Vector2(_punch_rng.randf_range(-1.0, 1.0), _punch_rng.randf_range(-1.0, 1.0)) * _punch


## Photo finish: hold a tight frame on `point`. Ignores follow() until release_hold().
func hold_on(point: Vector2) -> void:
	_holding = true
	_following = true
	_target_center = point
	_target_zoom = CameraFraming.fit_zoom(PHOTO_FRAME, _play_size(), _min_zoom(MIN_ZOOM), MAX_ZOOM)


## Ends the hold. The view eases back with the slowed hand-over easing.
func release_hold() -> void:
	if not _holding:
		return
	_holding = false
	_handover_left = HANDOVER_TIME


func is_holding() -> bool:
	return _holding


func _process_hold(delta: float) -> void:
	# The game runs slowed, so undo that to keep the zoom snappy in real time.
	var real_delta: float = delta / maxf(Engine.time_scale, 0.05)
	var t: float = CameraFraming.damping(PHOTO_RATE, real_delta)
	var new_zoom: float = zoom.x + (_target_zoom - zoom.x) * t
	var step: Vector2 = (_target_center - _center) * t
	_center = CameraFraming.clamp_center(_center + step, new_zoom, _play_size(), _bounds)
	_place(new_zoom)


## World rect the camera never looks outside of (the track's view bounds).
func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds


## Part of the screen the track may use, as fractions of the viewport. The rest is
## left empty for the streamer's own overlays (chat, webcam).
func set_play_fraction(fraction: Rect2) -> void:
	_play_fraction = fraction
	if _following:
		_target_zoom = CameraFraming.fit_zoom(
			_focus_size, _play_size(), _min_zoom(MIN_ZOOM), MAX_ZOOM
		)
	else:
		show_overview(true)


## Frame the whole track. With `snap` the view jumps there (new map), otherwise it glides.
func show_overview(snap: bool = false) -> void:
	_holding = false
	_following = false
	_followed_count = 0
	_jump_left = 0.0
	_target_zoom = CameraFraming.fit_zoom(
		_bounds.size, _play_size(), _min_zoom(OVERVIEW_MIN_ZOOM), MAX_ZOOM
	)
	_target_center = _bounds.get_center()
	if snap:
		_snap()


## Follow the leading group. `positions` and `progress` map marble id -> value.
## Falls back to the overview when there is nobody to follow.
func follow(positions: Dictionary, progress: Dictionary) -> void:
	if _holding:
		return
	if positions.size() < _followed_count:
		_handover_left = HANDOVER_TIME
	_followed_count = positions.size()
	var group: Array[Vector2] = CameraFraming.leader_group(positions, progress)
	if group.is_empty():
		show_overview()
		return
	var rect: Rect2 = CameraFraming.focus_rect(group, MARGIN, MIN_FRAME)
	if _following and CameraFraming.is_jump(_target_center, rect.get_center(), JUMP_DISTANCE):
		_jump_left = JUMP_TIME
	_following = true
	_focus_size = rect.size
	_target_zoom = CameraFraming.fit_zoom(rect.size, _play_size(), _min_zoom(MIN_ZOOM), MAX_ZOOM)
	_target_center = rect.get_center()


func _snap() -> void:
	_handover_left = 0.0
	_jump_left = 0.0
	_center = CameraFraming.clamp_center(_target_center, _target_zoom, _play_size(), _bounds)
	_place(_target_zoom)


## Applies zoom and position so `_center` shows in the middle of the play area.
func _place(new_zoom: float) -> void:
	zoom = Vector2(new_zoom, new_zoom)
	global_position = _center - CameraFraming.play_shift(_play_rect(), _viewport_size()) / new_zoom


func _play_rect() -> Rect2:
	var size: Vector2 = _viewport_size()
	return Rect2(_play_fraction.position * size, _play_fraction.size * size)


## `lowest` scaled down with the padding, so the whole track still fits the play area.
func _min_zoom(lowest: float) -> float:
	return lowest * minf(_play_fraction.size.x, _play_fraction.size.y)


func _play_size() -> Vector2:
	return _play_rect().size


func _viewport_size() -> Vector2:
	return get_viewport_rect().size
