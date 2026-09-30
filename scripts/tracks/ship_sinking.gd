class_name ShipSinking
extends Node2D
## Shipwreck's gimmick: the ship goes down while the fish race. Trigger zones (the Area2D
## children of `Zones`, in route order) start the sinking in stages: the first fish into a zone
## brings the next stage, so things happen where the fish are. A stage tilts the ship a little
## further (gravity leans over, the hull behind the decks leans with it) and floods the lower
## decks a little higher. Water under the waterline slows fish down, which costs the fish that
## get there first. A stage, once reached, is never undone: the lean and the water only grow.
## Children: `Zones` (Area2Ds), `Gravity` (Area2D covering the playfield) and `Flood` (Area2D that
## damps whatever is in the water, its shape hangs below the node's origin).
## Which way the ship leans and nothing else about a race comes from the seed in [method reseed];
## time only advances in [method tick].

## A sinking stage was reached. `stage` counts from 1.
signal stage_reached(stage: int)
## The sinking let off a particle burst. The finish replay plays it again.
signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)

## Degrees gravity leans over once each stage (index 0 is the untouched ship) has been reached.
const LEAN_DEGREES: Array[float] = [0.0, 0.6, 1.2, 1.8, 2.4]
## World y of the waterline at each stage, at the middle of the map.
const FLOOD_LEVELS: Array[float] = [1160.0, 1010.0, 880.0, 740.0, 600.0]
## Linear damping the water adds once it stands at the highest level.
const MAX_DAMP: float = 0.35
## How fast the lean settles in degrees per second and how fast the water rises in pixels per second.
const LEAN_SPEED: float = 1.0
const FLOOD_SPEED: float = 90.0
## How much the hull behind the decks exaggerates the lean, so the tilt reads on screen.
const HULL_TILT: float = 2.5
const HULL_PIVOT: Vector2 = Vector2(960.0, 540.0)
## Seconds between two wake-ups of resting fish while the ship is still settling.
const WAKE_INTERVAL: float = 0.3
const HALF_WIDTH: float = 1800.0
const FLOOD_DEPTH: float = 1600.0
const SURFACE_STEP: float = 24.0
const WAVE_AMPLITUDE: float = 4.0
const WATER_COLOR: Color = Color(0.1, 0.34, 0.4)
const SURFACE_COLOR: Color = Color(0.7, 0.95, 0.9)
const BUBBLE_COLOR: Color = Color(0.75, 0.95, 0.9)
const TIMBER_COLOR: Color = Color(0.07, 0.05, 0.035)
const PORTHOLE_COLOR: Color = Color(1.0, 0.72, 0.32)

## Stages reached so far, 0 for a ship that still floats.
var stage: int = 0
## Degrees gravity leans over right now, signed (positive leans toward +x).
var lean: float = 0.0
## World y of the waterline at the middle of the map.
var flood_level: float = FLOOD_LEVELS[0]

var _armed: bool = false
var _replaying: bool = false
## +1 or -1: which way this race's ship leans.
var _side: float = 1.0
var _time: float = 0.0
var _wake_in: float = 0.0
var _surface: Line2D
var _glow: Line2D
var _hull: Node2D

@onready var _zones: Node = $Zones
@onready var _gravity: Area2D = $Gravity
@onready var _flood: Area2D = $Flood


func _ready() -> void:
	assert(_zones.get_child_count() == LEAN_DEGREES.size() - 1, "one zone per sinking stage")
	_gravity.gravity_space_override = Area2D.SPACE_OVERRIDE_REPLACE
	_gravity.gravity_point = false
	_gravity.gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	_flood.linear_damp_space_override = Area2D.SPACE_OVERRIDE_COMBINE
	for zone: Node in _zones.get_children():
		(zone as Area2D).body_entered.connect(_on_zone_entered.bind(zone.get_index() + 1))
	_build()
	_apply()
	Replayable.join(self)


## Starts a race: the ship floats and the seed picks which way it will lean.
func reseed(seed_value: int) -> void:
	stop_gimmick()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	_side = 1.0 if rng.randf() < 0.5 else -1.0
	_armed = true


## Puts the ship back afloat and stops the sinking.
func stop_gimmick() -> void:
	_armed = false
	stage = 0
	lean = 0.0
	flood_level = FLOOD_LEVELS[0]
	_side = 1.0
	_wake_in = 0.0
	if is_node_ready():
		_apply()


func is_armed() -> bool:
	return _armed


## How many stages there are.
func stage_count() -> int:
	return LEAN_DEGREES.size() - 1


## Brings the ship to `target` (at least) and no further back: a stage is never undone.
func reach_stage(target: int) -> void:
	target = clampi(target, 0, stage_count())
	if target <= stage:
		return
	stage = target
	_wake_in = 0.0
	var zone: Area2D = _zones.get_child(target - 1) as Area2D
	burst_played.emit(zone.global_position, BUBBLE_COLOR, 16, 120.0, Vector2(0, -50))
	RaceFx.burst(self, zone.global_position, BUBBLE_COLOR, 16, 120.0)
	stage_reached.emit(stage)


## Degrees of lean the ship settles on at the current stage, signed.
func target_lean() -> float:
	# A plain 0 rather than -0, which a replay blend would turn into +0.
	return LEAN_DEGREES[stage] * _side if stage > 0 else 0.0


## Waterline the water settles on at the current stage.
func target_flood_level() -> float:
	return FLOOD_LEVELS[stage]


## How far the water has risen, from 0 (floating) to 1 (the top stage).
func flood_fraction() -> float:
	return clampf(inverse_lerp(FLOOD_LEVELS[0], FLOOD_LEVELS[stage_count()], flood_level), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not _armed:
		return
	lean = move_toward(lean, target_lean(), LEAN_SPEED * delta)
	flood_level = move_toward(flood_level, target_flood_level(), FLOOD_SPEED * delta)
	_apply()
	if lean != target_lean() or flood_level != target_flood_level():
		_wake_in -= delta
		if _wake_in <= 0.0:
			_wake_in = WAKE_INTERVAL
			_wake_bodies()


func _process(delta: float) -> void:
	_time += delta
	_wave()


func _on_zone_entered(body: Node2D, target: int) -> void:
	if _armed and not _replaying and body is Marble:
		reach_stage(target)


## Part of the finish replay ([Replayable]): the lean, the waterline, the stage and the wave phase.
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([lean, flood_level, float(stage), _time])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	lean = Replayable.mix(from, to, weight, 0)
	flood_level = Replayable.mix(from, to, weight, 1)
	stage = int(Replayable.step(from, to, weight, 2))
	_time = Replayable.mix(from, to, weight, 3)
	_apply()
	_wave()


## The replayed fish cross the zones again, which must not sink the ship any further.
func replay_begin() -> void:
	_replaying = true


## After the replay the physics areas show the state the race really ended in.
func replay_end() -> void:
	_replaying = false
	_apply()


## Puts the lean and the water into the physics areas and the drawing.
func _apply() -> void:
	var angle: float = deg_to_rad(lean)
	_gravity.gravity_direction = Vector2(sin(angle), cos(angle))
	# The water stands level in the frame where gravity points along its depth.
	_flood.position = Vector2(HULL_PIVOT.x, flood_level)
	_flood.rotation = -angle
	_flood.linear_damp = MAX_DAMP * flood_fraction()
	_hull.rotation = angle * HULL_TILT


## A fish resting on a deck is asleep, and a new lean or water does not wake it.
func _wake_bodies() -> void:
	for body: Node2D in _gravity.get_overlapping_bodies():
		if body is RigidBody2D:
			(body as RigidBody2D).sleeping = false


func _build() -> void:
	# The hull behind the decks: ribs and lit portholes, turned about the middle of the map.
	_hull = Node2D.new()
	_hull.position = HULL_PIVOT
	_hull.z_index = -8
	add_child(_hull)
	for i: int in 9:
		var x: float = -1120.0 + float(i) * 280.0
		var rib: Polygon2D = Polygon2D.new()
		rib.color = TIMBER_COLOR
		rib.polygon = PackedVector2Array(
			[
				Vector2(x - 26.0, -1100.0),
				Vector2(x + 26.0, -1100.0),
				Vector2(x + 34.0, 1100.0),
				Vector2(x - 34.0, 1100.0)
			]
		)
		_hull.add_child(rib)
	for i: int in 4:
		var porthole: Polygon2D = Polygon2D.new()
		var center: Vector2 = Vector2(-690.0 + float(i) * 460.0, -360.0 + float(i % 2) * 70.0)
		var ring: PackedVector2Array = PackedVector2Array()
		for step: int in 20:
			var around: float = float(step) / 20.0 * TAU
			ring.append(center + Vector2(cos(around), sin(around)) * 46.0)
		porthole.polygon = ring
		porthole.color = Color(PORTHOLE_COLOR, 0.1)
		_hull.add_child(porthole)
	# The floodwater hangs below the Flood area's origin, over the fish.
	var water: Polygon2D = Polygon2D.new()
	water.z_index = 3
	water.polygon = PackedVector2Array(
		[
			Vector2(-HALF_WIDTH, 0.0),
			Vector2(HALF_WIDTH, 0.0),
			Vector2(HALF_WIDTH, FLOOD_DEPTH),
			Vector2(-HALF_WIDTH, FLOOD_DEPTH)
		]
	)
	var shallow: Color = Color(WATER_COLOR, 0.12)
	var deep: Color = Color(WATER_COLOR, 0.42)
	water.vertex_colors = PackedColorArray([shallow, shallow, deep, deep])
	_flood.add_child(water)
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = _make_line(14.0, Color(SURFACE_COLOR, 0.18))
	_glow.material = add
	_surface = _make_line(3.0, Color(SURFACE_COLOR, 0.8))
	_wave()


func _make_line(width: float, color: Color) -> Line2D:
	var line: Line2D = Line2D.new()
	line.z_index = 3
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	_flood.add_child(line)
	return line


## Ripples the waterline. Only the shape changes here, the Flood node carries the height.
func _wave() -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var x: float = -HALF_WIDTH
	while x <= HALF_WIDTH:
		var y: float = (
			sin(x * 0.012 + _time * 1.5) * WAVE_AMPLITUDE
			+ sin(x * 0.027 - _time * 2.3) * WAVE_AMPLITUDE * 0.5
		)
		points.append(Vector2(x, y))
		x += SURFACE_STEP
	_surface.points = points
	_glow.points = points
