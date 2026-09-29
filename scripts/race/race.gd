class_name Race
extends Node2D
## Spawns marbles on a track, tracks the finish order and emits results.

signal marble_finished(id: int, place: int)
signal race_finished(results: Array[Dictionary])

const SPAWN_JITTER: float = 3.0

@export var marble_scene: PackedScene
@export var timeout_seconds: float = 90.0

var elapsed: float = 0.0
var running: bool = false

var _track: Track
var _ranking: RaceRanking
var _marbles: Dictionary = {}


## Clears any previous race and spawns `count` marbles. Every random draw comes
## from the given rng.
func start(track: Track, count: int, rng: RandomNumberGenerator) -> void:
	assert(marble_scene != null and count > 0, "Race needs a marble_scene and count > 0")
	clear()
	_track = track
	_track.marble_reached_finish.connect(_on_marble_reached_finish)
	var ids: Array[int] = []
	for i: int in count:
		ids.append(i)
		var marble: Marble = marble_scene.instantiate() as Marble
		marble.id = i
		var jitter: Vector2 = Vector2(
			rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER),
			rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER)
		)
		add_child(marble)
		marble.global_position = _track.get_spawn_position(i) + jitter
		_marbles[i] = marble
	_ranking = RaceRanking.new(ids)
	elapsed = 0.0
	running = true


func clear() -> void:
	running = false
	if _track != null and _track.marble_reached_finish.is_connected(_on_marble_reached_finish):
		_track.marble_reached_finish.disconnect(_on_marble_reached_finish)
	_track = null
	_ranking = null
	for marble: Marble in _marbles.values():
		# Leave the tree now so a stale marble can't trigger the finish area this frame.
		remove_child(marble)
		marble.queue_free()
	_marbles.clear()


func get_marbles() -> Array[Marble]:
	var result: Array[Marble] = []
	for marble: Marble in _marbles.values():
		result.append(marble)
	return result


## Pushes a marble toward the finish. Returns false if the race is not running or the id is unknown.
func boost_marble(id: int) -> bool:
	var marble: Marble = _live_marble(id)
	if marble == null:
		return false
	marble.boost(_track.get_forward(marble.global_position))
	return true


## Knocks a marble back and slows it. Returns false if the race is not running or the id is unknown.
func curse_marble(id: int) -> bool:
	var marble: Marble = _live_marble(id)
	if marble == null:
		return false
	marble.curse(_track.get_forward(marble.global_position))
	return true


## Current global position of every marble, id -> Vector2.
func get_position_map() -> Dictionary:
	var positions: Dictionary = {}
	for id: int in _marbles:
		var marble: Marble = _marbles[id]
		positions[id] = marble.global_position
	return positions


func get_progress_map() -> Dictionary:
	var progress: Dictionary = {}
	for id: int in _marbles:
		var marble: Marble = _marbles[id]
		progress[id] = _track.get_progress(marble.global_position)
	return progress


## The marble with this id if it is still racing (not yet finished), else null.
func _live_marble(id: int) -> Marble:
	if not running or _ranking == null or not _marbles.has(id):
		return null
	if _ranking.is_finished(id):
		return null
	return _marbles[id]


func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	if elapsed >= timeout_seconds:
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
	marble_finished.emit(marble.id, place)
	if _ranking.all_finished():
		_finish_race()


func _finish_race() -> void:
	running = false
	for marble: Marble in _marbles.values():
		marble.set_deferred("freeze", true)
	race_finished.emit(_ranking.get_results(get_progress_map()))
