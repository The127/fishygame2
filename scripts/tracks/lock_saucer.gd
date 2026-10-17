class_name LockSaucer
extends Node2D
## A lock saucer, the pinball cup that holds balls for multiball. Fish drop into the `Cup` (an
## Area2D over its inside) and sit on the closed `Hatch` (an AnimatableBody2D hinged at the
## saucer's origin, running along local +x). When `lock_count` fish are in, or when fish are
## locked and none are still coming (nothing else is left above the saucer), the hatch swings
## open and the locked fish are fired out together. It shuts again once the cup is empty. Only fish
## decide when it opens: there is no timer. Fish still coming are the ones above the hatch
## and the ones in the plunger lane, right of `lane_x`.

## The hatch opened and `count` fish were let go.
signal released(count: int)

const SWING_SPEED: float = 6.0
## Speed the locked fish are fired out at, straight down, and how far apart they fan out, in
## pixels per second.
const FIRE_SPEED: float = 380.0
const FAN_SPEED: float = 150.0
## Share of its swing the hatch has made when the fish are fired out, so most clear it.
const FIRE_AT: float = 0.7
const GLOW: Color = Color(0.5, 1.0, 0.9)
const LIT: Color = Color(1.0, 0.85, 0.35)

## Fish that make a full lock.
@export var lock_count: int = 3
## World x from which a fish counts as still waiting in the plunger lane.
@export var lane_x: float = 1690.0
## How far the hatch swings open, in degrees (the free end goes down).
@export_range(-110.0, 110.0) var open_degrees: float = 85.0
## Length of the hatch along its local +x.
@export var length: float = 130.0

## Fish locked right now, shown on the lights.
var locked_count: int = 0
## How many times the saucer fired in the race.
var releases: int = 0

var _hatch: AnimatableBody2D
var _cup: Area2D
var _armed: bool = false
var _open: bool = false
## Whether the locked fish still have to be fired out, once the hatch has swung far enough.
var _to_fire: bool = false
var _flash: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	Replayable.join(self)
	_hatch = get_node("Hatch") as AnimatableBody2D
	_cup = get_node("Cup") as Area2D


func _physics_process(delta: float) -> void:
	_time += delta
	tick(delta)
	queue_redraw()


## Called by [method Track.seed_gimmicks]: shuts the hatch and arms the saucer for a race.
func reseed(_seed_value: int) -> void:
	_armed = true
	_open = false
	_to_fire = false
	locked_count = 0
	releases = 0
	_flash = 0.0
	_hatch.rotation = 0.0
	queue_redraw()


## Called by [method Track.stop_gimmicks].
func stop_gimmick() -> void:
	_armed = false
	_open = false
	_to_fire = false
	locked_count = 0
	_flash = 0.0
	_hatch.rotation = 0.0
	queue_redraw()


func is_armed() -> bool:
	return _armed


## Whether the hatch is meant to be open (it may still be swinging).
func is_open() -> bool:
	return _open


func tick(delta: float) -> void:
	if not _armed:
		return
	_flash = maxf(_flash - delta * 2.5, 0.0)
	var wanted: float = deg_to_rad(open_degrees) if _open else 0.0
	_hatch.rotation = move_toward(_hatch.rotation, wanted, SWING_SPEED * delta)
	var inside: Array[Marble] = _fish_inside()
	if _open:
		if _to_fire and absf(_hatch.rotation) >= absf(deg_to_rad(open_degrees)) * FIRE_AT:
			_to_fire = false
			_fire(inside)
		# Shut again once everything that was locked has dropped out.
		if inside.is_empty():
			_open = false
			_to_fire = false
			locked_count = 0
		return
	locked_count = inside.size()
	if inside.size() >= lock_count or (not inside.is_empty() and not fish_coming(inside)):
		_release(inside)


## Whether a fish outside `inside` is still on its way to the saucer: above the hatch, or waiting
## in the plunger lane. Finished fish, fish that left the race and fish below the saucer don't count.
func fish_coming(inside: Array[Marble]) -> bool:
	for node: Node in get_tree().get_nodes_in_group(Marble.GROUP):
		var marble: Marble = node as Marble
		if marble == null or inside.has(marble) or marble.eaten or marble.has_finished:
			continue
		if marble.is_out():
			continue
		if marble.global_position.y < global_position.y or marble.global_position.x > lane_x:
			return true
	return false


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array(
		[
			_hatch.rotation,
			1.0 if _open else 0.0,
			1.0 if _armed else 0.0,
			float(locked_count),
			_flash,
			_time,
		]
	)


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_hatch.rotation = Replayable.mix(from, to, weight, 0)
	_open = Replayable.step(from, to, weight, 1) > 0.5
	_armed = Replayable.step(from, to, weight, 2) > 0.5
	locked_count = int(Replayable.step(from, to, weight, 3))
	_flash = Replayable.mix(from, to, weight, 4)
	_time = Replayable.mix(from, to, weight, 5)
	queue_redraw()


func _fish_inside() -> Array[Marble]:
	var found: Array[Marble] = []
	for body: Node2D in _cup.get_overlapping_bodies():
		if body is Marble and not (body as Marble).eaten:
			found.append(body as Marble)
	return found


## Opens the hatch. The locked fish are fired out as it swings open (see [method _fire]).
func _release(inside: Array[Marble]) -> void:
	_open = true
	_to_fire = true
	_flash = 1.0
	releases += 1
	released.emit(inside.size())


## Fires the fish still in the cup out together, fanned apart.
func _fire(inside: Array[Marble]) -> void:
	var fan: float = float(inside.size() - 1) * 0.5
	for i: int in inside.size():
		var marble: Marble = inside[i]
		var wanted: Vector2 = Vector2((float(i) - fan) * FAN_SPEED, FIRE_SPEED)
		marble.sleeping = false
		marble.apply_central_impulse((wanted - marble.linear_velocity) * marble.mass)


func _draw() -> void:
	var lit_count: int = locked_count
	var open_glow: float = _flash
	for i: int in lock_count:
		var at: Vector2 = Vector2(length * (float(i) + 0.5) / float(lock_count), -34.0)
		var on: bool = i < lit_count
		draw_circle(at, 7.0, Color(LIT if on else GLOW, 0.8 if on else 0.18))
		if on:
			draw_arc(at, 11.0 + 4.0 * sin(_time * 6.0), 0.0, TAU, 20, Color(LIT, 0.5), 2.0, true)
	if open_glow > 0.0:
		draw_rect(Rect2(0.0, -30.0, length, 60.0), Color(GLOW, open_glow * 0.35))
