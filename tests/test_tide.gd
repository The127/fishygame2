extends GutTest
## Ebb Tide: the water drains from the top down and fish left above the waterline are stranded.

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


func _sink_the_waterline() -> void:
	# Everything is above a waterline this low, as if the tide were already out.
	_water.start_y = 5000.0
	_water.stop()


func test_the_tide_map_has_a_tide_and_the_others_do_not() -> void:
	assert_true(_track.has_tide())
	var other: Track = TrackCatalog.instantiate("zigzag")
	add_child_autofree(other)
	assert_false(other.has_tide())


func test_water_is_full_until_a_race_starts() -> void:
	assert_false(_water.draining)
	assert_almost_eq(_track.get_water_level(), _water.start_y, 0.001)
	_drain_for(10.0)
	assert_almost_eq(_track.get_water_level(), _water.start_y, 0.001, "an idle tide stays put")


func test_drain_waits_then_falls_to_the_end_level() -> void:
	_water.reseed(1)
	_drain_for(_water.start_delay - 0.1)
	assert_almost_eq(_water.level, _water.start_y, 0.001, "the water holds during the delay")
	var seen: float = _water.level
	for i: int in 50:
		_drain_for(1.0)
		assert_gte(_water.level, seen, "the waterline only ever goes down")
		seen = _water.level
	assert_almost_eq(_water.level, _water.end_y, 0.001)


func test_stop_refills_and_hold_freezes() -> void:
	_water.reseed(1)
	_drain_for(_water.start_delay + 10.0)
	assert_gt(_water.level, _water.start_y)
	_water.hold()
	var held: float = _water.level
	_drain_for(5.0)
	assert_eq(_water.level, held, "a held tide stops where it is")
	_water.stop()
	assert_almost_eq(_water.level, _water.start_y, 0.001)
	assert_almost_eq(_water.position.y, _water.start_y, 0.001, "the drawn water follows")


func test_bigger_fields_get_a_slower_drain() -> void:
	assert_almost_eq(_water.drain_seconds_for(_water.tuned_fish), _water.drain_seconds, 0.001)
	assert_gt(_water.drain_seconds_for(40), _water.drain_seconds_for(20))
	assert_lt(_water.drain_seconds_for(5), _water.drain_seconds_for(20))
	assert_gte(_water.drain_seconds_for(0), 10.0, "never absurdly fast")


func test_the_drain_time_varies_a_little_per_seed_and_replays() -> void:
	var base: float = _water.drain_seconds_for(20)
	var times: Dictionary = {}
	for seed_value: int in 20:
		_water.reseed(seed_value)
		var t: float = _water.current_drain_seconds()
		assert_between(t, base * (1.0 - _water.variation), base * (1.0 + _water.variation))
		times[snappedf(t, 0.001)] = true
	assert_gt(times.size(), 1, "different seeds drain at different paces")
	_water.reseed(7)
	var first: float = _water.current_drain_seconds()
	_water.reseed(7)
	assert_eq(_water.current_drain_seconds(), first)


func test_a_fish_is_stranded_after_the_grace_period_above_the_waterline() -> void:
	var marble: Marble = _marble_at(Vector2(500, 100))
	for i: int in roundi(Marble.DRY_GRACE / STEP) - 5:
		assert_false(marble.update_dryness(300.0, STEP))
	assert_false(marble.stranded)
	var stranded_now: bool = false
	for i: int in 10:
		stranded_now = marble.update_dryness(300.0, STEP) or stranded_now
	assert_true(stranded_now, "the call that strands the fish says so")
	assert_true(marble.stranded)
	assert_true(marble.is_out())
	assert_true(marble.eaten, "a stranded fish is out of the physics like an eaten one")
	assert_true(marble.freeze)
	assert_false(marble.snapped)


func test_getting_wet_again_dries_the_fish_out_faster_than_it_gathered() -> void:
	var marble: Marble = _marble_at(Vector2(500, 100))
	for i: int in 60:
		marble.update_dryness(300.0, STEP)
	var dry: float = marble.dry_time
	assert_almost_eq(dry, 1.0, 0.02)
	marble.global_position = Vector2(500, 400)
	for i: int in 15:
		marble.update_dryness(300.0, STEP)
	assert_almost_eq(
		marble.dry_time, dry - 0.5, 0.02, "a quarter second wet takes half a second off"
	)
	for i: int in 120:
		marble.update_dryness(300.0, STEP)
	assert_eq(marble.dry_time, 0.0)
	assert_false(marble.stranded)


func test_a_stranded_fish_cannot_be_released_or_stranded_twice() -> void:
	var marble: Marble = _marble_at(Vector2(500, 100))
	marble.strand()
	marble.release(Vector2(500, 600), Vector2.ZERO)
	assert_true(marble.eaten, "release leaves a stranded fish where it lies")
	assert_false(marble.update_dryness(300.0, 10.0), "a stranded fish is not stranded again")


func test_a_stranded_fish_fades_out() -> void:
	var marble: Marble = _marble_at(Vector2(500, 100))
	marble.strand()
	await wait_seconds(Marble.FLOP_SECONDS + Marble.STRAND_FADE_SECONDS + 0.4)
	assert_false(marble.visible)


func test_fish_above_the_waterline_are_stranded_and_the_race_ends_with_nobody_through() -> void:
	var race: Race = _make_race(4)
	_sink_the_waterline()
	watch_signals(race)
	for i: int in roundi(Marble.DRY_GRACE / STEP) + 5:
		race._physics_process(STEP)
	assert_signal_emit_count(race, "fish_stranded", 4)
	assert_signal_emitted(race, "race_finished", "with nobody left swimming the race ends")
	var results: Array = get_signal_parameters(race, "race_finished", 0)[0]
	assert_eq(results.size(), 4)
	for result: Dictionary in results:
		assert_false(result["finished"], "stranded fish are DNF")
		assert_true(race.is_stranded(int(result["id"])))
	assert_false(race.running)


func test_a_finisher_keeps_its_place_while_the_rest_are_stranded() -> void:
	var race: Race = _make_race(3)
	var winner: Marble = race.get_marbles()[1]
	race._on_marble_reached_finish(winner)
	_sink_the_waterline()
	watch_signals(race)
	for i: int in roundi(Marble.DRY_GRACE / STEP) + 5:
		race._physics_process(STEP)
	assert_signal_emit_count(race, "fish_stranded", 2, "a fish that finished cannot be stranded")
	assert_false(race.is_stranded(winner.id))
	var results: Array = get_signal_parameters(race, "race_finished", 0)[0]
	assert_eq(int(results[0]["id"]), winner.id)
	assert_true(results[0]["finished"])
	assert_false(results[1]["finished"])


func test_the_race_tells_the_tide_how_many_fish_race() -> void:
	_make_race(40)
	assert_almost_eq(_water.current_drain_seconds() / _water.drain_seconds_for(40), 1.0, 0.05)


func test_clearing_the_race_refills_the_water() -> void:
	var race: Race = _make_race(2)
	_drain_for(_water.start_delay + 10.0)
	assert_gt(_water.level, _water.start_y)
	race.clear()
	assert_almost_eq(_water.level, _water.start_y, 0.001)
	assert_false(_water.draining)


func test_fish_start_below_the_waterline() -> void:
	var race: Race = _make_race(40)
	for marble: Marble in race.get_marbles():
		assert_gt(marble.global_position.y, _water.start_y, "nobody starts out of the water")


func test_the_waterline_takes_part_in_the_finish_replay() -> void:
	assert_true(Replayable.find_in(_track).has(_water))
	_water.replay_apply(PackedFloat32Array([100.0, 1.0]), PackedFloat32Array([200.0, 3.0]), 0.5)
	assert_almost_eq(_water.level, 150.0, 0.001)
	assert_almost_eq(_water.position.y, 150.0, 0.001, "the drawn water follows")
	assert_eq(_water.replay_state().size(), 2)
	assert_almost_eq(_water.replay_state()[0], 150.0, 0.001)
