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
	clear()
	_track = track
	if not _track.marble_reached_finish.is_connected(_on_marble_reached_finish):
		_track.marble_reached_finish.connect(_on_marble_reached_finish)
	var ids: Array[int] = []
	for i: int in count:
		ids.append(i)
		var marble: Marble = marble_scene.instantiate() as Marble
		marble.id = i
		marble.color = Color.from_hsv(fposmod(i * 0.618034, 1.0), 0.7, 0.95)
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
	for marble: Marble in _marbles.values():
		marble.queue_free()
	_marbles.clear()


func get_marbles() -> Array:
	return _marbles.values()


func get_progress_map() -> Dictionary:
	var progress: Dictionary = {}
	for id: int in _marbles:
		var marble: Marble = _marbles[id]
		progress[id] = _track.get_progress(marble.global_position)
	return progress


func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	if elapsed >= timeout_seconds:
		_finish_race()


func _on_marble_reached_finish(body: Node2D) -> void:
	if not running or not body is Marble:
		return
	var marble: Marble = body as Marble
	var place: int = _ranking.record_finish(marble.id, elapsed)
	if place == 0:
		return
	marble_finished.emit(marble.id, place)
	if _ranking.all_finished():
		_finish_race()


func _finish_race() -> void:
	running = false
	race_finished.emit(_ranking.get_results(get_progress_map()))
