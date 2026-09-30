class_name Track
extends Node2D
## A marble run: static colliders, a start area, a finish Area2D and a centerline
## Path2D used to measure race progress.

signal marble_reached_finish(marble: Node2D)
## A hazard event begins its telegraph. `kind` names the event.
signal hazard_started(kind: String)
## An anglerfish just swallowed `marble`.
signal fish_eaten(marble: Marble)
## A map part (anglerfish, portal) let off a particle burst. The finish replay plays it again.
signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)

## Distance in pixels either side of a point used to estimate the track direction.
const FORWARD_SAMPLE: float = 30.0

@export var spawn_columns: int = 5
@export var spawn_spacing: float = 34.0
## World area the race camera may look at. Grow it if a map extends beyond the default frame.
@export var view_bounds: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)
## How strongly the fish glow, 1 is normal. Dark maps raise it so the fish carry the light.
@export var fish_glow: float = 1.0
## Look of the map, a key of TrackStyle.PALETTES.
@export var style_id: String = TrackStyle.DEFAULT_STYLE

@onready var _finish: Area2D = $Finish
@onready var _centerline: Path2D = $Centerline
@onready var _spawn_origin: Marker2D = $SpawnOrigin


func _ready() -> void:
	_finish.body_entered.connect(_on_finish_body_entered)
	for hazard: Hazard in get_hazards():
		hazard.telegraph_started.connect(hazard_started.emit)
		if hazard is AnglerHazard:
			(hazard as AnglerHazard).fish_eaten.connect(fish_eaten.emit)
			(hazard as AnglerHazard).burst_played.connect(burst_played.emit)
	for node: Node in find_children("*", "PortalPair", true, false):
		(node as PortalPair).burst_played.connect(burst_played.emit)
	var style: TrackStyle = TrackStyle.new()
	add_child(style)
	style.dress(self, style_id)


## Lets the map's seeded gimmicks (drifting obstacles and the like) choose their layout for a
## race. Draws nothing from `rng` on maps that have none.
func seed_gimmicks(rng: RandomNumberGenerator) -> void:
	# Read before any draw and never advanced, so the duck cannot shift a race's layout.
	var duck_seed: int = hash(rng.state)
	for child: Node in get_children():
		if child.has_method("reseed"):
			child.call("reseed", rng.randi())
	_float_duck(duck_seed)


## Global positions of the race's treasures, one `{kind, position}` each. They lie on the map's
## `TreasureSpots` markers (ordered along the route the fish really take) when it has them, else on
## the centerline. A pure function of `treasure_seed`.
func treasure_spots(treasure_seed: int) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	var markers: Node = get_node_or_null("TreasureSpots")
	var curve: Curve2D = _centerline.curve
	var length: float = curve.get_baked_length()
	var marker_count: int = markers.get_child_count() if markers != null else 0
	if marker_count == 0 and length <= 0.0:
		return spots
	var last_index: int = -1
	for entry: Dictionary in Treasure.plan(treasure_seed):
		var progress: float = float(entry["progress"])
		var at: Vector2
		if marker_count > 0:
			# Each treasure gets its own marker while there are enough of them.
			last_index = mini(
				maxi(roundi(progress * float(marker_count - 1)), last_index + 1), marker_count - 1
			)
			var marker: Node2D = markers.get_child(last_index)
			at = marker.global_position
		else:
			at = _centerline.to_global(curve.sample_baked(progress * length))
		spots.append({"kind": entry["kind"], "position": at})
	return spots


## Easter egg: on rare races a rubber duck drifts through the background. Purely visual.
func _float_duck(duck_seed: int) -> void:
	var old: Node = get_node_or_null("RubberDuck")
	if old != null:
		remove_child(old)
		old.queue_free()
	if RubberDuck.appears(duck_seed):
		add_child(RubberDuck.create(duck_seed, view_bounds))


## Puts a duck on the map right now, whatever the odds. Used by tests and the debug tools.
func force_duck(duck_seed: int) -> RubberDuck:
	var old: Node = get_node_or_null("RubberDuck")
	if old != null:
		remove_child(old)
		old.queue_free()
	var duck: RubberDuck = RubberDuck.create(duck_seed, view_bounds)
	add_child(duck)
	return duck


## Plans this map's hazard events for a race. Each hazard draws its own seed from `rng`.
## A frequency of 0 or less means no hazards.
func arm_hazards(rng: RandomNumberGenerator, frequency: int) -> void:
	if frequency <= 0:
		return
	for hazard: Hazard in get_hazards():
		hazard.arm(rng.randi(), frequency)


## Ends any event in progress and puts the map back as it was.
func stop_hazards() -> void:
	for hazard: Hazard in get_hazards():
		hazard.disarm()


## Puts the map's geysers back to sleep and its gravity back to down.
func stop_gimmicks() -> void:
	for geyser: Geyser in get_geysers():
		geyser.disarm()
	for child: Node in get_children():
		if child is GravityFlipper:
			(child as GravityFlipper).disarm()


func get_geysers() -> Array[Geyser]:
	var result: Array[Geyser] = []
	for child: Node in get_children():
		if child is Geyser:
			result.append(child as Geyser)
	return result


func get_hazards() -> Array[Hazard]:
	var result: Array[Hazard] = []
	for child: Node in get_children():
		if child is Hazard:
			result.append(child as Hazard)
	return result


## Global position of the nth start slot (grid of spawn_columns per row, rows stack upward).
func get_spawn_position(index: int) -> Vector2:
	var col: int = index % spawn_columns
	var row: int = index / spawn_columns
	return _spawn_origin.to_global(Vector2(col * spawn_spacing, -row * spawn_spacing))


## Global position of the finish gate.
func get_finish_position() -> Vector2:
	return _finish.global_position


## Progress along the centerline in [0, 1] for a global position.
func get_progress(global_pos: Vector2) -> float:
	var curve: Curve2D = _centerline.curve
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return 0.0
	return curve.get_closest_offset(_centerline.to_local(global_pos)) / length


## Unit vector along the centerline (toward the finish) nearest to a global position.
func get_forward(global_pos: Vector2) -> Vector2:
	var curve: Curve2D = _centerline.curve
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return Vector2.DOWN
	var offset: float = curve.get_closest_offset(_centerline.to_local(global_pos))
	var ahead: Vector2 = curve.sample_baked(minf(offset + FORWARD_SAMPLE, length))
	var behind: Vector2 = curve.sample_baked(maxf(offset - FORWARD_SAMPLE, 0.0))
	var direction: Vector2 = _centerline.to_global(ahead) - _centerline.to_global(behind)
	if direction.length_squared() < 0.0001:
		return Vector2.DOWN
	return direction.normalized()


func _on_finish_body_entered(body: Node2D) -> void:
	marble_reached_finish.emit(body)
