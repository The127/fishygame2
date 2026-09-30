extends GutTest
## Shipwreck: a real race with the trapdoor planks armed, recorded and replayed. The planks, the
## propeller and the dust burst of an opening plank all play back as they happened.

const TRACK_SCENE: String = "res://scenes/tracks/wreck_track.tscn"
const MARBLE_SCENE: String = "res://scenes/marble.tscn"

var _race: Race
var _track: Track
var _hazard: PlankHazard
var _propeller: Spinner
## Live state of the planks and the propeller around each recorded frame, by frame time: the
## state after that physics frame and after the two before it (a node may update before or
## after the recorder within a frame, and a plank body only syncs its angle a step later).
var _seen: Dictionary = {}


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _plank_look(plank: AnimatableBody2D) -> Array:
	var visual: Polygon2D = plank.get_node("Visual") as Polygon2D
	var crack: Line2D = visual.get_child(1) as Line2D
	return [plank.rotation, visual.color, crack.visible, crack.modulate.a]


func _live_look() -> Array:
	var look: Array = []
	for child: Node in _hazard.get_children():
		if child is AnimatableBody2D:
			look.append(_plank_look(child as AnimatableBody2D))
	look.append(_propeller.rotation)
	return look


## Runs a race on the map up to shortly after the first plank opens, finishes it and records
## the live look of everything at each recorded frame.
func _record_race() -> ReplayRecorder:
	_track = (load(TRACK_SCENE) as PackedScene).instantiate() as Track
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 3, _rng(11), 5)
	_hazard = _track.get_hazards()[0] as PlankHazard
	_propeller = _track.get_node("Propeller") as Spinner
	var recorder: ReplayRecorder = _race.get_recorder()
	var opens_at: float = _hazard.get_schedule()[0] + _hazard.telegraph_seconds
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
		if not finished and _race.elapsed >= opens_at + 0.6:
			finished = true
			_track.marble_reached_finish.emit(_race.get_marbles()[0])
	return recorder


## Whether every value of `live` matches one of the `options`, each value on its own: the
## recorder may sample a value just before or just after its update within a physics frame, and
## a plank body only takes its angle a step after it was set.
func _matches(live: Array, options: Array) -> bool:
	for i: int in live.size():
		var values: Array = live[i] if live[i] is Array else [live[i]]
		for j: int in values.size():
			if values.size() == 4 and j == 3 and not bool(values[2]):
				continue  # a hidden crack's glow is not shown
			var found: bool = false
			for option: Array in options:
				var other: Variant = option[i][j] if option[i] is Array else option[i]
				found = found or _same(values[j], other)
			if not found:
				return false
	return true


func _same(a: Variant, b: Variant) -> bool:
	if a is float:
		return is_equal_approx(a as float, b as float)
	return a == b


func _replay(recorder: ReplayRecorder) -> FinishReplay:
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	return replay


func _show_frame(replay: FinishReplay, recorder: ReplayRecorder, index: int) -> void:
	replay._frame = index
	replay._clock = recorder.frame_time(index)
	replay._apply()


func test_replayed_planks_and_propeller_match_the_race() -> void:
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
		var live: Array = _live_look()
		compared += 1
		var options: Array = _seen[key]
		assert_true(_matches(live, options), "frame %d" % k)
	assert_true(compared > 30, "compared %d frames" % compared)
	assert_true(phases.has(Hazard.Phase.TELEGRAPH), "the clip shows the telegraph")
	assert_true(phases.has(Hazard.Phase.ACTIVE), "the clip shows the open plank")
	replay.stop()


func test_between_telegraph_and_active_the_phase_switches_without_blending() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = _replay(recorder)
	var checked: bool = false
	for k: int in recorder.frame_count() - 1:
		var from: PackedFloat32Array = recorder.node_state_at(k, _node_index(recorder))
		var to: PackedFloat32Array = recorder.node_state_at(k + 1, _node_index(recorder))
		if int(from[1]) != Hazard.Phase.TELEGRAPH or int(to[1]) != Hazard.Phase.ACTIVE:
			continue
		checked = true
		replay._frame = k
		replay._clock = lerpf(recorder.frame_time(k), recorder.frame_time(k + 1), 0.25)
		replay._apply()
		assert_eq(_hazard.phase, Hazard.Phase.TELEGRAPH)
		assert_almost_eq(_hazard.phase_time, from[2], 0.0001, "telegraph timer not blended")
		replay._clock = lerpf(recorder.frame_time(k), recorder.frame_time(k + 1), 0.75)
		replay._apply()
		assert_eq(_hazard.phase, Hazard.Phase.ACTIVE)
		assert_almost_eq(_hazard.phase_time, to[2], 0.0001, "active timer not blended")
	assert_true(checked, "the clip crosses from telegraph to active")
	replay.stop()


func test_the_dust_burst_is_recorded_and_replayed_when_the_plank_opens() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var bursts: Array[Dictionary] = []
	for event: Dictionary in recorder.events():
		if int(event["kind"]) == ReplayRecorder.Kind.BURST:
			bursts.append(event)
	assert_eq(bursts.size(), 1, "one plank opened in the clip")
	var replay: FinishReplay = _replay(recorder)
	var before: int = _particles(replay)
	replay._clock = float(bursts[0]["time"]) - 0.05
	replay._frame = 0
	replay._event_index = 0
	for event: Dictionary in recorder.events():
		if float(event["time"]) > replay._clock:
			break
		replay._event_index += 1
	replay._apply()
	assert_eq(_particles(replay), before, "no dust before the plank opens")
	replay._clock = float(bursts[0]["time"]) + 0.01
	replay._apply()
	assert_eq(_particles(replay), before + 1, "dust where the plank opened")
	replay.stop()


func _particles(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is CPUParticles2D:
			count += 1
	return count


func _node_index(recorder: ReplayRecorder) -> int:
	return recorder.nodes().find(_hazard)
