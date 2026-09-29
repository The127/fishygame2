class_name FlipGate
extends Node2D
## A tilting paddle under a chute. It sends a marble down one side, and once that marble has
## rolled off it flips to send the next one the other way, like the flipper in a marble machine.
## The layout is fixed and the physics deterministic, so the same seed always sends every
## fish down the same routes. Children: `Paddle` (an AnimatableBody2D hinged at the gate's
## origin, with a `Visual` polygon) and `Sensor` (an Area2D covering the space just beyond both ends of
## the paddle, so a marble waiting on the paddle never counts, only one that has rolled off).

signal flipped(new_state: int)

## How fast the paddle swings, in radians per second. Kept gentle so it never flings a marble.
const FLIP_SPEED: float = 3.6
const ARROW_COLOR: Color = Color(1.0, 0.55, 0.5)
const ALARM_COLOR: Color = Color(1.0, 0.9, 0.5)
const RIM_COLOR: Color = Color(1.0, 0.6, 0.6)
const ARROW_OFFSET: Vector2 = Vector2(0.0, -62.0)
const ARROW_SIZE: float = 15.0
## Seconds the arrow stays bright after a flip.
const FLASH_SECONDS: float = 0.5

## How far the paddle tilts either way, in degrees.
@export var tilt_degrees: float = 24.0
## Where the next marble is sent at the start of a race: +1 right, -1 left.
@export_enum("Left:-1", "Right:1") var initial_state: int = 1

## +1 sends the next marble right, -1 sends it left.
var state: int = 1

var _alarm: float = 0.0
var _flash: float = 0.0
var _time: float = 0.0
## Instance ids of the marbles now in the sensor.
var _over: Dictionary = {}

@onready var _paddle: AnimatableBody2D = $Paddle
@onready var _sensor: Area2D = $Sensor


func _ready() -> void:
	state = initial_state
	_paddle.rotation = target_angle()
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	var visual: Polygon2D = _paddle.get_node("Visual") as Polygon2D
	var ring: PackedVector2Array = visual.polygon + PackedVector2Array([visual.polygon[0]])
	var rim: Line2D = Line2D.new()
	rim.points = ring
	rim.width = 2.0
	rim.default_color = Color(RIM_COLOR, 0.8)
	rim.joint_mode = Line2D.LINE_JOINT_ROUND
	rim.antialiased = true
	visual.add_child(rim)


func _physics_process(delta: float) -> void:
	_paddle.rotation = move_toward(_paddle.rotation, target_angle(), FLIP_SPEED * delta)
	_watch_sensor()


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.7 + 0.3 * sin(_time * 3.0)
	var color: Color = ARROW_COLOR.lerp(ALARM_COLOR, _alarm)
	var alpha: float = pulse * (0.55 + 0.45 * _alarm)
	alpha = maxf(alpha, _flash / FLASH_SECONDS)
	var tip: Vector2 = ARROW_OFFSET + Vector2(float(state) * ARROW_SIZE, 0.0)
	var back: float = -float(state) * ARROW_SIZE * 0.6
	var points: PackedVector2Array = PackedVector2Array(
		[
			tip,
			ARROW_OFFSET + Vector2(back, -ARROW_SIZE * 0.7),
			ARROW_OFFSET + Vector2(back, ARROW_SIZE * 0.7),
		]
	)
	draw_colored_polygon(points, Color(color, alpha * 0.55))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(color, alpha), 2.0, true)


## The paddle angle for the current state, in radians (positive is clockwise, right end down).
func target_angle() -> float:
	return float(state) * deg_to_rad(tilt_degrees)


## Swings the paddle to the other side.
func flip() -> void:
	state = -state
	_flash = FLASH_SECONDS
	flipped.emit(state)


## Sends the next marble a given way (+1 right, -1 left), flipping only if it is not so already.
func set_state(new_state: int) -> void:
	if new_state != state:
		flip()


## 0 to 1: how loudly the arrow warns that the gate is about to be thrown around.
func set_alarm(amount: float) -> void:
	_alarm = clampf(amount, 0.0, 1.0)


## Puts the gate back as it starts a race.
func reset() -> void:
	state = initial_state
	_alarm = 0.0
	_flash = 0.0
	_over.clear()
	_paddle.rotation = target_angle()


## Flips once a marble that was in the sensor has left it. Marbles that vanish from the
## tree (a race being cleared) never count.
func _watch_sensor() -> void:
	var now: Dictionary = {}
	for body: Node2D in _sensor.get_overlapping_bodies():
		if body is Marble:
			now[body.get_instance_id()] = true
	var passed: bool = false
	for id: int in _over:
		if now.has(id):
			continue
		var marble: Node = instance_from_id(id) as Node
		if marble != null and marble.is_inside_tree():
			passed = true
	_over = now
	if passed:
		flip()
