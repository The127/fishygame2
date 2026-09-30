class_name Hazard
extends Node2D
## A mid-race event on a map. Armed with a seed and a frequency it plans its events up front,
## then plays each one as a telegraph followed by the event itself. Time only advances in
## [method tick], so a seed always replays the same events. Subclasses override the hooks.

signal telegraph_started(kind: String)

enum Phase { IDLE, TELEGRAPH, ACTIVE }

## Race seconds after which no more events are planned.
const HORIZON: float = 90.0
## Most events one race plans, however often they strike. Bounds how long any hazard can hold
## a marble back.
const MAX_EVENTS: int = 6
## Seconds before the first event at the earliest.
const FIRST_EVENT_MIN: float = 3.0
## Mean pause between events at frequency 1, in seconds. Divided by the frequency.
const BASE_GAP: float = 20.0

## Name of the event, sent with [signal telegraph_started].
@export var kind: String = "hazard"
@export var telegraph_seconds: float = 1.5
@export var active_seconds: float = 3.0
## Mean pause between events at frequency 1, in seconds. A map can tighten it for a hazard that
## should strike often. Divided by the frequency.
@export var base_gap: float = BASE_GAP
## Most events one race plans. At most [constant MAX_EVENTS].
@export_range(1, 6) var max_events: int = MAX_EVENTS

var phase: Phase = Phase.IDLE
var phase_time: float = 0.0
## Seconds since the race started, advanced by [method tick].
var clock: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _schedule: Array[float] = []
var _next_event: int = 0
var _armed: bool = false
var _needs_redraw: bool = false


## Plans the events for a race. A frequency of 0 or less arms nothing.
func arm(seed_value: int, frequency: int) -> void:
	disarm()
	if frequency <= 0:
		return
	_rng.seed = seed_value
	var gap: float = base_gap / float(frequency)
	var t: float = _rng.randf_range(FIRST_EVENT_MIN, FIRST_EVENT_MIN + gap)
	while t < HORIZON and _schedule.size() < mini(max_events, MAX_EVENTS):
		_schedule.append(t)
		t += event_seconds() + _rng.randf_range(0.6, 1.4) * gap
	_armed = true


## Stops the event in progress and forgets the plan.
func disarm() -> void:
	if phase != Phase.IDLE:
		_end_event()
	phase = Phase.IDLE
	phase_time = 0.0
	clock = 0.0
	_schedule.clear()
	_next_event = 0
	_armed = false
	_reset()


func is_armed() -> bool:
	return _armed


## Start times, in race seconds, of the planned events.
func get_schedule() -> Array[float]:
	return _schedule.duplicate()


## Longest an event can last, telegraph included. Spaces the planned events apart.
func event_seconds() -> float:
	return telegraph_seconds + active_seconds


func tick(delta: float) -> void:
	if not _armed:
		return
	clock += delta
	match phase:
		Phase.IDLE:
			if _next_event < _schedule.size() and clock >= _schedule[_next_event]:
				_next_event += 1
				phase = Phase.TELEGRAPH
				phase_time = 0.0
				_begin_telegraph(_rng)
				telegraph_started.emit(kind)
		Phase.TELEGRAPH:
			phase_time += delta
			_process_telegraph(delta)
			if phase_time >= telegraph_seconds:
				phase = Phase.ACTIVE
				phase_time = 0.0
				_begin_active()
		Phase.ACTIVE:
			phase_time += delta
			_process_active(delta)
			if phase_time >= active_seconds:
				phase = Phase.IDLE
				phase_time = 0.0
				_end_event()
	if phase != Phase.IDLE or _needs_redraw:
		queue_redraw()
	_needs_redraw = phase != Phase.IDLE


func _physics_process(delta: float) -> void:
	tick(delta)


## Called when an event's telegraph begins. Choose everything random about the event
## from `rng` here.
func _begin_telegraph(_rng_for_event: RandomNumberGenerator) -> void:
	pass


func _process_telegraph(_delta: float) -> void:
	pass


func _begin_active() -> void:
	pass


func _process_active(_delta: float) -> void:
	pass


## Called when an event ends or is cut short.
func _end_event() -> void:
	pass


## Called when arming and disarming: put the map back as it was.
func _reset() -> void:
	pass


## Progress through the current phase in [0, 1].
func phase_progress() -> float:
	var length: float = telegraph_seconds if phase == Phase.TELEGRAPH else active_seconds
	return clampf(phase_time / maxf(length, 0.001), 0.0, 1.0)
