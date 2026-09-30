extends GutTest
## Ebb Tide's invisible triggers: the furthest fish sends the water crashing down to a preset level.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _water: WaterLevel


func before_each() -> void:
	_track = TrackCatalog.instantiate("tide")
	add_child_autofree(_track)
	_water = _track.get_node("WaterLevel") as WaterLevel


func _drain_for(seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		_water._physics_process(STEP)


func _marble_at(pos: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


func _make_race(count: int) -> Race:
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(race)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	race.start(_track, count, rng, 0)
	return race


func _trigger(index: int) -> TideTrigger:
	return _track.get_node("TideTrigger%d" % index) as TideTrigger


func test_the_map_has_trigger_levels_that_only_go_down_the_course() -> void:
	var last: float = -INF
	for i: int in range(1, 6):
		var trigger: TideTrigger = _trigger(i)
		assert_gt(trigger.level_y, last, "each trigger drops the water further than the one before")
		last = trigger.level_y
	assert_lt(last, _water.end_y)


func test_tripping_a_trigger_drops_the_water_fast_and_holds_it() -> void:
	_water.reseed(1)
	_drain_for(1.0)
	var target: float = 200.0
	_water.drop_to(target)
	_drain_for(0.3)
	var partway: float = _water.level
	assert_gt(partway, _water.start_y, "the water is on its way down")
	assert_lt(partway, target, "it takes a moment to get there")
	_drain_for(2.0)
	assert_almost_eq(_water.level, target, 0.001, "the water stops at the trigger's level")
	_drain_for(2.0)
	assert_almost_eq(_water.level, target, 0.001, "and holds while the steady drain is behind")


func test_the_water_never_rises_after_a_trigger() -> void:
	_water.reseed(1)
	_water.drop_to(300.0)
	_drain_for(3.0)
	var seen: float = _water.level
	_water.drop_to(100.0)
	_drain_for(1.0)
	assert_eq(_water.level, seen, "a higher target is ignored")
	_water.drop_to(250.0)
	_drain_for(1.0)
	assert_gte(_water.level, seen)
	for i: int in 400:
		_drain_for(1.0)
		assert_gte(_water.level, seen, "the steady drain never lifts it either")
		seen = _water.level
	assert_almost_eq(_water.level, _water.end_y, 0.001)


func test_triggers_do_nothing_when_the_tide_is_not_draining() -> void:
	_water.drop_to(400.0)
	_drain_for(2.0)
	assert_almost_eq(_water.level, _water.start_y, 0.001)


func test_a_new_race_starts_from_full_water_after_a_trigger() -> void:
	_water.reseed(1)
	_water.drop_to(400.0)
	_drain_for(4.0)
	assert_gt(_water.level, 300.0)
	_water.reseed(2)
	_drain_for(1.0)
	assert_almost_eq(_water.level, _water.start_y, 0.001, "the earlier trigger is forgotten")


func test_a_live_fish_trips_a_trigger_once_and_until_rearmed() -> void:
	var trigger: TideTrigger = _trigger(1)
	watch_signals(trigger)
	var marble: Marble = _marble_at(Vector2(0, 0))
	trigger._on_body_entered(marble)
	assert_signal_emit_count(trigger, "tripped", 1)
	assert_eq(get_signal_parameters(trigger, "tripped", 0)[0], trigger.level_y)
	trigger._on_body_entered(_marble_at(Vector2(0, 0)))
	assert_signal_emit_count(trigger, "tripped", 1, "only the furthest fish trips it")
	trigger.rearm()
	trigger._on_body_entered(_marble_at(Vector2(0, 0)))
	assert_signal_emit_count(trigger, "tripped", 2)


func test_a_stranded_fish_or_a_wall_does_not_trip_a_trigger() -> void:
	var trigger: TideTrigger = _trigger(1)
	watch_signals(trigger)
	var marble: Marble = _marble_at(Vector2(0, 0))
	marble.strand()
	trigger._on_body_entered(marble)
	trigger._on_body_entered(_track.get_node("Floor") as Node2D)
	assert_signal_not_emitted(trigger, "tripped")


func test_the_leading_fish_entering_a_trigger_lowers_the_track_water() -> void:
	var race: Race = _make_race(3)
	var leader: Marble = race.get_marbles()[0]
	var trigger: TideTrigger = _trigger(2)
	_drain_for(1.0)
	trigger._on_body_entered(leader)
	_drain_for(4.0)
	assert_almost_eq(_track.get_water_level(), trigger.level_y, 0.001)


func test_starting_a_race_rearms_the_triggers() -> void:
	var trigger: TideTrigger = _trigger(1)
	trigger._on_body_entered(_marble_at(Vector2(0, 0)))
	_make_race(2)
	watch_signals(trigger)
	trigger._on_body_entered(_marble_at(Vector2(0, 0)))
	assert_signal_emit_count(trigger, "tripped", 1)
