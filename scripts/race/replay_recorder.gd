class_name ReplayRecorder
extends RefCounted
## Rolling buffer of fish poses for the finish replay. It keeps only the last few seconds
## before the winner crosses the gate, plus a short tail after it, then stops recording.
## Memory is fixed at creation: a ring of frames with one pose per marble id.

enum Kind { SPLASH, BOOST, CURSE }

## Seconds between recorded frames.
const SAMPLE_INTERVAL: float = 1.0 / 30.0
## Seconds kept before the winner's crossing, and recorded after it.
const LEAD_SECONDS: float = 2.5
const TAIL_SECONDS: float = 1.0

var marble_count: int = 0

var _capacity: int = 0
var _times: PackedFloat32Array = PackedFloat32Array()
var _positions: PackedVector2Array = PackedVector2Array()
var _velocities: PackedVector2Array = PackedVector2Array()
## Next ring slot to write, and how many slots hold a frame.
var _head: int = 0
var _size: int = 0
var _last_time: float = -INF
var _finish_time: float = -1.0
var _winner_id: int = -1
## Visual effects worth replaying: {time, id, kind, position}, oldest first.
var _events: Array[Dictionary] = []


func _init(p_marble_count: int = 0) -> void:
	marble_count = maxi(p_marble_count, 0)
	_capacity = ceili((LEAD_SECONDS + TAIL_SECONDS) / SAMPLE_INTERVAL) + 2
	_times.resize(_capacity)
	_positions.resize(_capacity * marble_count)
	_velocities.resize(_capacity * marble_count)


## True when a frame is due at race time `time` and recording is still open.
func should_sample(time: float) -> bool:
	return not is_done() and time - _last_time >= SAMPLE_INTERVAL - 0.0001


## Stores one frame. `positions` and `velocities` are indexed by marble id. The oldest frame
## is dropped when the ring is full. Does nothing once the tail after the finish is complete.
func sample(time: float, positions: PackedVector2Array, velocities: PackedVector2Array) -> void:
	if is_done() or positions.size() < marble_count or velocities.size() < marble_count:
		return
	if _size > 0 and absf(time - _last_time) < 0.0001:
		# Same instant as the last frame (a finish right after a regular sample): replace it.
		_head = posmod(_head - 1, _capacity)
		_size -= 1
	_times[_head] = time
	var base: int = _head * marble_count
	for i: int in marble_count:
		_positions[base + i] = positions[i]
		_velocities[base + i] = velocities[i]
	_head = (_head + 1) % _capacity
	_size = mini(_size + 1, _capacity)
	_last_time = time
	_prune_events()


## Notes the winner's crossing. Only the first call counts.
func mark_finish(time: float, winner_id: int) -> void:
	if _finish_time >= 0.0:
		return
	_finish_time = time
	_winner_id = winner_id


func add_event(time: float, id: int, kind: Kind, position: Vector2) -> void:
	if is_done():
		return
	_events.append({"time": time, "id": id, "kind": kind, "position": position})


## Recording is over: the winner crossed and the tail after it is stored.
func is_done() -> bool:
	return _finish_time >= 0.0 and _last_time >= _finish_time + TAIL_SECONDS


## Enough was recorded to play: a winner and at least two frames.
func has_clip() -> bool:
	return _finish_time >= 0.0 and _size >= 2


func frame_count() -> int:
	return _size


func frame_time(index: int) -> float:
	return _times[_slot(index)]


func position_at(index: int, id: int) -> Vector2:
	return _positions[_slot(index) * marble_count + id]


func velocity_at(index: int, id: int) -> Vector2:
	return _velocities[_slot(index) * marble_count + id]


func start_time() -> float:
	return frame_time(0) if _size > 0 else 0.0


func end_time() -> float:
	return frame_time(_size - 1) if _size > 0 else 0.0


func finish_time() -> float:
	return _finish_time


func winner_id() -> int:
	return _winner_id


func events() -> Array[Dictionary]:
	return _events


## Chronological frame index to ring slot.
func _slot(index: int) -> int:
	return posmod(_head - _size + index, _capacity)


func _prune_events() -> void:
	var oldest: float = frame_time(0)
	while not _events.is_empty() and float(_events[0]["time"]) < oldest:
		_events.pop_front()
