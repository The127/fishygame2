class_name Track
extends Node2D
## A marble run: static colliders, a start area, a finish Area2D and a centerline
## Path2D used to measure race progress.
##
## A map can have several starts. `SpawnOrigin` is the first; every Marker2D under an optional
## `Starts` node adds another. Each start needs a Path2D under `Feeders` (same order) running
## from that start to the point where the routes merge, and `Centerline` then runs from the
## merge point to the finish. `merge_progress` is the share of the progress scale the feeders
## take up, so a fish scores the same progress at the same stage of any route.

signal marble_reached_finish(marble: Node2D)
## A hazard event begins its telegraph. `kind` names the event.
signal hazard_started(kind: String)
## A hazard event's telegraph is over and the event itself begins. `kind` names the event.
signal hazard_active(kind: String)
## An anglerfish just swallowed `marble`.
signal fish_eaten(marble: Marble)
## Stomach acid just dissolved `marble`: it is out of the race.
signal fish_dissolved(marble: Marble)
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
## Look of the map, a key of TrackPalettes.PALETTES.
@export var style_id: String = TrackPalettes.DEFAULT_STYLE
## Share of the progress scale (0..1) spent on the feeder routes of a multi-start map.
@export_range(0.0, 0.9) var merge_progress: float = 0.25

var _starts: Array[Marker2D] = []
var _feeders: Array[Path2D] = []
## Start index and slot within that start, by marble index, for the current race.
var _start_of: Array[int] = []
var _slot_of: Array[int] = []

var _tide: WaterLevel

@onready var _finish: Area2D = $Finish
@onready var _centerline: Path2D = $Centerline
@onready var _spawn_origin: Marker2D = $SpawnOrigin


func _ready() -> void:
	_starts.append(_spawn_origin)
	var extra_starts: Node = get_node_or_null("Starts")
	if extra_starts != null:
		for child: Node in extra_starts.get_children():
			if child is Marker2D:
				_starts.append(child as Marker2D)
	var feeders: Node = get_node_or_null("Feeders")
	if feeders != null:
		for child: Node in feeders.get_children():
			if child is Path2D:
				_feeders.append(child as Path2D)
	assert(
		_feeders.is_empty() or _feeders.size() == _starts.size(), "every start needs a feeder route"
	)
	_finish.body_entered.connect(_on_finish_body_entered)
	for child: Node in get_children():
		if child is WaterLevel:
			_tide = child as WaterLevel
	for hazard: Hazard in get_hazards():
		hazard.telegraph_started.connect(hazard_started.emit)
		hazard.active_started.connect(hazard_active.emit)
		if hazard is AnglerHazard:
			(hazard as AnglerHazard).fish_eaten.connect(fish_eaten.emit)
			(hazard as AnglerHazard).burst_played.connect(burst_played.emit)
		if hazard is PlankHazard:
			(hazard as PlankHazard).burst_played.connect(burst_played.emit)
		if hazard is RuinHazard:
			(hazard as RuinHazard).burst_played.connect(burst_played.emit)
		if hazard is SpinCycleHazard:
			(hazard as SpinCycleHazard).burst_played.connect(burst_played.emit)
	for node: Node in find_children("*", "PortalPair", true, false):
		(node as PortalPair).burst_played.connect(burst_played.emit)
	for node: Node in find_children("*", "AcidPit", true, false):
		(node as AcidPit).burst_played.connect(burst_played.emit)
		(node as AcidPit).fish_dissolved.connect(fish_dissolved.emit)
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


## Puts the map's geysers back to sleep, its gravity back to down, its tide full again and any
## other seeded gimmick (a turning drum) back to rest.
func stop_gimmicks() -> void:
	for geyser: Geyser in get_geysers():
		geyser.disarm()
	for child: Node in get_children():
		if child is GravityFlipper:
			(child as GravityFlipper).disarm()
		elif child.has_method("stop_gimmick"):
			child.call("stop_gimmick")
	if _tide != null:
		_tide.stop()


## Tells the map how many fish race, for gimmicks that pace themselves to the field. Call before
## [method seed_gimmicks].
func set_field_size(count: int) -> void:
	if _tide != null:
		_tide.set_field_size(count)


## Stops the tide where it is. The next [method stop_gimmicks] refills it.
func hold_tide() -> void:
	if _tide != null:
		_tide.hold()


## Whether the map drains during a race (fish above the waterline get stranded).
func has_tide() -> bool:
	return _tide != null


## World y of the waterline right now. Only meaningful when [method has_tide] is true.
func get_water_level() -> float:
	return _tide.level if _tide != null else -INF


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


## Number of separate starts (1 on most maps).
func get_start_count() -> int:
	return _starts.size()


## Decides which start each of `count` fish begins at: an even split with a random
## rotation, shuffled by `rng`, so the extra fish of an uneven split do not always land on the
## same start. Draws nothing from `rng` on a map with a single start.
func plan_starts(count: int, rng: RandomNumberGenerator) -> void:
	_start_of.clear()
	_slot_of.clear()
	var starts: int = _starts.size()
	if starts <= 1:
		return
	var rotation: int = rng.randi_range(0, starts - 1)
	for i: int in count:
		_start_of.append((i + rotation) % starts)
	for i: int in range(count - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: int = _start_of[i]
		_start_of[i] = _start_of[j]
		_start_of[j] = swap
	var used: Array[int] = []
	used.resize(starts)
	used.fill(0)
	for start: int in _start_of:
		_slot_of.append(used[start])
		used[start] += 1


## Index of the start the nth fish begins at (see [method plan_starts]). Without a plan the fish
## are dealt out to the starts in turn.
func get_start_of(index: int) -> int:
	if _starts.size() <= 1:
		return 0
	if index < _start_of.size():
		return _start_of[index]
	return index % _starts.size()


## Global position of the nth fish's start slot (grid of spawn_columns per row, rows stack upward).
func get_spawn_position(index: int) -> Vector2:
	var start: int = get_start_of(index)
	var slot: int = index
	if _starts.size() > 1:
		slot = _slot_of[index] if index < _slot_of.size() else index / _starts.size()
	var col: int = slot % spawn_columns
	var row: int = slot / spawn_columns
	return _starts[start].to_global(Vector2(col * spawn_spacing, -row * spawn_spacing))


## Global position of the finish gate.
func get_finish_position() -> Vector2:
	return _finish.global_position


## Progress along the route in [0, 1] for a global position. On a multi-start map the feeders
## fill the first `merge_progress` of the scale and the centerline the rest.
func get_progress(global_pos: Vector2) -> float:
	for hazard: Hazard in get_hazards():
		var known: float = hazard.progress_at(global_pos, _finish.global_position)
		if known >= 0.0:
			return known
	return _route_progress(global_pos)


func _route_progress(global_pos: Vector2) -> float:
	var route: int = _nearest_route(global_pos)
	var path: Path2D = _route_path(route)
	var length: float = path.curve.get_baked_length()
	if length <= 0.0:
		return 0.0
	var along: float = path.curve.get_closest_offset(path.to_local(global_pos)) / length
	if _feeders.is_empty():
		return along
	if route < _feeders.size():
		return merge_progress * along
	return merge_progress + (1.0 - merge_progress) * along


## Unit vector along the route (toward the finish) nearest to a global position.
func get_forward(global_pos: Vector2) -> Vector2:
	var path: Path2D = _route_path(_nearest_route(global_pos))
	var curve: Curve2D = path.curve
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return Vector2.DOWN
	var offset: float = curve.get_closest_offset(path.to_local(global_pos))
	var ahead: Vector2 = curve.sample_baked(minf(offset + FORWARD_SAMPLE, length))
	var behind: Vector2 = curve.sample_baked(maxf(offset - FORWARD_SAMPLE, 0.0))
	var direction: Vector2 = path.to_global(ahead) - path.to_global(behind)
	if direction.length_squared() < 0.0001:
		return Vector2.DOWN
	return direction.normalized()


## Routes are the feeders in start order, then the centerline.
func _route_path(route: int) -> Path2D:
	return _feeders[route] if route < _feeders.size() else _centerline


## Index of the route whose line passes closest to a global position.
func _nearest_route(global_pos: Vector2) -> int:
	var best: int = _feeders.size()
	if _feeders.is_empty():
		return best
	var best_distance: float = _distance_to(_centerline, global_pos)
	for i: int in _feeders.size():
		var distance: float = _distance_to(_feeders[i], global_pos)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


func _distance_to(path: Path2D, global_pos: Vector2) -> float:
	var local: Vector2 = path.to_local(global_pos)
	return local.distance_to(path.curve.get_closest_point(local))


func _on_finish_body_entered(body: Node2D) -> void:
	marble_reached_finish.emit(body)
