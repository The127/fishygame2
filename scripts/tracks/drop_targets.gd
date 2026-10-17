class_name DropTargets
extends Node2D
## A bank of drop targets, like the row of standing targets on a real pinball table. Every child
## `StaticBody2D` with a rectangle `Collider` is one target. A fish that touches a standing target
## knocks it flat, and when the last one is down the bank is [signal cleared]. [method raise_all]
## stands them up again. Targets only fall to contact, never to a timer.

signal target_dropped(index: int, remaining: int)
## The last standing target fell.
signal cleared

## How far past a target's edge a fish already knocks it down.
const SENSOR_PAD: float = 6.0
## Seconds a target takes to fall or stand up.
const SWING_SECONDS: float = 0.18
const STANDING: Color = Color(1.0, 0.8, 0.3)
const FLAT: Color = Color(0.45, 0.3, 0.12)

var _targets: Array[StaticBody2D] = []
var _sizes: PackedVector2Array = PackedVector2Array()
## 0 for standing, 1 for flat, per target.
var _lowered: PackedFloat32Array = PackedFloat32Array()
var _down: PackedByteArray = PackedByteArray()
var _armed: bool = false


func _ready() -> void:
	Replayable.join(self)
	for child: Node in get_children():
		if not child is StaticBody2D:
			continue
		var target: StaticBody2D = child as StaticBody2D
		var collider: CollisionShape2D = target.get_node("Collider") as CollisionShape2D
		var size: Vector2 = (collider.shape as RectangleShape2D).size
		var index: int = _targets.size()
		_targets.append(target)
		_sizes.append(size)
		_lowered.append(0.0)
		_down.append(0)
		var sensor: Area2D = Area2D.new()
		var zone: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = size + Vector2.ONE * SENSOR_PAD * 2.0
		zone.shape = rect
		zone.position = collider.position
		sensor.add_child(zone)
		target.add_child(sensor)
		sensor.body_entered.connect(_on_body_entered.bind(index))


func _physics_process(delta: float) -> void:
	var step: float = delta / SWING_SECONDS
	for i: int in _lowered.size():
		_lowered[i] = move_toward(_lowered[i], float(_down[i]), step)
	queue_redraw()


## Stands every target up and lets the bank be hit.
func arm() -> void:
	_armed = true
	raise_all()


## Stands every target up and stops reacting to fish.
func disarm() -> void:
	_armed = false
	raise_all()
	_lowered.fill(0.0)
	queue_redraw()


func raise_all() -> void:
	for i: int in _targets.size():
		_down[i] = 0
		_set_solid(i, true)


func count() -> int:
	return _targets.size()


## Targets still standing.
func standing() -> int:
	var left: int = 0
	for flag: int in _down:
		if flag == 0:
			left += 1
	return left


func is_down(index: int) -> bool:
	return _down[index] != 0


## Knocks target `index` down. Returns false if it was down already or the bank is not armed.
func hit(index: int) -> bool:
	if not _armed or _down[index] != 0:
		return false
	_down[index] = 1
	_set_solid(index, false)
	var remaining: int = standing()
	target_dropped.emit(index, remaining)
	if remaining == 0:
		cleared.emit()
	return true


## Part of the finish replay ([Replayable]): how far down each target is.
func replay_state() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array([1.0 if _armed else 0.0])
	state.append_array(_lowered)
	return state


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_armed = Replayable.step(from, to, weight, 0) > 0.5
	for i: int in _lowered.size():
		_lowered[i] = Replayable.mix(from, to, weight, 1 + i)
	queue_redraw()


func _set_solid(index: int, solid: bool) -> void:
	var collider: CollisionShape2D = _targets[index].get_node("Collider") as CollisionShape2D
	collider.set_deferred("disabled", not solid)


func _on_body_entered(body: Node2D, index: int) -> void:
	# Switched off while the finish replay plays, when the marbles only show the recording.
	if not is_physics_processing() or not body is Marble:
		return
	hit(index)


func _draw() -> void:
	for i: int in _targets.size():
		var target: StaticBody2D = _targets[i]
		var collider: CollisionShape2D = target.get_node("Collider") as CollisionShape2D
		var size: Vector2 = _sizes[i]
		var flat: float = _lowered[i]
		# The target is hinged at its foot and lies back as it falls.
		var foot: Vector2 = target.position + collider.position + Vector2(0.0, size.y * 0.5)
		var tilt: float = flat * 1.35
		var color: Color = STANDING.lerp(FLAT, flat)
		var up: Vector2 = Vector2(sin(tilt), -cos(tilt)) * size.y
		var side: Vector2 = Vector2(cos(tilt), sin(tilt)) * size.x * 0.5
		draw_colored_polygon(
			PackedVector2Array([foot - side, foot + side, foot + up + side, foot + up - side]),
			Color(color, 0.9)
		)
		draw_polyline(
			PackedVector2Array(
				[foot - side, foot + side, foot + up + side, foot + up - side, foot - side]
			),
			Color(1.0, 0.95, 0.8, 0.9 - 0.5 * flat),
			2.0,
			true
		)
