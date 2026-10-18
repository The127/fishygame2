class_name BeltReverseHazard
extends Hazard
## The hazard of Sushi Bar: one belt jams and runs backwards for a few seconds. The belt flashes
## as a warning, then it slows, turns round and carries its fish back toward the start of the belt
## until it picks up its proper way again. Which belt it is comes from the event's seed.
##
## The hazard only works out how fast each belt should run; it tells the map's [SushiBelts] with
## [signal belt_changed], during the race and under the finish replay alike.

## Belt `index` now runs at `factor` of its speed (negative is backwards), and `warning` (0 to 1)
## is how close it is to jamming.
signal belt_changed(index: int, factor: float, warning: float)

## Speed of the jammed belt, as a share of its usual speed the other way.
const REVERSE: float = 0.6
## Seconds the belt takes to turn round, at each end of the event.
const TURN: float = 0.4

## How many belts the map has.
@export var belt_count: int = 4

var _belt: int = 0


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	_belt = rng.randi_range(0, belt_count - 1)
	_emit()


func _process_telegraph(_delta: float) -> void:
	_emit()


func _process_active(_delta: float) -> void:
	_emit()


func _end_event() -> void:
	belt_changed.emit(_belt, 1.0, 0.0)


func _reset() -> void:
	belt_changed.emit(_belt, 1.0, 0.0)
	_belt = 0


## The jammed belt's speed now, as a share of its usual speed.
func factor() -> float:
	if phase != Phase.ACTIVE:
		return 1.0
	var turn: float = clampf(minf(phase_time, active_seconds - phase_time) / TURN, 0.0, 1.0)
	return lerpf(1.0, -REVERSE, turn)


## How close the belt is to jamming, 0 to 1 (only during the warning).
func warning() -> float:
	return phase_progress() if phase == Phase.TELEGRAPH else 0.0


## The belt that jams in the current event.
func belt() -> int:
	return _belt


func _emit() -> void:
	belt_changed.emit(_belt, factor(), warning())


func _replay_extra() -> PackedFloat32Array:
	return PackedFloat32Array([float(_belt)])


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	var belt_then: int = int(Replayable.step(from, to, weight, REPLAY_BASE))
	if belt_then != _belt:
		belt_changed.emit(_belt, 1.0, 0.0)
	_belt = belt_then
	_emit()
