extends GutTest
## Riptide Rounds: the loop, the current, the cuts after each lap and the ghosts' eddies.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _race: Race
var _cuts: Array[Array] = []


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _start(count: int, seed_value: int = 3, hazards: int = 0) -> void:
	_track = TrackCatalog.instantiate("riptide")
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	_race.treasures_enabled = false
	add_child_autofree(_race)
	_cuts.clear()
	_race.round_cut.connect(
		func(round_number: int, ids: Array[int]) -> void: _cuts.append([round_number, ids])
	)
	_race.start(_track, count, _rng(seed_value), hazards)


func _run_seconds(seconds: float) -> void:
	for i: int in int(seconds / STEP):
		await get_tree().physics_frame


## Runs until `condition` holds or `limit` seconds pass. Returns whether it held.
func _run_until(condition: Callable, limit: float = 80.0) -> bool:
	var frames: int = 0
	while not condition.call() and frames < int(limit / STEP):
		await get_tree().physics_frame
		frames += 1
	return condition.call()


func _cut_ids() -> Array[int]:
	var ids: Array[int] = []
	for marble: Marble in _race.get_marbles():
		if marble.eliminated:
			ids.append(marble.id)
	ids.sort()
	return ids


func _alive_ids() -> Array[int]:
	var ids: Array[int] = []
	for marble: Marble in _race.get_marbles():
		if not marble.is_out() and not marble.has_finished:
			ids.append(marble.id)
	return ids


func test_the_map_is_a_three_lap_loop_seen_whole() -> void:
	_track = TrackCatalog.instantiate("riptide")
	add_child_autofree(_track)
	assert_eq(_track.laps, 3)
	assert_true(_track.has_rounds())
	assert_false(_track.follow_camera)
	assert_true(_track.has_eddies())
	var curve: Curve2D = (_track.get_node("Centerline") as Path2D).curve
	assert_eq(curve.get_point_position(0), curve.get_point_position(curve.point_count - 1))
	assert_gt(curve.get_baked_length(), 3500.0)


func test_other_maps_are_one_lap_with_no_rounds() -> void:
	for id: String in TrackCatalog.ids():
		if id == "riptide":
			continue
		var track: Track = TrackCatalog.instantiate(id)
		add_child_autofree(track)
		assert_eq(track.laps, 1, id)
		assert_false(track.has_rounds(), id)
		assert_true(track.follow_camera, id)
		assert_false(track.has_eddies(), id)


func test_progress_wraps_at_the_lap_line_and_the_finish_is_not_used() -> void:
	_track = TrackCatalog.instantiate("riptide")
	add_child_autofree(_track)
	var finish: Area2D = _track.get_node("Finish") as Area2D
	assert_false(finish.monitoring, "the lap line finishes nobody")
	var before: float = _track.get_progress(_track.lane_point(0.97))
	var after: float = _track.get_progress(_track.lane_point(0.02))
	assert_gt(before, 0.9)
	assert_lt(after, 0.1)


func test_there_is_no_gravity_and_the_current_carries_fish_round() -> void:
	_start(4)
	var before: Dictionary = {}
	for marble: Marble in _race.get_marbles():
		before[marble.id] = _track.get_progress(marble.global_position)
	await _run_seconds(3.0)
	for marble: Marble in _race.get_marbles():
		var moved: float = _track.get_progress(marble.global_position) - float(before[marble.id])
		assert_gt(moved, 0.1, "fish %d was carried along" % marble.id)
		assert_true(
			_track.view_bounds.has_point(marble.global_position),
			"fish %d stays in view" % marble.id
		)


func test_a_fish_against_the_wall_is_carried_slower_than_one_in_the_middle() -> void:
	_start(1)
	var current: RingCurrent = _track.find_child("Current", true, false) as RingCurrent
	var middle: float = current.water_speed(1000.0, 0.0, 0)
	var wall: float = current.water_speed(1000.0, 95.0, 0)
	assert_gt(middle, wall)
	assert_gt(wall, 0.0)


func test_each_fish_has_its_own_small_knack_with_the_water() -> void:
	_start(1)
	var current: RingCurrent = _track.find_child("Current", true, false) as RingCurrent
	var seen: Dictionary = {}
	for id: int in 20:
		var knack: float = current.knack(id)
		assert_lte(absf(knack), RingCurrent.KNACK_SIZE)
		seen[snappedf(knack, 0.001)] = true
	assert_gt(seen.size(), 10)


func test_the_slowest_third_is_cut_after_lap_one_and_two() -> void:
	_start(10)
	assert_true(await _run_until(func() -> bool: return _cuts.size() >= 2))
	assert_eq(_cuts[0][0], 1)
	assert_eq((_cuts[0][1] as Array).size(), 3)
	assert_eq(_cuts[1][0], 2)
	assert_eq((_cuts[1][1] as Array).size(), 2)
	assert_eq(_cut_ids().size(), 5)
	for marble: Marble in _race.get_marbles():
		assert_eq(marble.is_out(), marble.eliminated)
		assert_eq(marble.eliminated, _race.is_eliminated(marble.id))


func test_the_race_ends_with_the_survivors_finishing_and_the_cut_ranked_behind() -> void:
	_start(10)
	var box: Array = []
	_race.race_finished.connect(func(r: Array[Dictionary]) -> void: box.assign(r))
	assert_true(await _run_until(func() -> bool: return not _race.running, 90.0))
	var results: Array = box
	assert_eq(results.size(), 10)
	for place: int in 5:
		assert_true(results[place]["finished"], "place %d finished" % (place + 1))
	for place: int in range(5, 10):
		assert_false(results[place]["finished"], "place %d was cut" % (place + 1))
		assert_true(_race.is_eliminated(int(results[place]["id"])))
	# Fish cut after the second lap rank above those cut after the first.
	var second: Array = _cuts[1][1]
	for place: int in range(5, 7):
		assert_true(second.has(results[place]["id"]), "cut in round two ranks sixth and seventh")
	assert_lt(_race.elapsed, 60.0)


func test_two_fish_race_three_laps_with_no_cut() -> void:
	_start(2)
	var box: Array = []
	_race.race_finished.connect(func(r: Array[Dictionary]) -> void: box.assign(r))
	assert_true(await _run_until(func() -> bool: return not _race.running, 90.0))
	var results: Array = box
	assert_eq(_cuts.size(), 0)
	assert_true(results[0]["finished"])
	assert_true(results[1]["finished"])


func test_a_cut_fish_leaves_the_physics_and_waits_as_a_ghost_in_the_lagoon() -> void:
	_start(10)
	assert_true(await _run_until(func() -> bool: return _cuts.size() >= 1))
	var cut: Marble = null
	for marble: Marble in _race.get_marbles():
		if marble.eliminated:
			cut = marble
	assert_not_null(cut)
	assert_eq(cut.collision_layer, 0)
	assert_true(cut.freeze)
	assert_almost_eq(cut.modulate.a, Marble.GHOST_ALPHA, 0.01)
	await _run_seconds(EddyRing.DRAIN_SECONDS + 0.5)
	var ring: EddyRing = _track.find_child("Lagoon", true, false) as EddyRing
	var lagoon: Rect2 = ring.lagoon.grow(40.0)
	for marble: Marble in _race.get_marbles():
		if marble.eliminated:
			assert_true(
				lagoon.has_point(marble.global_position), "ghost %d is in the lagoon" % marble.id
			)
	assert_eq(ring.ghost_count(), _cut_ids().size())


func test_finished_fish_leave_the_course_too() -> void:
	_start(3, 5)
	var someone_done: Callable = func() -> bool:
		return _race.get_marbles().any(func(m: Marble) -> bool: return m.has_finished)
	var reached: bool = await _run_until(someone_done)
	assert_true(reached)
	await _run_seconds(0.2)
	for marble: Marble in _race.get_marbles():
		if marble.has_finished:
			assert_eq(marble.collision_layer, 0, "the winner no longer circles among the others")
			assert_false(marble.eliminated)


func test_only_a_cut_fish_can_send_an_eddy_and_only_a_few_at_once() -> void:
	_start(10)
	assert_eq(_race.eddy_blocker(0), "swimming")
	assert_true(await _run_until(func() -> bool: return _cuts.size() >= 1))
	var cut: Array[int] = _cut_ids()
	assert_eq(_race.eddy_blocker(_alive_ids()[0]), "swimming")
	await _run_seconds(EddyRing.DRAIN_SECONDS)
	assert_eq(_race.eddy_blocker(cut[0]), "")
	watch_signals(_race)
	assert_true(_race.drop_eddy(cut[0]))
	assert_signal_emitted(_race, "eddy_dropped")
	assert_eq(_race.eddy_blocker(cut[0]), "busy", "its ghost is out there")
	assert_false(_race.drop_eddy(cut[0]))
	assert_true(_race.drop_eddy(cut[1]))
	assert_true(_race.drop_eddy(cut[2]))
	assert_eq(_track.find_child("Lagoon", true, false).eddy_count(), 3)
	_race.clear()


func test_a_fourth_eddy_has_to_wait_for_room() -> void:
	_start(20)
	assert_true(await _run_until(func() -> bool: return _cuts.size() >= 1))
	await _run_seconds(EddyRing.DRAIN_SECONDS)
	var cut: Array[int] = _cut_ids()
	assert_gte(cut.size(), 4)
	for i: int in EddyRing.MAX_EDDIES:
		assert_true(_race.drop_eddy(cut[i]))
	assert_eq(_race.eddy_blocker(cut[3]), "full")
	assert_false(_race.drop_eddy(cut[3]))
	# After its spin the first ghost goes home and leaves room.
	await _run_seconds(EddyRing.FLIGHT_SECONDS + EddyRing.EDDY_SECONDS + 0.5)
	assert_eq(_race.eddy_blocker(cut[3]), "")


func test_an_eddy_lands_ahead_of_the_leader_on_the_lane() -> void:
	_start(10)
	assert_true(await _run_until(func() -> bool: return _cuts.size() >= 1))
	await _run_seconds(EddyRing.DRAIN_SECONDS)
	var cut: Array[int] = _cut_ids()
	assert_true(_race.drop_eddy(cut[0]))
	var ring: EddyRing = _track.find_child("Lagoon", true, false) as EddyRing
	var at: Vector2 = Vector2.ZERO
	for i: int in 3:
		if ring._eddy_ghost[i] != null:
			at = ring._eddy_pos[i]
	assert_ne(at, Vector2.ZERO)
	var lane: Vector2 = _track.lane_point(_track.get_progress(at))
	assert_lt(at.distance_to(lane), Race.EDDY_SIDE + 5.0, "the eddy lies in the channel")


func test_an_eddy_spins_fish_around_its_middle_and_ignores_nothing_else() -> void:
	_start(1)
	var ring: EddyRing = _track.find_child("Lagoon", true, false) as EddyRing
	var marble: Marble = _race.get_marbles()[0]
	marble.global_position = Vector2(1000.0, 700.0)
	marble.linear_velocity = Vector2.ZERO
	marble.sleeping = false
	ring._stir(marble, Vector2(960.0, 700.0), 1.0, 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Outward is +x, so spinning one way pushes the fish down the screen (+y).
	assert_gt(marble.linear_velocity.y, 10.0)
	assert_lt(marble.linear_velocity.x, 0.0, "and the pull is toward the middle")


func test_a_quiet_ghost_breaks_loose_on_its_own_during_the_hazard() -> void:
	_start(10, 3, 5)
	assert_true(await _run_until(func() -> bool: return _cuts.size() >= 1))
	var before: int = 0
	var seen: Array[int] = [0]
	_race.eddy_dropped.connect(func(_id: int) -> void: seen[0] += 1)
	# No chat at all: the map's hazard still sends ghosts out.
	assert_true(await _run_until(func() -> bool: return seen[0] >= 1 or not _race.running, 30.0))
	assert_gte(seen[0], before + 1)


func test_with_hazards_off_ghosts_stay_put_until_chat_sends_them() -> void:
	_start(10, 3, 0)
	var seen: Array[int] = [0]
	_race.eddy_dropped.connect(func(_id: int) -> void: seen[0] += 1)
	assert_true(await _run_until(func() -> bool: return _cuts.size() >= 2))
	assert_eq(seen[0], 0)


func test_clearing_the_race_empties_the_lagoon() -> void:
	_start(10)
	assert_true(await _run_until(func() -> bool: return _cuts.size() >= 1))
	_race.clear()
	var ring: EddyRing = _track.find_child("Lagoon", true, false) as EddyRing
	assert_eq(ring.ghost_count(), 0)
	assert_eq(ring.eddy_count(), 0)


func test_every_reason_the_race_gives_has_a_reply() -> void:
	for reason: String in [
		"closed", "no_fish", "no_rounds", "swimming", "busy", "full", "cooldown"
	]:
		assert_true(ChatReplies.HAUNT_REJECTIONS.has(reason), reason)


func test_other_maps_have_no_eddies_to_send() -> void:
	_track = TrackCatalog.instantiate("zigzag")
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 3, _rng(1), 0)
	assert_eq(_race.eddy_blocker(0), "no_rounds")
	assert_false(_race.drop_eddy(0))
