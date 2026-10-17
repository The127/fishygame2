class_name RampGate
extends Node2D
## A trap door in a slope of a pinball table that is a shortcut: shut, the slope carries on to the
## flippers; open, the fish rolling over it drop through and skip them. It opens when its
## `Targets` (a [DropTargets] bank elsewhere on the table) are all down, and the first fish to fall
## through it shuts it again and stands the targets back up. Children: `Plate` (an
## AnimatableBody2D hinged at the gate's origin, running along local +x, with a `Visual` polygon),
## `Mouth` (an Area2D just under the plate, where a falling fish counts as having used the gate)
## and `Targets`. Only fish progress moves it, never a timer.

## A fish fell through the open gate.
signal used
signal opened

const SWING_SPEED: float = 5.0
const GLOW: Color = Color(0.4, 1.0, 0.6)

## Angle of the plate when shut, in degrees: the slope it is part of.
@export_range(-90.0, 90.0) var slope_degrees: float = 0.0
## How far the plate swings open from there, in degrees (the free end goes down).
@export_range(-110.0, 110.0) var open_degrees: float = 75.0
## Length of the plate along local +x, for the glow.
@export var length: float = 120.0

## How many times the gate was used in the race.
var times_used: int = 0

var _plate: AnimatableBody2D
var _mouth: Area2D
var _targets: DropTargets
var _open: bool = false
var _armed: bool = false
var _time: float = 0.0
var _flash: float = 0.0


func _ready() -> void:
	Replayable.join(self)
	_plate = get_node("Plate") as AnimatableBody2D
	_plate.rotation = deg_to_rad(slope_degrees)
	_mouth = get_node("Mouth") as Area2D
	_targets = get_node("Targets") as DropTargets
	_targets.cleared.connect(open)
	_mouth.body_entered.connect(_on_mouth_entered)


func _physics_process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 2.0, 0.0)
	_plate.rotation = move_toward(_plate.rotation, _wanted_angle(), SWING_SPEED * delta)
	queue_redraw()


## Called by [method Track.seed_gimmicks]: shuts the gate and stands the targets up for a race.
func reseed(_seed_value: int) -> void:
	_armed = true
	_open = false
	times_used = 0
	_plate.rotation = deg_to_rad(slope_degrees)
	_targets.arm()
	queue_redraw()


## Called by [method Track.stop_gimmicks].
func stop_gimmick() -> void:
	_armed = false
	_open = false
	_plate.rotation = deg_to_rad(slope_degrees)
	_targets.disarm()
	queue_redraw()


func _wanted_angle() -> float:
	return deg_to_rad(slope_degrees + (open_degrees if _open else 0.0))


func is_open() -> bool:
	return _open


func get_targets() -> DropTargets:
	return _targets


func open() -> void:
	if not _armed or _open:
		return
	_open = true
	_flash = 1.0
	opened.emit()


## Shuts the gate and stands the targets up.
func close() -> void:
	_open = false
	_targets.raise_all()


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array(
		[_plate.rotation, 1.0 if _open else 0.0, 1.0 if _armed else 0.0, _flash, _time]
	)


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_plate.rotation = Replayable.mix(from, to, weight, 0)
	_open = Replayable.step(from, to, weight, 1) > 0.5
	_armed = Replayable.step(from, to, weight, 2) > 0.5
	_flash = Replayable.mix(from, to, weight, 3)
	_time = Replayable.mix(from, to, weight, 4)
	queue_redraw()


func _on_mouth_entered(body: Node2D) -> void:
	# Switched off while the finish replay plays, when the marbles only show the recording.
	if not _armed or not _open or not is_physics_processing() or not body is Marble:
		return
	times_used += 1
	used.emit()
	close()


func _draw() -> void:
	var lit: float = 0.0
	if _open:
		lit = 0.5 + 0.5 * sin(_time * 8.0)
	lit = maxf(lit, _flash)
	draw_circle(Vector2.ZERO, 7.0, Color(GLOW, 0.3 + 0.6 * lit))
	var along: Vector2 = Vector2.from_angle(deg_to_rad(slope_degrees))
	var step: float = length / 5.0
	for i: int in 5:
		var at: Vector2 = along * step * (float(i) + 0.5) + along.orthogonal() * -4.0
		draw_circle(at, 3.5, Color(GLOW, 0.2 + 0.7 * lit))
