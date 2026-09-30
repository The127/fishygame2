extends GutTest
## Shipwreck's sinking ship: trigger zones bring stages that lean gravity over and raise the
## water, and a stage is never undone. The finish replay shows the lean and the flood.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _ship: ShipSinking
var _race: Race


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _make_track() -> void:
	_track = TrackCatalog.instantiate("wreck")
	add_child_autofree(_track)
	_ship = _track.get_node("Sinking") as ShipSinking


func _marble() -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	return marble


func _zone(index: int) -> Area2D:
	return _ship.get_node("Zones").get_child(index) as Area2D


func _settle(seconds: float) -> void:
	for _i: int in int(seconds / STEP):
		_ship.tick(STEP)


func test_the_ship_floats_until_a_race_starts() -> void:
	_make_track()
	assert_eq(_ship.stage, 0)
	assert_false(_ship.is_armed())
	assert_eq(_ship.stage_count(), 4)
	assert_eq(_ship.get_node("Zones").get_child_count(), 4)
	assert_almost_eq(_ship.get_node("Gravity").gravity_direction.x, 0.0, 0.0001)
	_zone(0).body_entered.emit(_marble())
	assert_eq(_ship.stage, 0, "a zone does nothing before a race")


func test_the_first_fish_into_a_zone_brings_the_next_stage() -> void:
	_make_track()
	_ship.reseed(3)
	watch_signals(_ship)
	_zone(0).body_entered.emit(_marble())
	assert_eq(_ship.stage, 1)
	assert_signal_emitted_with_parameters(_ship, "stage_reached", [1])
	_zone(0).body_entered.emit(_marble())
	assert_eq(_ship.stage, 1, "the same zone again changes nothing")
	_zone(2).body_entered.emit(_marble())
	assert_eq(_ship.stage, 3, "a fish that skips a zone brings every stage up to its own")
	_zone(1).body_entered.emit(_marble())
	assert_eq(_ship.stage, 3, "a stage is never undone")
	assert_signal_emit_count(_ship, "stage_reached", 2)


func test_only_fish_trigger_a_zone() -> void:
	_make_track()
	_ship.reseed(3)
	var not_a_fish: Node2D = Node2D.new()
	add_child_autofree(not_a_fish)
	_zone(0).body_entered.emit(not_a_fish)
	assert_eq(_ship.stage, 0)


func test_the_lean_and_the_water_only_grow() -> void:
	_make_track()
	_ship.reseed(3)
	var last_lean: float = 0.0
	var last_level: float = _ship.flood_level
	for stage: int in range(1, _ship.stage_count() + 1):
		_ship.reach_stage(stage)
		for _i: int in 600:
			_ship.tick(STEP)
			assert_true(absf(_ship.lean) >= last_lean - 0.0001, "the lean never eases")
			assert_true(_ship.flood_level <= last_level + 0.0001, "the water never drops")
			last_lean = absf(_ship.lean)
			last_level = _ship.flood_level
	assert_almost_eq(absf(_ship.lean), ShipSinking.LEAN_DEGREES[4], 0.001)
	assert_almost_eq(_ship.flood_level, ShipSinking.FLOOD_LEVELS[4], 0.001)


func test_gravity_and_the_water_follow_the_ship() -> void:
	_make_track()
	_ship.reseed(3)
	_ship.reach_stage(4)
	_settle(10.0)
	var gravity: Area2D = _ship.get_node("Gravity") as Area2D
	var flood: Area2D = _ship.get_node("Flood") as Area2D
	var angle: float = deg_to_rad(_ship.lean)
	assert_almost_eq(gravity.gravity_direction.x, sin(angle), 0.0001)
	assert_gt(gravity.gravity_direction.y, 0.99)
	assert_almost_eq(flood.position.y, ShipSinking.FLOOD_LEVELS[4], 0.001)
	assert_almost_eq(flood.rotation, -angle, 0.0001, "the water stands level under gravity")
	assert_almost_eq(flood.linear_damp, ShipSinking.MAX_DAMP, 0.0001)


func test_the_seed_picks_which_way_the_ship_leans() -> void:
	_make_track()
	var sides: Dictionary = {}
	for seed_value: int in 20:
		_ship.reseed(seed_value)
		_ship.reach_stage(1)
		_settle(2.0)
		sides[signf(_ship.lean)] = true
	assert_eq(sides.size(), 2, "both ways come up over a few seeds")
	_ship.reseed(5)
	_ship.reach_stage(1)
	_settle(2.0)
	var first: float = _ship.lean
	_ship.reseed(5)
	_ship.reach_stage(1)
	_settle(2.0)
	assert_eq(_ship.lean, first, "a seed leans the same way every time")


func test_stopping_puts_the_ship_back_afloat() -> void:
	_make_track()
	_ship.reseed(3)
	_ship.reach_stage(4)
	_settle(10.0)
	_track.stop_gimmicks()
	assert_eq(_ship.stage, 0)
	assert_eq(_ship.lean, 0.0)
	assert_eq(_ship.flood_level, ShipSinking.FLOOD_LEVELS[0])
	assert_false(_ship.is_armed())
	assert_almost_eq(_ship.get_node("Gravity").gravity_direction.x, 0.0, 0.0001)


func test_a_real_race_sinks_the_ship() -> void:
	_make_track()
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 10, _rng(11), 0)
	assert_true(_ship.is_armed())
	var frames: int = 0
	while _ship.stage < _ship.stage_count() and frames < 6000:
		await get_tree().physics_frame
		frames += 1
	assert_eq(_ship.stage, _ship.stage_count(), "the leaders reach every zone")
	assert_lt(_ship.flood_level, ShipSinking.FLOOD_LEVELS[0])


func test_the_replay_shows_the_lean_and_the_flood_and_leaves_the_stage_alone() -> void:
	_make_track()
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 4, _rng(5), 0)
	_ship.reach_stage(2)
	_settle(1.0)
	var recorder: ReplayRecorder = _race.get_recorder()
	var frames: int = 0
	while not recorder.is_done() and frames < 600:
		await get_tree().physics_frame
		frames += 1
		if frames == 60:
			_ship.reach_stage(4)
		if frames == 300:
			_track.marble_reached_finish.emit(_race.get_marbles()[0])
	assert_true(recorder.is_done())
	var leaned_to: float = _ship.lean
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var nodes: Array[Node] = recorder.nodes()
	var index: int = nodes.find(_ship)
	assert_gt(index, -1, "the sinking is recorded")
	var bad: int = 0
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		var state: PackedFloat32Array = _ship.replay_state()
		var recorded: PackedFloat32Array = recorder.node_state_at(k, index)
		for i: int in state.size():
			if absf(state[i] - recorded[i]) > 0.01:
				bad += 1
		assert_eq(_ship.stage, int(recorded[2]), "the replay does not sink the ship further")
	assert_eq(bad, 0, "the lean and the water show what was recorded")
	replay.stop()
	assert_almost_eq(_ship.lean, leaned_to, 0.001, "the ship comes back as the race left it")
