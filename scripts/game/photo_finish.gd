class_name PhotoFinish
extends Node
## Photo finish moment: a short slow-motion spell in real time. It only scales the visual
## clock (Engine.time_scale). Physics ticks stay fixed-step, so race results are unchanged.
## Always restores normal speed when it ends, is stopped or leaves the tree.

signal started
signal ended

## The winner and a chaser must be this close to the gate, in pixels.
const MAX_DISTANCE: float = 160.0
## And the chaser must reach it within this many seconds at its current speed.
const MAX_ETA: float = 0.4
const SLOW_SCALE: float = 0.2
## Real seconds at full slow-mo, then real seconds ramping back to normal speed.
const HOLD_SECONDS: float = 1.0
const RAMP_SECONDS: float = 0.5

var active: bool = false

var _started_msec: int = 0


## Seconds a marble at `distance` pixels from the gate needs to reach it at `speed`.
static func eta(distance: float, speed: float) -> float:
	if speed < 1.0:
		return INF
	return distance / speed


static func is_close(distance: float, speed: float) -> bool:
	return distance <= MAX_DISTANCE and eta(distance, speed) <= MAX_ETA


## Time scale `elapsed` real seconds after the start; 1.0 once the moment is over.
static func time_scale_at(elapsed: float) -> float:
	if elapsed < 0.0 or elapsed >= HOLD_SECONDS + RAMP_SECONDS:
		return 1.0
	if elapsed <= HOLD_SECONDS:
		return SLOW_SCALE
	var t: float = (elapsed - HOLD_SECONDS) / RAMP_SECONDS
	return lerpf(SLOW_SCALE, 1.0, t * t * (3.0 - 2.0 * t))


func start() -> void:
	if active:
		return
	active = true
	_started_msec = Time.get_ticks_msec()
	Engine.time_scale = SLOW_SCALE
	started.emit()


## Ends the moment right away and restores normal speed.
func stop() -> void:
	if not active:
		return
	active = false
	Engine.time_scale = 1.0
	ended.emit()


func _process(_delta: float) -> void:
	if not active:
		return
	var elapsed: float = float(Time.get_ticks_msec() - _started_msec) / 1000.0
	if elapsed >= HOLD_SECONDS + RAMP_SECONDS:
		stop()
	else:
		Engine.time_scale = time_scale_at(elapsed)


func _exit_tree() -> void:
	if active:
		stop()
