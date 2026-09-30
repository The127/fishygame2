extends GutTest
## Sunken City: a real race with the ruins armed, recorded and replayed. The shaking tower, its
## fall, the slabs and the dust of the crash all play back as they happened.

const TRACK_SCENE: String = "res://scenes/tracks/city_track.tscn"
const MARBLE_SCENE: String = "res://scenes/marble.tscn"

var _race: Race
var _track: Track
var _hazard: RuinHazard
## Live look of the ruins around each recorded frame, by frame time: the look after that physics
## frame and after the two before it (a node may update before or after the recorder within a
## frame, and a slab body only syncs its pose a step later).
var _seen: Dictionary = {}


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Per ruin: tower angle, rune glow, slab position, slab angle and slab opacity.
func _live_look() -> Array:
	var look: Array = []
	for ruin: Node in _hazard.get_ruins():
		var slab: AnimatableBody2D = ruin.get_node("Slab") as AnimatableBody2D
		var runes: CanvasItem = ruin.get_node("Tower/Runes") as CanvasItem
		(
			look
			. append(
				[
					(ruin.get_node("Tower") as Node2D).rotation,
					runes.modulate.a,
					slab.position.x,
					slab.position.y,
					slab.rotation,
					(slab.get_node("Visual") as CanvasItem).modulate.a,
				]
			)
		)
	return look


## Runs a race on the map up to shortly after the first tower crashes, finishes it and records
## the live look of everything at each recorded frame.
func _record_race() -> ReplayRecorder:
	_track = (load(TRACK_SCENE) as PackedScene).instantiate() as Track
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 3, _rng(11), 5)
	_hazard = _track.get_hazards()[0] as RuinHazard
	var recorder: ReplayRecorder = _race.get_recorder()
	var crash_at: float = (
		_hazard.get_schedule()[0] + _hazard.telegraph_seconds + RuinHazard.TOPPLE_SECONDS
	)
	var finished: bool = false
	var frames: int = 0
	var history: Array = [_live_look(), _live_look()]
	while not recorder.is_done() and frames < 2000:
		await get_tree().physics_frame
		frames += 1
		var count: int = recorder.frame_count()
		var key: float = snappedf(recorder.frame_time(count - 1), 0.0001) if count > 0 else -1.0
		if count > 0 and not _seen.has(key):
			_seen[key] = [_live_look(), history[0], history[1]]
		history = [_live_look(), history[0]]
		if not finished and _race.elapsed >= crash_at + 0.6:
			finished = true
			_track.marble_reached_finish.emit(_race.get_marbles()[0])
	return recorder


## Whether every value of `live` matches one of the `options`, each value on its own.
func _matches(live: Array, options: Array) -> bool:
	for i: int in live.size():
		var values: Array = live[i]
		for j: int in values.size():
			var found: bool = false
			for option: Array in options:
				found = found or absf(float(values[j]) - float(option[i][j])) < 0.001
			if not found:
				return false
	return true


func _replay(recorder: ReplayRecorder) -> FinishReplay:
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	return replay


func _show_frame(replay: FinishReplay, recorder: ReplayRecorder, index: int) -> void:
	replay._frame = index
	replay._clock = recorder.frame_time(index)
	replay._apply()


func test_replayed_ruins_match_the_race() -> void:
	var recorder: ReplayRecorder = await _record_race()
	assert_true(recorder.has_clip())
	var replay: FinishReplay = _replay(recorder)
	var phases: Dictionary = {}
	var compared: int = 0
	for k: int in recorder.frame_count() - 1:
		var key: float = snappedf(recorder.frame_time(k), 0.0001)
		if not _seen.has(key):
			continue
		_show_frame(replay, recorder, k)
		phases[_hazard.phase] = true
		compared += 1
		assert_true(_matches(_live_look(), _seen[key]), "frame %d" % k)
	assert_true(compared > 30, "compared %d frames" % compared)
	assert_true(phases.has(Hazard.Phase.TELEGRAPH), "the clip shows the tower shake")
	assert_true(phases.has(Hazard.Phase.ACTIVE), "the clip shows the tower fall")
	replay.stop()


func test_the_tower_stands_before_the_clip_and_lies_after_the_crash() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = _replay(recorder)
	var tower: Node2D = null
	for ruin: Node in _hazard.get_ruins():
		if (ruin.get_node("Tower") as Node2D).rotation != 0.0:
			tower = ruin.get_node("Tower") as Node2D
	assert_not_null(tower, "a tower fell in the race")
	_show_frame(replay, recorder, 0)
	var first: float = absf(tower.rotation)
	_show_frame(replay, recorder, recorder.frame_count() - 2)
	var last: float = absf(tower.rotation)
	assert_gt(last, first, "the tower is further down at the end of the clip")
	replay.stop()


func test_the_crash_dust_is_recorded_as_bursts() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var bursts: int = 0
	for event: Dictionary in recorder.events():
		if int(event["kind"]) == ReplayRecorder.Kind.BURST:
			bursts += 1
	assert_gt(bursts, 0, "the clip holds the dust of the crash")


func test_stopping_the_replay_puts_the_ruins_back() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var before: Array = _live_look()
	var replay: FinishReplay = _replay(recorder)
	_show_frame(replay, recorder, 0)
	replay.stop()
	assert_true(_matches(_live_look(), [before]))
