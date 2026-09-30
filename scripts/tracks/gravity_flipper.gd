class_name GravityFlipper
extends Node2D
## Flips the gravity of everything inside its `Zone` (an Area2D that covers the playfield) between
## down and up at seeded, irregular intervals. A warning pulses for [constant WARNING_SECONDS]
## before each flip, so viewers see it coming. The flip times are planned from the race seed in
## [method reseed], and time only advances in [method tick], so a seed replays the same flips.
## Children: `Zone` (Area2D that overrides gravity).

## Emitted when gravity flips. `up` is true when gravity now pulls toward the top of the screen.
signal flipped(up: bool)

## Seconds between two flips, drawn per flip.
const MIN_INTERVAL: float = 3.0
const MAX_INTERVAL: float = 4.5
## Seconds before the first flip at the earliest and latest.
const FIRST_MIN: float = 3.0
const FIRST_MAX: float = 4.0
## Seconds the warning pulses before a flip.
const WARNING_SECONDS: float = 1.0
## Race seconds after which no more flips are planned.
const HORIZON: float = 120.0
## Seconds the bright flash lasts after a flip.
const FLASH_SECONDS: float = 0.6
## How fast the drifting bubbles reverse, in flips per second.
const BLEND_SPEED: float = 5.0
const BUBBLES: int = 34
const BUBBLE_SPEED: float = 55.0
## Sideways lean of gravity toward +x, so a fish is always pulled a little toward the finish.
const LEAN: float = 0.2
const CHEVRON_COLOR: Color = Color(0.75, 0.8, 1.0)
const ALARM_COLOR: Color = Color(1.0, 0.85, 0.45)

## Area the warning and the bubbles cover, in this node's space.
@export var bounds: Rect2 = Rect2(30.0, 90.0, 1860.0, 900.0)

## True while gravity pulls toward the top of the screen.
var up: bool = false
## Seconds since the race started, advanced by [method tick].
var clock: float = 0.0

var _times: Array[float] = []
var _next: int = 0
var _armed: bool = false
var _flash: float = 0.0
## +1 while gravity pulls down and -1 while it pulls up, eased between the two.
var _blend: float = 1.0
var _scroll: float = 0.0

@onready var _zone: Area2D = $Zone


func _ready() -> void:
	_zone.gravity_space_override = Area2D.SPACE_OVERRIDE_REPLACE
	_zone.gravity_point = false
	_zone.gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	_apply()
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material


## Plans the flips of a race from `seed_value` and puts gravity back to down.
func reseed(seed_value: int) -> void:
	disarm()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var t: float = rng.randf_range(FIRST_MIN, FIRST_MAX)
	while t < HORIZON:
		_times.append(t)
		t += rng.randf_range(MIN_INTERVAL, MAX_INTERVAL)
	_armed = true
	queue_redraw()


## Stops flipping and puts gravity back to down.
func disarm() -> void:
	_armed = false
	_times.clear()
	_next = 0
	clock = 0.0
	_flash = 0.0
	_blend = 1.0
	up = false
	if is_node_ready():
		_apply()
	queue_redraw()


func is_armed() -> bool:
	return _armed


## Start times, in race seconds, of the planned flips.
func get_schedule() -> Array[float]:
	return _times.duplicate()


## 0 until the last [constant WARNING_SECONDS] before a flip, then rising to 1 at the flip.
func warning() -> float:
	if not _armed or _next >= _times.size():
		return 0.0
	return clampf(1.0 - (_times[_next] - clock) / WARNING_SECONDS, 0.0, 1.0)


## 1 at the moment of a flip, fading to 0.
func flash() -> float:
	return _flash / FLASH_SECONDS


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not _armed:
		return
	clock += delta
	while _next < _times.size() and clock >= _times[_next]:
		_next += 1
		flip()
	_flash = maxf(_flash - delta, 0.0)
	var target: float = -1.0 if up else 1.0
	_blend = move_toward(_blend, target, BLEND_SPEED * delta)
	_scroll += -_blend * BUBBLE_SPEED * delta
	queue_redraw()


## Flips gravity right now.
func flip() -> void:
	up = not up
	_flash = FLASH_SECONDS
	_apply()
	flipped.emit(up)


func _apply() -> void:
	_zone.gravity_direction = Vector2(LEAN, -1.0 if up else 1.0).normalized()
	# A fish resting against a baffle is asleep, and a new gravity does not wake it.
	for body: Node2D in _zone.get_overlapping_bodies():
		if body is RigidBody2D:
			(body as RigidBody2D).sleeping = false


func _draw() -> void:
	_draw_bubbles()
	if not _armed:
		return
	var warn: float = warning()
	if warn > 0.0:
		# The arrows point where gravity is about to go and throb faster as the flip nears.
		var pulse: float = 0.5 + 0.5 * sin(clock * (10.0 + 14.0 * warn))
		_draw_chevrons(-1.0 if not up else 1.0, Color(ALARM_COLOR, 0.12 + 0.4 * warn * pulse))
	else:
		_draw_chevrons(1.0 if not up else -1.0, Color(CHEVRON_COLOR, 0.06))
	if _flash > 0.0:
		draw_rect(bounds, Color(CHEVRON_COLOR, 0.22 * flash()))


## Rows of chevrons. `direction` is +1 for pointing down, -1 for pointing up.
func _draw_chevrons(direction: float, color: Color) -> void:
	var center: Vector2 = bounds.get_center()
	for column: int in 5:
		var x: float = lerpf(bounds.position.x + 200.0, bounds.end.x - 260.0, float(column) / 4.0)
		for row: int in 3:
			var y: float = center.y + (float(row) - 1.0) * 160.0
			var tip: Vector2 = Vector2(x, y + 28.0 * direction)
			draw_polyline(
				PackedVector2Array(
					[
						Vector2(x - 34.0, y - 28.0 * direction),
						tip,
						Vector2(x + 34.0, y - 28.0 * direction)
					]
				),
				color,
				5.0,
				true
			)


## Bubbles that float against gravity: up while it pulls down, down while it pulls up.
func _draw_bubbles() -> void:
	for i: int in BUBBLES:
		var lane: float = fposmod(float(i) * 0.618034, 1.0)
		var pace: float = 0.6 + 0.8 * fposmod(float(i) * 0.37, 1.0)
		var x: float = bounds.position.x + lane * bounds.size.x + sin(clock * 1.3 + float(i)) * 8.0
		var y: float = bounds.position.y + fposmod(_scroll * pace + float(i) * 97.0, bounds.size.y)
		var radius: float = 2.0 + 3.0 * fposmod(float(i) * 0.71, 1.0)
		draw_arc(Vector2(x, y), radius, 0.0, TAU, 10, Color(CHEVRON_COLOR, 0.35), 1.5, true)
