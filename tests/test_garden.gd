extends GutTest
## Coral Garden: coral grows shut over the openings in the lanes behind the fish that pass.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _coral: CoralHazard


func before_each() -> void:
	_track = TrackCatalog.instantiate("garden")
	add_child_autofree(_track)
	_coral = _track.get_hazards()[0] as CoralHazard
	# A body only takes its transform inside physics frames.
	await wait_physics_frames(6)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _marble_at(pos: Vector2, gravity: float = 1.0) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = gravity
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


func _run(seconds: float) -> void:
	await wait_physics_frames(int(seconds / STEP))


## Ticks the coral by hand until bed `index` has stopped growing. Returns whether it did.
func _grow_shut(index: int) -> bool:
	var bed: CoralBed = _coral.get_beds()[index]
	bed.wake()
	var spent: float = 0.0
	while bed.stage != CoralBed.Stage.GROWN and spent < 20.0:
		_coral.tick(STEP)
		spent += STEP
	return bed.stage == CoralBed.Stage.GROWN


func test_the_garden_has_four_beds_all_asleep_with_the_lanes_open() -> void:
	assert_not_null(_coral)
	assert_eq(_coral.bed_count(), 4)
	assert_eq(_coral.closed_count(), 0)
	for bed: CoralBed in _coral.get_beds():
		assert_eq(bed.stage, CoralBed.Stage.DORMANT)
		assert_true(bed.is_open())


func test_the_coral_is_the_maps_hazard() -> void:
	assert_eq(_track.get_hazards().size(), 1)
	assert_true(_coral.is_scheduled())


func test_a_fish_in_the_trigger_wakes_its_bed_and_only_that_one() -> void:
	_coral.reseed(3)
	var bed: CoralBed = _coral.get_beds()[0]
	_marble_at(bed.get_node("Trigger").global_position, 0.0)
	await _run(0.2)
	assert_ne(bed.stage, CoralBed.Stage.DORMANT, "the bed wakes")
	for other: CoralBed in _coral.get_beds():
		if other != bed:
			assert_eq(other.stage, CoralBed.Stage.DORMANT)


func test_nothing_wakes_before_a_race_has_started() -> void:
	var bed: CoralBed = _coral.get_beds()[0]
	_marble_at(bed.get_node("Trigger").global_position, 0.0)
	await _run(0.5)
	assert_eq(bed.stage, CoralBed.Stage.DORMANT)


func test_a_woken_bed_glows_then_grows_and_stays_grown() -> void:
	_coral.reseed(3)
	var bed: CoralBed = _coral.get_beds()[0]
	assert_true(bed.wake())
	assert_false(bed.wake(), "a bed only wakes once")
	var saw_glow: bool = false
	var saw_growth: bool = false
	var spent: float = 0.0
	while bed.stage != CoralBed.Stage.GROWN and spent < 20.0:
		_coral.tick(STEP)
		spent += STEP
		saw_glow = saw_glow or (bed.stage == CoralBed.Stage.WARN and bed.glow > 0.2)
		saw_growth = saw_growth or (bed.stage == CoralBed.Stage.GROWING and bed.growth > 0.4)
	assert_true(saw_glow, "the polyps glow first")
	assert_true(saw_growth, "then the coral grows across")
	assert_eq(bed.growth, 1.0)
	assert_false(bed.is_open())
	for i: int in 200:
		_coral.tick(STEP)
	assert_eq(bed.growth, 1.0, "it never shrinks back")
	assert_eq(_coral.closed_count(), 1)


func test_the_same_seed_makes_the_beds_hesitate_the_same_way() -> void:
	_coral.reseed(9)
	var first: Array[float] = []
	for bed: CoralBed in _coral.get_beds():
		first.append(bed.hesitation)
	_coral.reseed(9)
	for i: int in first.size():
		assert_eq(_coral.get_beds()[i].hesitation, first[i])
	_coral.reseed(10)
	var differs: bool = false
	for i: int in first.size():
		differs = differs or _coral.get_beds()[i].hesitation != first[i]
	assert_true(differs, "another seed hesitates differently")


func test_stopping_the_gimmick_puts_every_bed_back_to_sleep() -> void:
	_coral.reseed(3)
	assert_true(_grow_shut(0))
	_coral.stop_gimmick()
	assert_eq(_coral.closed_count(), 0)
	for bed: CoralBed in _coral.get_beds():
		assert_eq(bed.stage, CoralBed.Stage.DORMANT)
		assert_eq(bed.growth, 0.0)


func test_growth_does_not_depend_on_the_hazard_setting() -> void:
	# Hazards off: the race arms nothing, yet a fish still wakes the coral.
	_track.seed_gimmicks(_rng(5))
	_track.arm_hazards(_rng(5), 0)
	assert_false(_coral.is_armed())
	var bed: CoralBed = _coral.get_beds()[0]
	_marble_at(bed.get_node("Trigger").global_position, 0.0)
	await _run(0.3)
	assert_ne(bed.stage, CoralBed.Stage.DORMANT)


func test_a_closed_opening_carries_a_fish_across_and_an_open_one_drops_it() -> void:
	_coral.reseed(3)
	assert_true(_grow_shut(0))
	await wait_physics_frames(3)
	var shut: CoralBed = _coral.get_beds()[0]
	var open: CoralBed = _coral.get_beds()[1]
	var over_shut: Marble = _marble_at(shut.gap_center() + Vector2(0.0, -40.0))
	var over_open: Marble = _marble_at(open.gap_center() + Vector2(0.0, -40.0))
	await _run(1.0)
	assert_lt(over_shut.global_position.y, shut.gap_center().y + 10.0, "the coral holds it up")
	assert_gt(over_open.global_position.y, open.gap_center().y + 60.0, "the open gap drops it")


func test_the_plug_slides_in_from_the_upstream_side() -> void:
	_coral.reseed(3)
	var bed: CoralBed = _coral.get_beds()[0]
	var plug: AnimatableBody2D = bed.get_node("Plug") as AnimatableBody2D
	var rest: Vector2 = plug.position
	assert_true(_grow_shut(0))
	await wait_physics_frames(3)
	var moved: Vector2 = plug.position - rest
	assert_gt(moved.length(), bed.gap_width, "it crosses the opening")
	assert_eq(signf(moved.x), float(bed.flow), "along the way the fish roll")
	for other: CoralBed in _coral.get_beds():
		if other != bed:
			assert_eq((other.get_node("Plug") as Node2D).position, Vector2.ZERO)


func test_an_overgrowth_event_closes_a_sleeping_bed_without_any_fish() -> void:
	_coral.arm(4, 5)
	assert_true(_coral.is_armed())
	_coral.clock = _coral.get_schedule()[0] - 0.1
	var glowed: bool = false
	var spent: float = 0.0
	while _coral.closed_count() == 0 and spent < 20.0:
		_coral.tick(STEP)
		spent += STEP
		for bed: CoralBed in _coral.get_beds():
			glowed = glowed or bed.glow > 0.3
	assert_eq(_coral.closed_count(), 1)
	assert_true(glowed, "the bed warns before it closes")


func test_an_overgrowth_event_leaves_grown_beds_alone_and_picks_a_sleeping_one() -> void:
	_coral.reseed(3)
	assert_true(_grow_shut(0))
	_coral.arm(4, 5)
	_coral.clock = _coral.get_schedule()[0] - 0.1
	var spent: float = 0.0
	while _coral.closed_count() < 2 and spent < 20.0:
		_coral.tick(STEP)
		spent += STEP
	assert_eq(_coral.closed_count(), 2)
	assert_false(_coral.get_beds()[0].is_open())


func test_disarming_keeps_what_has_grown() -> void:
	_coral.reseed(3)
	_coral.arm(4, 5)
	assert_true(_grow_shut(1))
	_coral.disarm()
	assert_false(_coral.get_beds()[1].is_open())


func test_events_are_planned_from_the_seed() -> void:
	_coral.arm(4, 5)
	var a: Array[float] = _coral.get_schedule()
	_coral.arm(4, 5)
	assert_eq(_coral.get_schedule(), a)
	assert_gt(a.size(), 0)


func test_the_hazard_setting_zero_arms_no_events() -> void:
	_track.arm_hazards(_rng(5), 0)
	assert_false(_coral.is_armed())


func test_every_lane_keeps_an_open_end_so_the_field_always_gets_down() -> void:
	# Close every bed, then let a field race: all of them must still reach the finish.
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(race)
	race.start(_track, 6, _rng(21), 0)
	for bed: CoralBed in _coral.get_beds():
		bed.grow_now()
	var finished: Array[int] = []
	_track.marble_reached_finish.connect(func(m: Node2D) -> void: finished.append((m as Marble).id))
	var spent: float = 0.0
	while finished.size() < 6 and spent < 80.0:
		await wait_physics_frames(60)
		spent += 1.0
	assert_eq(_coral.closed_count(), 4)
	assert_eq(finished.size(), 6, "every fish reaches the finish with all four beds shut")
