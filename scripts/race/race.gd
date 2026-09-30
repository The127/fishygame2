class_name Race
extends Node2D
## Spawns marbles on a track, tracks the finish order and emits results.

signal marble_finished(id: int, place: int)
signal race_finished(results: Array[Dictionary])
## A Thanos snap just turned these fish to dust.
signal fish_snapped(ids: Array[int])
## The tide just left this fish stranded above the waterline.
signal fish_stranded(id: int)
## The winner just crossed with `chaser_id` about to follow. Visual cue only.
signal photo_finish(winner_id: int, chaser_id: int)
## A fish picked up a treasure worth `value` points. `kind` is a [enum Treasure.Kind].
signal treasure_collected(id: int, kind: int, value: int)

const SPAWN_JITTER: float = 3.0
@export var marble_scene: PackedScene
## Safety net: ends the race even without a time limit, so a jam can never hang a round.
@export var timeout_seconds: float = 90.0
## Race length in seconds; fish still racing at that point are DNF. 0 or less means no limit.
@export var time_limit: float = 0.0

## Whether treasures lie on the map. Set before [method start].
@export var treasures_enabled: bool = true

## The random event this race runs under (see [RaceEvent]), [constant RaceEvent.NOTHING] for none.
var event: String = RaceEvent.NOTHING
var elapsed: float = 0.0
var running: bool = false
## Whether [signal photo_finish] fired in this race.
var had_photo_finish: bool = false

var _track: Track
var _ranking: RaceRanking
var _marbles: Dictionary = {}
var _powers: RacePowers
var _treasures: RaceTreasures
var _snap_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _snap_pending: bool = false
var _snap_time: float = 0.0
var _recorder: ReplayRecorder
var _sample_positions: PackedVector2Array = PackedVector2Array()
var _sample_velocities: PackedVector2Array = PackedVector2Array()
var _sample_alphas: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	_powers = RacePowers.new(self, _marbles, _live_marble, _record_event)
	_treasures = RaceTreasures.new(self, _marbles, _live_marble)
	_treasures.collected.connect(treasure_collected.emit)


## Clears any previous race and spawns `count` marbles. Every random draw comes
## from the given rng. `hazard_frequency` (1 to 5) turns on the map's hazard events, 0 leaves them off.
## `random_event` is a [RaceEvent] id; it changes the rules but draws nothing from `rng`.
func start(
	track: Track,
	count: int,
	rng: RandomNumberGenerator,
	hazard_frequency: int = 0,
	random_event: String = RaceEvent.NOTHING
) -> void:
	assert(marble_scene != null and count > 0, "Race needs a marble_scene and count > 0")
	clear()
	_track = track
	event = random_event
	_track.modulate = RaceEvent.track_tint(event)
	_track.marble_reached_finish.connect(_on_marble_reached_finish)
	if not _track.burst_played.is_connected(_on_burst_played):
		_track.burst_played.connect(_on_burst_played)
	# Read before any draw and never advanced, so a snap cannot shift the race's layout.
	_snap_rng.seed = hash(rng.state)
	_snap_pending = event == RaceEvent.THANOS_SNAP
	_snap_time = _snap_rng.randf_range(RaceEvent.SNAP_MIN_SECONDS, RaceEvent.SNAP_MAX_SECONDS)
	var ids: Array[int] = []
	for i: int in count:
		ids.append(i)
		var marble: Marble = marble_scene.instantiate() as Marble
		marble.id = i
		var jitter: Vector2 = Vector2(
			rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER),
			rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER)
		)
		marble.glow_boost = _track.fish_glow * RaceEvent.glow_scale(event)
		marble.gravity_scale = RaceEvent.gravity_scale(event)
		if RaceEvent.bounce(event) >= 0.0:
			# The material is shared by every marble scene instance, so change a copy.
			var material: PhysicsMaterial = marble.physics_material_override.duplicate()
			material.bounce = RaceEvent.bounce(event)
			marble.physics_material_override = material
		add_child(marble)
		marble.global_position = _track.get_spawn_position(i) + jitter
		_marbles[i] = marble
	_ranking = RaceRanking.new(ids)
	_track.set_field_size(count)
	_track.seed_gimmicks(rng)
	# Read before any later draw and never advanced, so treasures cannot shift a race's layout.
	_powers.track = _track
	if treasures_enabled:
		_treasures.place(_track, hash(rng.state))
	_track.arm_hazards(rng, RaceEvent.hazard_level(event, hazard_frequency))
	_recorder = ReplayRecorder.new(count)
	_recorder.bind_nodes(Replayable.find_in(_track))
	_sample_positions.resize(count)
	_sample_velocities.resize(count)
	_sample_alphas.resize(count)
	had_photo_finish = false
	elapsed = 0.0
	running = true


func clear() -> void:
	running = false
	_snap_pending = false
	event = RaceEvent.NOTHING
	if _track != null:
		_track.modulate = Color.WHITE
		_track.stop_hazards()
		_track.stop_gimmicks()
	if _track != null and _track.burst_played.is_connected(_on_burst_played):
		_track.burst_played.disconnect(_on_burst_played)
	if _track != null and _track.marble_reached_finish.is_connected(_on_marble_reached_finish):
		_track.marble_reached_finish.disconnect(_on_marble_reached_finish)
	_track = null
	_ranking = null
	_powers.clear()
	_treasures.clear()
	for marble: Marble in _marbles.values():
		# Leave the tree now so a stale marble can't trigger the finish area this frame.
		remove_child(marble)
		marble.queue_free()
	_marbles.clear()


## The recorded finish of this race, for [FinishReplay]. Null before the first race.
func get_recorder() -> ReplayRecorder:
	return _recorder


## Seconds left before the time limit, or -1.0 when there is no limit or no race is running.
func time_left() -> float:
	if not running or time_limit <= 0.0:
		return -1.0
	return maxf(time_limit - elapsed, 0.0)


func get_marbles() -> Array[Marble]:
	var result: Array[Marble] = []
	for marble: Marble in _marbles.values():
		result.append(marble)
	return result


## Pushes a marble toward the finish. Returns false if the race is not running or the id is unknown.
func boost_marble(id: int) -> bool:
	return _powers.boost(id)


## Knocks a marble back and slows it. Returns false if the race is not running or the id is unknown.
func curse_marble(id: int) -> bool:
	return _powers.curse(id)


## Gives a marble a small cheering nudge toward the finish. `strength` is in emote units.
## Returns false if the race is not running or the id is unknown.
func cheer_marble(id: int, strength: float) -> bool:
	return _powers.cheer(id, strength)


## Makes a marble meow, purely for show. Returns false if the race is not running or the id is unknown.
func meow_marble(id: int) -> bool:
	if not running or not _marbles.has(id):
		return false
	(_marbles[id] as Marble).meow()
	return true


## Debug hook: makes a random fish meow. Returns false if the race is not running.
func meow_random_marble() -> bool:
	if not running or _marbles.is_empty():
		return false
	return meow_marble(_marbles.keys().pick_random() as int)


## The streamer's fishing rod: drops a hook at `pos` and yanks the nearest fish within
## `radius` back up the track. Returns that fish's id, or -1 if the race is not running
## or no fish is in reach (the hook still drops).
func hook_near(pos: Vector2, radius: float) -> int:
	if not running:
		return -1
	return _powers.hook_near(pos, radius)


## The streamer's net: holds fish inside the area for `seconds`. Returns how many fish are in
## it now (fish that swim in later are held too). Does nothing if the race is not running.
func place_net(pos: Vector2, radius: float, seconds: float) -> int:
	if not running:
		return 0
	return _powers.place_net(pos, radius, seconds)


## The streamer's bubble blast: shoves every fish within `radius` away from `pos`, hardest
## at the centre. Returns how many fish it hit.
func blast(pos: Vector2, radius: float) -> int:
	if not running:
		return 0
	return _powers.blast(pos, radius)


## Current global position of every marble still racing, id -> Vector2.
func get_position_map() -> Dictionary:
	var positions: Dictionary = {}
	for id: int in _marbles:
		if _ranking != null and _ranking.is_finished(id):
			continue
		var marble: Marble = _marbles[id]
		if marble.eaten:
			continue
		positions[id] = marble.global_position
	return positions


func get_progress_map() -> Dictionary:
	var progress: Dictionary = {}
	for id: int in _marbles:
		var marble: Marble = _marbles[id]
		# A snapped fish ranks behind every other fish that did not finish.
		progress[id] = -1.0 if marble.snapped else _track.get_progress(marble.global_position)
	return progress


## The marble with this id if it is still racing (not yet finished), else null.
func _live_marble(id: int) -> Marble:
	if not running or _ranking == null or not _marbles.has(id):
		return null
	if _ranking.is_finished(id) or (_marbles[id] as Marble).eaten:
		return null
	return _marbles[id]


## Treasures still lying on the map.
func treasures_left() -> int:
	return _treasures.left()


func _physics_process(delta: float) -> void:
	if not running:
		return
	_powers.hold_in_nets()
	_treasures.collect()
	elapsed += delta
	_strand_dry_fish(delta)
	if not running:
		return
	if _snap_pending and elapsed >= _snap_time:
		_snap()
	if _recorder != null and _recorder.should_sample(elapsed):
		_record_sample()
	if elapsed >= timeout_seconds or (time_limit > 0.0 and elapsed >= time_limit):
		_finish_race()


func _on_marble_reached_finish(body: Node2D) -> void:
	if not running or _ranking == null or not body is Marble:
		return
	var marble: Marble = body as Marble
	if _marbles.get(marble.id) != marble:
		return
	var place: int = _ranking.record_finish(marble.id, elapsed)
	if place == 0:
		return
	marble.has_finished = true
	if place == 1:
		# A frame right at the crossing, so the replay is centred on it.
		_record_sample()
		_recorder.mark_finish(elapsed, marble.id)
	_record_event(ReplayRecorder.Kind.SPLASH, marble)
	marble.splash()
	if place == 1:
		marble.celebrate()
	marble_finished.emit(marble.id, place)
	if place == 1:
		_check_photo_finish(marble.id)
	if _all_racers_finished():
		_finish_race()


## Whether every fish that is still in the race has finished (snapped and stranded fish do not
## count).
func _all_racers_finished() -> bool:
	for id: int in _ranking.get_unfinished_ids():
		if not (_marbles[id] as Marble).is_out():
			return false
	return true


## Whether the fish was left high and dry by the tide.
func is_stranded(id: int) -> bool:
	return _marbles.has(id) and (_marbles[id] as Marble).stranded


## On a map with a draining tide, fish that lie above the waterline for too long are stranded.
## Ends the race when that leaves nobody still swimming.
func _strand_dry_fish(delta: float) -> void:
	if not _track.has_tide():
		return
	var waterline: float = _track.get_water_level()
	var any_stranded: bool = false
	for id: int in _marbles:
		var marble: Marble = _live_marble(id)
		if marble != null and marble.update_dryness(waterline, delta):
			any_stranded = true
			fish_stranded.emit(id)
	if any_stranded and _all_racers_finished():
		_finish_race()


## Whether the fish was turned to dust by a Thanos snap.
func is_snapped(id: int) -> bool:
	return _marbles.has(id) and (_marbles[id] as Marble).snapped


## The Thanos snap: half of the fish still racing (a seeded pick) turn to dust.
func _snap() -> void:
	_snap_pending = false
	var racing: Array[int] = []
	for id: int in _marbles:
		if _live_marble(id) != null:
			racing.append(id)
	racing.sort()
	var count: int = RaceEvent.snap_count(racing.size())
	if count == 0:
		return
	# Partial Fisher-Yates shuffle: the first `count` ids are the victims.
	for i: int in count:
		var j: int = _snap_rng.randi_range(i, racing.size() - 1)
		var swap: int = racing[i]
		racing[i] = racing[j]
		racing[j] = swap
	var victims: Array[int] = racing.slice(0, count)
	for id: int in victims:
		var marble: Marble = _marbles[id]
		_record_event(ReplayRecorder.Kind.SPLASH, marble)
		marble.snap()
	fish_snapped.emit(victims)
	if _all_racers_finished():
		_finish_race()


## Emits photo_finish when another marble is about to cross right behind the winner.
## Reads state only, so it cannot change the outcome.
func _check_photo_finish(winner_id: int) -> void:
	var finish: Vector2 = _track.get_finish_position()
	var chaser_id: int = -1
	var best_eta: float = INF
	for id: int in _marbles:
		if id == winner_id or _ranking.is_finished(id):
			continue
		var marble: Marble = _marbles[id]
		var distance: float = marble.global_position.distance_to(finish)
		var to_finish: Vector2 = finish - marble.global_position
		# Only the speed toward the gate counts, not sideways or backwards motion.
		var speed: float = maxf(0.0, marble.linear_velocity.dot(to_finish.normalized()))
		if PhotoFinish.is_close(distance, speed) and PhotoFinish.eta(distance, speed) < best_eta:
			best_eta = PhotoFinish.eta(distance, speed)
			chaser_id = id
	if chaser_id >= 0:
		had_photo_finish = true
		photo_finish.emit(winner_id, chaser_id)


func _record_sample() -> void:
	for id: int in _marbles:
		var marble: Marble = _marbles[id]
		_sample_positions[id] = marble.global_position
		_sample_velocities[id] = marble.linear_velocity
		# Swallowed and snapped fish are hidden (snapped ones fade out first).
		_sample_alphas[id] = marble.modulate.a if marble.visible else 0.0
	_recorder.sample(elapsed, _sample_positions, _sample_velocities, _sample_alphas)


func _record_event(kind: ReplayRecorder.Kind, marble: Marble) -> void:
	if _recorder != null:
		_recorder.add_event(elapsed, marble.id, kind, marble.global_position)


func _on_burst_played(
	at: Vector2, color: Color, amount: int, speed: float, gravity: Vector2
) -> void:
	if _recorder == null or not running:
		return
	_recorder.add_event(
		elapsed,
		-1,
		ReplayRecorder.Kind.BURST,
		at,
		{"color": color, "amount": amount, "speed": speed, "gravity": gravity}
	)


func _finish_race() -> void:
	running = false
	_track.stop_hazards()
	_track.hold_tide()
	for marble: Marble in _marbles.values():
		marble.finish_strand()
		marble.set_deferred("freeze", true)
	var results: Array[Dictionary] = _ranking.get_results(get_progress_map())
	race_finished.emit(results)
