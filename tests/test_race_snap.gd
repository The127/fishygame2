extends GutTest
## The Thanos snap random event: half the racing fish turn to dust and count as unfinished.

const TRACK_SCENE: String = "res://scenes/tracks/test_track.tscn"
const MARBLE_SCENE: String = "res://scenes/marble.tscn"


func _make_race(count: int, seed_value: int = 5, event: String = RaceEvent.THANOS_SNAP) -> Race:
	var track: Track = (load(TRACK_SCENE) as PackedScene).instantiate() as Track
	add_child_autofree(track)
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(race)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	race.start(track, count, rng, 0, event)
	return race


func _run_until_snap(race: Race) -> void:
	race._snap_time = 0.5
	for i: int in 60:
		race._physics_process(1.0 / 60.0)


func test_snap_removes_half_of_the_racing_fish() -> void:
	var race: Race = _make_race(6)
	watch_signals(race)
	_run_until_snap(race)
	assert_signal_emitted(race, "fish_snapped")
	var snapped_count: int = 0
	for marble: Marble in race.get_marbles():
		if marble.snapped:
			snapped_count += 1
			assert_true(race.is_snapped(marble.id))
	assert_eq(snapped_count, 3)
	assert_eq(race.get_position_map().size(), 3, "snapped fish leave the position map")


func test_snapped_fish_are_dnf_and_rank_last() -> void:
	var race: Race = _make_race(4)
	_run_until_snap(race)
	var survivors: Array[int] = []
	for marble: Marble in race.get_marbles():
		if not marble.snapped:
			survivors.append(marble.id)
	watch_signals(race)
	for id: int in survivors:
		for marble: Marble in race.get_marbles():
			if marble.id == id:
				race._on_marble_reached_finish(marble)
	assert_signal_emitted(race, "race_finished", "the race ends once every fish left has finished")
	var results: Array = get_signal_parameters(race, "race_finished", 0)[0]
	for i: int in results.size():
		assert_eq(bool(results[i]["finished"]), i < survivors.size())


func test_a_single_fish_is_never_snapped() -> void:
	var race: Race = _make_race(1)
	watch_signals(race)
	_run_until_snap(race)
	assert_signal_not_emitted(race, "fish_snapped")
	assert_false(race.get_marbles()[0].snapped)


func test_no_snap_without_the_event() -> void:
	var race: Race = _make_race(6, 5, RaceEvent.NOTHING)
	watch_signals(race)
	_run_until_snap(race)
	assert_signal_not_emitted(race, "fish_snapped")


func test_the_same_seed_snaps_the_same_fish() -> void:
	var picks: Array = []
	for round: int in 2:
		var race: Race = _make_race(8, 11)
		_run_until_snap(race)
		var ids: Array[int] = []
		for marble: Marble in race.get_marbles():
			if marble.snapped:
				ids.append(marble.id)
		ids.sort()
		picks.append(ids)
	assert_eq(picks[0], picks[1])


func test_snap_count_rounds_down_and_needs_two_fish() -> void:
	assert_eq(RaceEvent.snap_count(0), 0)
	assert_eq(RaceEvent.snap_count(1), 0)
	assert_eq(RaceEvent.snap_count(2), 1)
	assert_eq(RaceEvent.snap_count(5), 2)
