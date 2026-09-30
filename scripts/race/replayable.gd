class_name Replayable
extends RefCounted
## The hook that lets a moving node on a map take part in the finish replay.
##
## A node opts in by calling `Replayable.join(self)` in `_ready()` and implementing two methods:
##
## - `replay_state() -> PackedFloat32Array`: everything that decides how the node looks and
##   where it is right now (positions, angles, timers, phase), as floats. The length must be
##   the same on every call. Keep it small, it is stored about 30 times a second.
## - `replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void`:
##   puts the node into the state that lies `weight` (0 to 1) of the way from the recorded
##   state `from` to the next one, `to`. Read values with [method mix] (smooth values) or
##   [method step] (on/off flags, indices, anything that must not be blended).
##
## While a replay plays, [FinishReplay] switches the node's physics processing off, so nothing
## advances on its own, then calls `replay_apply` every frame and puts the node back to the
## state it had before the replay when the replay ends. A node that needs more can also define
## `replay_begin()` and `replay_end()`, called around the replay, and `replay_fish(fish)`, which
## gets the replayed fish (marble id to [Marble]) for a node that draws something to them.

const GROUP: StringName = &"replayable"
const STATE_METHOD: StringName = &"replay_state"
const APPLY_METHOD: StringName = &"replay_apply"


## Opts `node` in to the replay. Call it from `_ready()`.
static func join(node: Node) -> void:
	node.add_to_group(GROUP)


## Every replayable node at or under `root`, in tree order.
static func find_in(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	_collect(root, found)
	return found


## Smoothly blended value number `index` of the two states.
static func mix(
	from: PackedFloat32Array, to: PackedFloat32Array, weight: float, index: int
) -> float:
	return lerpf(from[index], to[index], weight)


## Value number `index` of the nearer state: for values that must not be blended.
static func step(
	from: PackedFloat32Array, to: PackedFloat32Array, weight: float, index: int
) -> float:
	return from[index] if weight < 0.5 else to[index]


## A 2D point stored in two consecutive floats starting at `index`, blended.
static func mix_vector(
	from: PackedFloat32Array, to: PackedFloat32Array, weight: float, index: int
) -> Vector2:
	return Vector2(mix(from, to, weight, index), mix(from, to, weight, index + 1))


## `count` consecutive values starting at `start`, blended, as a new array.
static func blend(
	from: PackedFloat32Array, to: PackedFloat32Array, weight: float, start: int, count: int
) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	for i: int in count:
		out[i] = lerpf(from[start + i], to[start + i], weight)
	return out


static func _collect(node: Node, into: Array[Node]) -> void:
	if node.is_in_group(GROUP) and node.has_method(STATE_METHOD) and node.has_method(APPLY_METHOD):
		into.append(node)
	for child: Node in node.get_children():
		_collect(child, into)
