class_name WashDrum
extends AnimatableBody2D
## One steel ring of the Washing Machine map, with a door gap in the rim. The map nests several
## of them around one centre, each with its own size, swing and direction. A ring is built from
## its exported numbers in [method _ready]. Once a race has [method reseed]ed it, it tumbles like
## a real washer: it swings one way, slows and swings back, so the load never rides the wall for
## long. Fish slide back and forth with the swing and drop through the door when it sweeps past
## the bottom, into the next ring out, and finally onto the lanes.

## Sides of the drawn and collidable rim.
const SEGMENTS: int = 48
const STEEL_LIGHT: Color = Color(0.62, 0.7, 0.78)
const STEEL_DARK: Color = Color(0.42, 0.5, 0.58)
const DOOR_COLOR: Color = Color(1.0, 0.86, 0.3)
const ALARM_COLOR: Color = Color(1.0, 0.45, 0.35)
## Bubbles of suds that cling to the inside of the drum.
const SUDS: int = 26

## Outside radius of the rim, in pixels.
@export var outer_radius: float = 290.0
@export var thickness: float = 34.0
## How many rim segments the door leaves out (each spans 360 / [constant SEGMENTS] degrees).
@export var door_segments: int = 4
## Where the door sits on the drum when it has not turned, in degrees (-90 is the top).
@export var door_degrees: float = -90.0
## How far the drum swings from where it rests before it swings back, in degrees.
@export var tumble_degrees: float = 260.0
## 1 swings the drum clockwise, -1 counterclockwise.
@export_range(-1, 1, 2) var direction: int = 1
## Whole-turn multiplier for the spin cycle (negative turns the other way). It stays a whole
## number so the ring lands where it began.
@export var spin_multiplier: int = 1
## Seconds one swing out and back takes.
@export var tumble_seconds: float = 8.0
## The drum waits a moment at the start of a race, somewhere between these two times in seconds,
## so the fish settle and the door does not always reach the bottom at the same second.
@export var start_delay_min: float = 0.0
@export var start_delay_max: float = 2.0

## Whether the drum is turning (a race has started).
var spinning: bool = false
## Where the drum is turned to, in radians. The node's own `rotation` follows it when physics
## next steps, so read this one.
var angle: float = 0.0
## Extra turn in radians on top of the swing. The spin cycle winds it up by whole turns and
## drops it back to zero, which leaves the drum exactly where it was.
var spin: float = 0.0
## 0 to 1 warning glow around the door.
var alarm: float = 0.0:
	set(value):
		alarm = value
		queue_redraw()

var _suds: Array[Vector3] = []
var _delay: float = 0.0
## Where the swing is, in radians of a full out-and-back cycle.
var _phase: float = 0.0


func _ready() -> void:
	_build()
	Replayable.join(self)


## Starts the drum swinging for a race, after a wait drawn from `seed_value`. It does not jump to
## another angle, so the fish already inside are never hit by the rim.
func reseed(seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	stop()
	_delay = rng.randf_range(start_delay_min, start_delay_max)
	spinning = true


## Brings the drum back to rest with the door where it began.
func stop() -> void:
	spinning = false
	_delay = 0.0
	_phase = 0.0
	spin = 0.0
	angle = 0.0
	rotation = 0.0
	alarm = 0.0


## Where the door is, in degrees on screen (-90 is the top, 90 the bottom).
func door_world_degrees() -> float:
	return fposmod(door_degrees + rad_to_deg(angle) + 180.0, 360.0) - 180.0


func _physics_process(delta: float) -> void:
	if not spinning:
		return
	if _delay > 0.0:
		_delay -= delta
		return
	_phase = fposmod(_phase + TAU * delta / tumble_seconds, TAU)
	angle = float(direction) * deg_to_rad(tumble_degrees) * 0.5 * (1.0 - cos(_phase)) + spin
	rotation = angle


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([angle, alarm])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	angle = lerp_angle(from[0], to[0], weight)
	rotation = angle
	alarm = Replayable.mix(from, to, weight, 1)


func _build() -> void:
	var step: float = TAU / float(SEGMENTS)
	var start: float = deg_to_rad(door_degrees) + float(door_segments) * step * 0.5
	var inner: float = outer_radius - thickness
	for i: int in SEGMENTS - door_segments:
		var a0: float = start + float(i) * step
		var a1: float = a0 + step
		var quad: PackedVector2Array = PackedVector2Array(
			[
				Vector2.from_angle(a0) * inner,
				Vector2.from_angle(a0) * outer_radius,
				Vector2.from_angle(a1) * outer_radius,
				Vector2.from_angle(a1) * inner,
			]
		)
		_add_part("Rim%d" % i, quad, STEEL_LIGHT if i % 2 == 0 else STEEL_DARK)
	# The door frame glows at both edges of the gap.
	var end: float = start + float(SEGMENTS - door_segments) * step
	for edge: Array in [[start, 1.0], [end, -1.0]]:
		var edge_angle: float = edge[0]
		var side: float = edge[1]
		var lamp: Polygon2D = Polygon2D.new()
		lamp.name = "DoorFrame"
		lamp.color = DOOR_COLOR
		lamp.polygon = PackedVector2Array(
			[
				Vector2.from_angle(edge_angle) * (inner - 6.0),
				Vector2.from_angle(edge_angle) * (outer_radius + 6.0),
				Vector2.from_angle(edge_angle - side * 0.03) * (outer_radius + 6.0),
				Vector2.from_angle(edge_angle - side * 0.03) * (inner - 6.0),
			]
		)
		lamp.z_index = 1
		add_child(lamp)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for i: int in maxi(int(float(SUDS) * outer_radius / 290.0), 6):
		var bubble_angle: float = rng.randf() * TAU
		var depth: float = rng.randf_range(0.0, 0.75)
		_suds.append(Vector3(bubble_angle, inner - 4.0 - depth * 26.0, rng.randf_range(3.0, 9.0)))
	queue_redraw()


func _add_part(part_name: String, polygon: PackedVector2Array, color: Color) -> void:
	var shape: CollisionPolygon2D = CollisionPolygon2D.new()
	shape.name = part_name + "Shape"
	shape.polygon = polygon
	add_child(shape)
	var visual: Polygon2D = Polygon2D.new()
	visual.name = part_name
	visual.polygon = polygon
	visual.color = color
	add_child(visual)
	var ring: PackedVector2Array = polygon + PackedVector2Array([polygon[0]])
	var line: Line2D = Line2D.new()
	line.points = ring
	line.width = 1.5
	line.default_color = Color(0.9, 1.0, 1.0, 0.45)
	visual.add_child(line)


func _draw() -> void:
	# Suds on the inside of the drum, and a warning glow around the door.
	for bubble: Vector3 in _suds:
		var at: Vector2 = Vector2.from_angle(bubble.x) * bubble.y
		draw_circle(at, bubble.z, Color(0.92, 0.98, 1.0, 0.16))
		draw_arc(at, bubble.z, 0.0, TAU, 12, Color(1, 1, 1, 0.35), 1.0)
	if alarm > 0.01:
		var step: float = TAU / float(SEGMENTS)
		var a0: float = deg_to_rad(door_degrees) - float(door_segments) * step * 0.5
		var a1: float = deg_to_rad(door_degrees) + float(door_segments) * step * 0.5
		draw_arc(Vector2.ZERO, outer_radius + 10.0, a0, a1, 12, Color(ALARM_COLOR, alarm), 8.0)
