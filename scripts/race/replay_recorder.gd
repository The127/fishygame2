class_name ReplayRecorder
extends RefCounted
## Rolling buffer of fish poses for the finish replay. It keeps only the last few seconds
## before the winner crosses the gate, plus a short tail after it, then stops recording.
## Memory is fixed at creation: a ring of frames with one pose per marble id, plus the state of
## every [Replayable] node on the map once [method bind_nodes] has been called.

## BURST is a particle burst that belongs to no fish (anglerfish bite and spit, portal sparks):
## its `data` holds the `color`, `amount`, `speed` and `gravity` of the burst.
enum Kind { SPLASH, BOOST, CURSE, BURST }

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
## Per frame and marble: 1 when fully visible, 0 when gone (swallowed or dust).
var _alphas: PackedFloat32Array = PackedFloat32Array()
## The replayable nodes, each one's number of floats and where its floats start in a frame.
var _nodes: Array[Node] = []
var _node_sizes: PackedInt32Array = PackedInt32Array()
var _node_offsets: PackedInt32Array = PackedInt32Array()
var _node_stride: int = 0
var _node_values: PackedFloat32Array = PackedFloat32Array()
## Next ring slot to write, and how many slots hold a frame.
var _head: int = 0
var _size: int = 0
var _last_time: float = -INF
var _finish_time: float = -1.0
var _winner_id: int = -1
## Visual effects worth replaying: {time, id, kind, position, data}, oldest first.
var _events: Array[Dictionary] = []


func _init(p_marble_count: int = 0) -> void:
	marble_count = maxi(p_marble_count, 0)
	_capacity = ceili((LEAD_SECONDS + TAIL_SECONDS) / SAMPLE_INTERVAL) + 2
	_times.resize(_capacity)
	_positions.resize(_capacity * marble_count)
	_velocities.resize(_capacity * marble_count)
	_alphas.resize(_capacity * marble_count)
	_alphas.fill(1.0)


## Starts recording the state of these [Replayable] nodes with every frame. Call once, before
## the first sample. Each node's state length is read now and must not change afterwards.
func bind_nodes(nodes: Array[Node]) -> void:
	_nodes.clear()
	_node_sizes.clear()
	_node_offsets.clear()
	_node_stride = 0
	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		var state: PackedFloat32Array = node.call(Replayable.STATE_METHOD)
		_nodes.append(node)
		_node_sizes.append(state.size())
		_node_offsets.append(_node_stride)
		_node_stride += state.size()
	_node_values.resize(_capacity * _node_stride)


## True when a frame is due at race time `time` and recording is still open.
func should_sample(time: float) -> bool:
	return not is_done() and time - _last_time >= SAMPLE_INTERVAL - 0.0001


## Stores one frame. `positions` and `velocities` are indexed by marble id. The oldest frame
## is dropped when the ring is full. Does nothing once the tail after the finish is complete.
## `alphas` (optional) is how visible each marble is, 1 for fully. The bound nodes are read here.
func sample(
	time: float,
	positions: PackedVector2Array,
	velocities: PackedVector2Array,
	alphas: PackedFloat32Array = PackedFloat32Array()
) -> void:
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
		_alphas[base + i] = alphas[i] if i < alphas.size() else 1.0
	_capture_nodes(_head * _node_stride)
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


## Notes a visual effect. `id` is the fish it belongs to, or -1 for none; `data` is whatever
## the kind needs to draw it again.
func add_event(time: float, id: int, kind: Kind, position: Vector2, data: Dictionary = {}) -> void:
	if is_done():
		return
	_events.append({"time": time, "id": id, "kind": kind, "position": position, "data": data})


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


## How visible marble `id` is in frame `index`: 1 for fully, 0 for gone.
func alpha_at(index: int, id: int) -> float:
	return _alphas[_slot(index) * marble_count + id]


## The replayable nodes this recording holds states for.
func nodes() -> Array[Node]:
	return _nodes


## State number `node_index` of the bound nodes in frame `index`.
func node_state_at(index: int, node_index: int) -> PackedFloat32Array:
	var start: int = _slot(index) * _node_stride + _node_offsets[node_index]
	return _node_values.slice(start, start + _node_sizes[node_index])


## Bytes held by the ring, for tests and tuning.
func memory_bytes() -> int:
	return (
		_times.size() * 4
		+ (_positions.size() + _velocities.size()) * 8
		+ (_alphas.size() + _node_values.size()) * 4
	)


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


## Stores the state of every bound node at float offset `base` of the node ring.
func _capture_nodes(base: int) -> void:
	for n: int in _nodes.size():
		var node: Node = _nodes[n]
		var size: int = _node_sizes[n]
		var state: PackedFloat32Array = (
			node.call(Replayable.STATE_METHOD) if is_instance_valid(node) else PackedFloat32Array()
		)
		# A node that freed itself (or changed its length) keeps the slot, filled with zeros.
		for k: int in size:
			_node_values[base + _node_offsets[n] + k] = state[k] if k < state.size() else 0.0


## Chronological frame index to ring slot.
func _slot(index: int) -> int:
	return posmod(_head - _size + index, _capacity)


func _prune_events() -> void:
	var oldest: float = frame_time(0)
	while not _events.is_empty() and float(_events[0]["time"]) < oldest:
		_events.pop_front()
