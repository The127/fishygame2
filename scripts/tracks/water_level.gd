class_name WaterLevel
extends Node2D
## The tide of Ebb Tide. The water sits above the whole map until a race starts, then drains
## from the top down: everything above [member level] is dry. The race strands fish that lie
## there too long (see [method Marble.update_dryness]). This node only moves and draws the
## waterline. Time advances in the physics step while draining, so a seed always drains the same.

## How fast the waterline crashes down to a level a [TideTrigger] sets, in pixels per second.
const SURGE_SPEED: float = 420.0
## Half-width of the drawn water, wide enough for any camera frame, and the x it is centered on.
const HALF_WIDTH: float = 1600.0
const CENTER_X: float = 960.0
const SURFACE_STEP: float = 24.0
const WAVE_AMPLITUDE: float = 5.0
## How far the dry overlay reaches above the waterline.
const DRY_HEIGHT: float = 2200.0
const GLOW_DEPTH: float = 110.0
const DRY_COLOR: Color = Color(0.42, 0.33, 0.22)
const SURFACE_COLOR: Color = Color(0.75, 0.97, 1.0)

## Waterline at the start of a race, above the spawn area so nobody starts dry.
@export var start_y: float = -260.0
## Waterline once it has drained away, below the finish so the last stragglers get stranded.
@export var end_y: float = 1080.0
## Seconds after the start before the water begins to drop.
@export var start_delay: float = 5.0
## Seconds the drain takes once it has begun, before the per-race variation.
@export var drain_seconds: float = 44.0
## How much a race's drain time may vary, as a fraction (0.1 is plus or minus ten percent).
@export var variation: float = 0.03
## Fish count that [member drain_seconds] is tuned for. Bigger fields jostle longer, so the drain
## takes [member seconds_per_extra_fish] seconds longer per fish above it. Smaller fields gain
## little, so each fish below it only shortens the drain by [member seconds_per_missing_fish].
@export var tuned_fish: int = 20
@export var seconds_per_extra_fish: float = 0.18
@export var seconds_per_missing_fish: float = 0.1

## World y of the waterline.
var level: float = -260.0
var draining: bool = false
var clock: float = 0.0

## Lowest waterline a trigger has asked for so far. The water is never above it afterwards.
var _goal: float = -260.0
var _drain_time: float = 44.0
var _fish_count: int = 20
var _surface: Line2D
var _glow: Line2D
var _time: float = 0.0
var _last_level: float = -260.0
## How hard the surface is glowing because the water is crashing down, 0 to 1.
var _flare: float = 0.0


func _ready() -> void:
	z_index = 4
	level = start_y
	_goal = start_y
	_last_level = start_y
	_drain_time = drain_seconds
	_build()
	_apply()
	Replayable.join(self)


## Tells the tide how many fish race, so it can drain at a pace that suits the field.
func set_field_size(count: int) -> void:
	_fish_count = count


## Drain time in seconds for a field of `count` fish, before the per-race variation.
func drain_seconds_for(count: int) -> float:
	var extra: float = float(count - tuned_fish)
	var per_fish: float = seconds_per_extra_fish if extra > 0.0 else seconds_per_missing_fish
	return maxf(drain_seconds + per_fish * extra, 10.0)


## Starts a race's drain. The seed varies the drain time a little, so races differ.
func reseed(seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	_drain_time = drain_seconds_for(_fish_count) * (1.0 + rng.randf_range(-variation, variation))
	clock = 0.0
	level = start_y
	_goal = start_y
	draining = true
	_apply()


## Refills the map and stops draining.
func stop() -> void:
	draining = false
	clock = 0.0
	level = start_y
	_goal = start_y
	_apply()


## Makes the water crash down to world y `target` (a [TideTrigger] was tripped) and hold there
## until the steady drain catches up. Only ever lowers the water: a target above the waterline, or
## a race that is not draining, changes nothing.
func drop_to(target: float) -> void:
	if draining:
		_goal = maxf(_goal, target)


## Stops draining and leaves the waterline where it is, for the end of a race.
func hold() -> void:
	draining = false


## Seconds the current race's drain takes once begun (after the per-race variation).
func current_drain_seconds() -> float:
	return _drain_time


func _physics_process(delta: float) -> void:
	if not draining:
		return
	clock += delta
	var t: float = clampf((clock - start_delay) / maxf(_drain_time, 0.001), 0.0, 1.0)
	var scheduled: float = lerpf(start_y, end_y, t)
	# The steady drain is the slowest the water falls. A tripped trigger sends it down faster, at a
	# speed that never lets it rise.
	var target: float = maxf(scheduled, _goal)
	if target > level:
		level = minf(target, level + SURGE_SPEED * delta)
	_apply()


func _process(delta: float) -> void:
	_time += delta
	_flare_up(delta)
	_wave()


## The finish replay records the waterline and the wave phase (see [Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([level, _time])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	level = Replayable.mix(from, to, weight, 0)
	_time = Replayable.mix(from, to, weight, 1)
	_apply()
	_wave()


## Makes the surface flare while the water is crashing down. It follows how fast the waterline
## moves, so the finish replay flares the same way without recording anything extra.
func _flare_up(delta: float) -> void:
	var speed: float = (level - _last_level) / maxf(delta, 0.001)
	_last_level = level
	var want: float = clampf((speed - 60.0) / 240.0, 0.0, 1.0)
	_flare = move_toward(_flare, want, delta * (8.0 if want > _flare else 2.5))
	_glow.width = 14.0 + 40.0 * _flare
	_glow.default_color = Color(SURFACE_COLOR, 0.2 + 0.5 * _flare)
	_surface.width = 3.0 + 3.0 * _flare


func _apply() -> void:
	position = Vector2(CENTER_X, level)


func _build() -> void:
	# Dry seabed above the waterline: a dull sand wash, stronger right at the surface.
	var dry: Polygon2D = Polygon2D.new()
	dry.polygon = PackedVector2Array(
		[
			Vector2(-HALF_WIDTH, -DRY_HEIGHT),
			Vector2(HALF_WIDTH, -DRY_HEIGHT),
			Vector2(HALF_WIDTH, 0.0),
			Vector2(-HALF_WIDTH, 0.0)
		]
	)
	var high: Color = Color(DRY_COLOR, 0.3)
	var low: Color = Color(DRY_COLOR, 0.5)
	dry.vertex_colors = PackedColorArray([high, high, low, low])
	add_child(dry)
	# Soft light just under the surface.
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var shallows: Polygon2D = Polygon2D.new()
	shallows.polygon = PackedVector2Array(
		[
			Vector2(-HALF_WIDTH, 0.0),
			Vector2(HALF_WIDTH, 0.0),
			Vector2(HALF_WIDTH, GLOW_DEPTH),
			Vector2(-HALF_WIDTH, GLOW_DEPTH)
		]
	)
	var bright: Color = Color(SURFACE_COLOR, 0.22)
	var clear: Color = Color(SURFACE_COLOR, 0.0)
	shallows.vertex_colors = PackedColorArray([bright, bright, clear, clear])
	shallows.material = add
	add_child(shallows)
	_glow = _make_line(14.0, Color(SURFACE_COLOR, 0.2))
	_glow.material = add
	_surface = _make_line(3.0, Color(SURFACE_COLOR, 0.9))
	_wave()


func _make_line(width: float, color: Color) -> Line2D:
	var line: Line2D = Line2D.new()
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	add_child(line)
	return line


## Ripples the waterline. Only the shape changes here, the node itself carries the height.
func _wave() -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var x: float = -HALF_WIDTH
	while x <= HALF_WIDTH:
		var y: float = (
			sin(x * 0.011 + _time * 1.7) * WAVE_AMPLITUDE
			+ sin(x * 0.023 - _time * 2.6) * WAVE_AMPLITUDE * 0.45
		)
		points.append(Vector2(x, y))
		x += SURFACE_STEP
	_surface.points = points
	_glow.points = points
