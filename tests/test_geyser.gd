extends GutTest
## The timed geysers of the Volcanic Vents map.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _vents() -> Track:
	var track: Track = TrackCatalog.instantiate("vents")
	add_child_autofree(track)
	return track


## The phase of every vent once a second for `seconds`, as one flat array.
func _timeline(track: Track, seconds: int) -> Array[int]:
	var result: Array[int] = []
	for geyser: Geyser in track.get_geysers():
		for t: int in seconds:
			result.append(geyser.phase_at(float(t)))
	return result


func test_vents_map_has_geysers_and_still_one_hazard() -> void:
	var track: Track = _vents()
	assert_gte(track.get_geysers().size(), 4)
	assert_eq(track.get_hazards().size(), 1)


func test_other_maps_have_no_geysers() -> void:
	for id: String in ["zigzag", "pachinko", "wreck"]:
		var track: Track = TrackCatalog.instantiate(id)
		add_child_autofree(track)
		assert_eq(track.get_geysers().size(), 0, id)


func test_unarmed_geysers_stay_quiet() -> void:
	var track: Track = _vents()
	for geyser: Geyser in track.get_geysers():
		assert_false(geyser.is_armed())
		for t: int in 30:
			assert_eq(geyser.phase_at(float(t)), Geyser.Phase.QUIET)


func test_same_seed_replays_the_same_eruptions() -> void:
	var first: Track = _vents()
	var second: Track = _vents()
	first.arm_gimmicks(7)
	second.arm_gimmicks(7)
	assert_eq(_timeline(first, 60), _timeline(second, 60))
	for i: int in first.get_geysers().size():
		assert_eq(first.get_geysers()[i].get_cycle(), second.get_geysers()[i].get_cycle())


func test_different_seeds_time_the_vents_differently() -> void:
	var first: Track = _vents()
	var second: Track = _vents()
	first.arm_gimmicks(1)
	second.arm_gimmicks(2)
	assert_ne(_timeline(first, 60), _timeline(second, 60))


func test_vents_do_not_all_erupt_together() -> void:
	var track: Track = _vents()
	track.arm_gimmicks(5)
	var offsets: Dictionary = {}
	for geyser: Geyser in track.get_geysers():
		var pattern: Array[int] = []
		for t: int in 20:
			pattern.append(geyser.phase_at(float(t)))
		offsets[pattern] = true
	assert_gt(offsets.size(), 1)


func test_each_cycle_warns_before_it_erupts() -> void:
	var track: Track = _vents()
	track.arm_gimmicks(3)
	for geyser: Geyser in track.get_geysers():
		var previous: int = geyser.phase_at(0.0)
		var t: float = 0.0
		var eruptions: int = 0
		while t < 60.0:
			t += STEP
			var phase: int = geyser.phase_at(t)
			if phase == Geyser.Phase.ERUPT and previous != Geyser.Phase.ERUPT:
				eruptions += 1
				assert_eq(previous, Geyser.Phase.TELEGRAPH, "an eruption is announced")
			previous = phase
		assert_gt(eruptions, 3, "erupts repeatedly")


func test_vents_erupt_whatever_the_hazard_setting() -> void:
	var track: Track = _vents()
	track.arm_hazards(_rng(1), 0)
	track.arm_gimmicks(1)
	assert_false(track.get_hazards()[0].is_armed())
	for geyser: Geyser in track.get_geysers():
		assert_true(geyser.is_armed())


func test_stopping_the_gimmicks_quiets_the_vents() -> void:
	var track: Track = _vents()
	track.arm_gimmicks(1)
	track.stop_gimmicks()
	for geyser: Geyser in track.get_geysers():
		assert_false(geyser.is_armed())
		assert_false(geyser.is_erupting())


func test_race_start_arms_the_vents_and_clear_stops_them() -> void:
	var track: Track = _vents()
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(race)
	race.start(track, 2, _rng(4), 0)
	for geyser: Geyser in track.get_geysers():
		assert_true(geyser.is_armed())
	race.clear()
	for geyser: Geyser in track.get_geysers():
		assert_false(geyser.is_armed())


func test_eruption_throws_a_marble_along_the_vent() -> void:
	var track: Track = _vents()
	var geyser: Geyser = track.get_geysers()[0]
	geyser.arm(3)
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = geyser.global_position + geyser.get_direction() * 40.0
	# The column only reports the marble after a physics frame.
	await wait_physics_frames(3)
	var spent: float = 0.0
	while not geyser.is_erupting() and spent < 30.0:
		geyser.tick(STEP)
		spent += STEP
	assert_true(geyser.is_erupting())
	marble.linear_velocity = Vector2.ZERO
	# Physics frames tick the geyser as well, so the eruption may end: the push only
	# has to have started.
	await wait_physics_frames(15)
	assert_gt(marble.linear_velocity.dot(geyser.get_direction()), 0.0, "thrown along the vent")
