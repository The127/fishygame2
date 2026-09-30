extends GutTest
## The acid pits of Inside the Whale: a fish that touches the acid dissolves into a skeleton and is
## out of the race, the hatch over each pit sinks and rises on its own cycle, and the race treats
## a dissolved fish like any other DNF.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _whale() -> Track:
	_track = TrackCatalog.instantiate("whale")
	add_child_autofree(_track)
	return _track


func _pit(track: Track, pit_name: String) -> AcidPit:
	return track.find_child(pit_name) as AcidPit


## A fish floating at `at` with gravity off, so only the pit acts on it.
func _fish(at: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = at
	return marble


func test_the_whale_has_two_acid_pits() -> void:
	var track: Track = _whale()
	assert_not_null(_pit(track, "AcidA"))
	assert_not_null(_pit(track, "AcidB"))


func test_a_fish_in_the_acid_dissolves_and_leaves_a_skeleton() -> void:
	var pit: AcidPit = _pit(_whale(), "AcidA")
	watch_signals(pit)
	var fish: Marble = _fish(pit.global_position)
	await wait_physics_frames(3)
	assert_true(fish.dissolved, "the fish dissolved")
	assert_true(fish.is_out(), "a dissolved fish is out for good")
	assert_true(fish.eaten, "the hazards leave it alone")
	assert_eq(fish.collision_layer, 0)
	assert_eq(pit.skeleton_count(), 1)
	assert_signal_emitted(pit, "fish_dissolved")
	assert_signal_emitted(pit, "burst_played")
	await get_tree().create_timer(Marble.DISSOLVE_SECONDS + 0.2).timeout
	assert_false(fish.visible, "the fish is gone once it has faded")


func test_a_fish_that_already_finished_is_left_alone() -> void:
	var pit: AcidPit = _pit(_whale(), "AcidA")
	var fish: Marble = _fish(pit.global_position)
	fish.has_finished = true
	await wait_physics_frames(3)
	assert_false(fish.dissolved)
	assert_eq(pit.skeleton_count(), 0)


func test_a_fish_above_the_acid_is_left_alone() -> void:
	var pit: AcidPit = _pit(_whale(), "AcidA")
	var fish: Marble = _fish(pit.global_position + Vector2(0.0, -120.0))
	await wait_physics_frames(3)
	assert_false(fish.dissolved)


func test_a_pit_keeps_only_its_newest_skeletons() -> void:
	var pit: AcidPit = _pit(_whale(), "AcidA")
	for i: int in AcidPit.MAX_SKELETONS + 2:
		var fish: Marble = _fish(pit.global_position + Vector2(0.0, float(i)))
		await wait_physics_frames(2)
		assert_true(fish.dissolved)
	assert_eq(pit.skeleton_count(), AcidPit.MAX_SKELETONS)


func test_stopping_the_gimmicks_cleans_the_pit() -> void:
	var track: Track = _whale()
	var pit: AcidPit = _pit(track, "AcidA")
	_fish(pit.global_position)
	await wait_physics_frames(3)
	assert_eq(pit.skeleton_count(), 1)
	track.stop_gimmicks()
	assert_eq(pit.skeleton_count(), 0)


func test_the_hatch_sinks_and_rises() -> void:
	var pit: AcidPit = _pit(_whale(), "AcidA")
	pit.reseed(1)
	var low: float = INF
	var high: float = -INF
	for i: int in 800:
		var open: float = pit.openness_at(float(i) * 0.01)
		low = minf(low, open)
		high = maxf(high, open)
	assert_eq(low, 0.0, "the hatch is shut part of the time")
	assert_eq(high, 1.0, "and fully open part of the time")


func test_the_hatch_is_open_only_a_fraction_of_the_time() -> void:
	var pit: AcidPit = _pit(_whale(), "AcidA")
	pit.reseed(2)
	var open_steps: int = 0
	var steps: int = 2000
	for i: int in steps:
		if pit.openness_at(float(i) * 0.01) > 0.0:
			open_steps += 1
	var share: float = float(open_steps) / float(steps)
	assert_gt(share, 0.05)
	assert_lt(share, 0.35, "most of the time a fish can cross")


func test_the_hatch_glows_before_it_opens() -> void:
	var pit: AcidPit = _pit(_whale(), "AcidA")
	pit.reseed(3)
	var warned: bool = false
	for i: int in 1000:
		var t: float = float(i) * 0.01
		if pit.warning_at(t) > 0.5:
			warned = true
			assert_eq(pit.openness_at(t), 0.0, "the warning comes while it is still shut")
	assert_true(warned)


func test_a_seed_always_starts_the_hatch_at_the_same_point() -> void:
	var pit: AcidPit = _pit(_whale(), "AcidA")
	pit.reseed(7)
	var expected: float = pit.openness_at(2.3)
	var expected_warning: float = pit.warning_at(2.3)
	pit.reseed(9)
	var moved: bool = false
	for i: int in 100:
		moved = moved or pit.openness_at(float(i) * 0.1) != expected
	assert_true(moved)
	pit.reseed(7)
	assert_eq(pit.openness_at(2.3), expected)
	assert_eq(pit.warning_at(2.3), expected_warning)


func test_the_open_hatch_leaves_the_pit_uncovered() -> void:
	var pit: AcidPit = _pit(_whale(), "AcidA")
	var lid: AnimatableBody2D = pit.get_node("Lid") as AnimatableBody2D
	pit.reseed(1)
	var deepest: float = 0.0
	for i: int in int(pit.period / STEP) + 30:
		await wait_physics_frames(1)
		deepest = maxf(deepest, lid.position.y)
	assert_almost_eq(deepest, pit.drop, 0.5, "the hatch sinks by its full depth")


func test_the_pit_follows_the_replay_state() -> void:
	var pit: AcidPit = _pit(_whale(), "AcidA")
	_fish(pit.global_position)
	await wait_physics_frames(3)
	var from: PackedFloat32Array = pit.replay_state()
	pit.stop_gimmick()
	assert_eq(pit.skeleton_count(), 0)
	pit.replay_apply(from, from, 0.0)
	assert_eq(pit.skeleton_count(), 1, "the skeleton comes back with the state")
	assert_eq(pit.replay_state().size(), from.size(), "the state always has the same length")


func _start_race(count: int) -> Race:
	_track = TrackCatalog.instantiate("whale")
	add_child_autofree(_track)
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(race)
	race.start(_track, count, _rng(5), 0)
	await wait_physics_frames(1)
	return race


func test_a_dissolved_fish_is_a_dnf_and_the_race_still_ends() -> void:
	var race: Race = await _start_race(2)
	watch_signals(race)
	var marbles: Array[Marble] = race.get_marbles()
	var pit: AcidPit = _pit(_track, "AcidA")
	PhysicsServer2D.body_set_state(
		marbles[1].get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(0.0, pit.global_position)
	)
	await wait_physics_frames(3)
	assert_true(race.is_dissolved(1))
	assert_signal_emitted_with_parameters(race, "fish_dissolved", [1])
	assert_true(race.running, "one fish is still racing")
	_track.marble_reached_finish.emit(marbles[0])
	assert_false(race.running, "the race ends once the last swimmer finished")
	var results: Array[Dictionary] = []
	results.assign(get_signal_parameters(race, "race_finished", 0)[0])
	assert_eq(int(results[0]["id"]), 0)
	assert_true(bool(results[0]["finished"]))
	assert_eq(int(results[1]["id"]), 1)
	assert_false(bool(results[1]["finished"]), "the dissolved fish did not finish")


func test_the_race_ends_when_every_fish_dissolved() -> void:
	var race: Race = await _start_race(1)
	var pit: AcidPit = _pit(_track, "AcidA")
	PhysicsServer2D.body_set_state(
		race.get_marbles()[0].get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(0.0, pit.global_position)
	)
	await wait_physics_frames(3)
	assert_false(race.running, "nobody is left to race")
