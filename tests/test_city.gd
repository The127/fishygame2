extends GutTest
## Sunken City: ruined towers come down when the fish arrive. The first two ruins' floor patches
## crumble away and open shortcuts, the next two slabs drop and seal the shortcuts that started
## open, and the last five towers just topple onto the lane.

const STEP: float = 1.0 / 60.0
## Ruins whose floor patch crumbles (their gap starts shut), then the ones that seal a gap.
const OPENING: Array[int] = [0, 1]
const SEALING: Array[int] = [2, 3]
const TOPPLING: Array[int] = [4, 5, 6, 7, 8]

var _track: Track
var _hazard: RuinHazard


func before_each() -> void:
	_track = TrackCatalog.instantiate("city")
	add_child_autofree(_track)
	_hazard = _track.get_hazards()[0] as RuinHazard


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _arm(seed_value: int = 3, frequency: int = 5) -> void:
	_hazard.arm(seed_value, frequency)


## Steps until ruin `index` has come down. Returns whether it did.
func _bring_down(index: int) -> bool:
	_hazard.trigger(index)
	var spent: float = 0.0
	while _hazard.stage_of(index) != RuinHazard.Stage.FALLEN and spent < 20.0:
		_hazard.tick(STEP)
		spent += STEP
	return _hazard.stage_of(index) == RuinHazard.Stage.FALLEN


func _bring_down_all() -> void:
	for i: int in _hazard.ruin_count():
		_bring_down(i)


func _live_set() -> Array[bool]:
	var live: Array[bool] = []
	for i: int in _hazard.ruin_count():
		live.append(_hazard.is_live(i))
	return live


func test_the_city_has_nine_ruins_and_none_has_fallen() -> void:
	assert_not_null(_hazard)
	assert_eq(_hazard.ruin_count(), 9)
	assert_eq(_hazard.fallen_count(), 0)


func test_before_any_collapse_the_floor_patches_hold_and_the_sealable_gaps_are_open() -> void:
	for i: int in OPENING:
		assert_false(_hazard.is_gap_open(i), "gap %d starts shut" % i)
	for i: int in SEALING:
		assert_true(_hazard.is_gap_open(i), "gap %d starts open" % i)


func test_with_hazards_off_nothing_collapses() -> void:
	_track.arm_hazards(_rng(1), 0)
	assert_false(_hazard.is_armed())
	for i: int in _hazard.ruin_count():
		assert_false(_hazard.trigger(i), "ruin %d cannot be set off" % i)
	for i: int in 600:
		_hazard.tick(STEP)
	assert_eq(_hazard.fallen_count(), 0)


func test_nothing_falls_until_a_fish_arrives() -> void:
	_arm()
	for i: int in 3600:
		_hazard.tick(STEP)
	assert_eq(_hazard.fallen_count(), 0, "a minute without fish brings nothing down")
	assert_eq(_hazard.phase, Hazard.Phase.IDLE)


func test_a_ruin_goes_through_telegraph_and_topple_before_it_is_down() -> void:
	watch_signals(_hazard)
	_arm()
	assert_true(_hazard.trigger(0))
	assert_eq(_hazard.stage_of(0), RuinHazard.Stage.TELEGRAPH)
	assert_signal_emitted(_hazard, "telegraph_started")
	assert_signal_not_emitted(_hazard, "active_started")
	var stages: Dictionary = {}
	for i: int in 600:
		_hazard.tick(STEP)
		stages[_hazard.stage_of(0)] = true
	assert_true(stages.has(RuinHazard.Stage.TOPPLE))
	assert_signal_emitted(_hazard, "active_started")
	assert_eq(_hazard.stage_of(0), RuinHazard.Stage.FALLEN)
	assert_eq(_hazard.phase, Hazard.Phase.IDLE)


func test_each_ruin_brings_down_exactly_one_more_tower() -> void:
	_arm()
	for index: int in _hazard.ruin_count():
		assert_true(_bring_down(index))
		assert_eq(_hazard.fallen_count(), index + 1)


func test_ruins_run_on_their_own_and_several_can_be_going_down_at_once() -> void:
	_arm()
	assert_true(_hazard.trigger(1))
	for i: int in 60:
		_hazard.tick(STEP)
	assert_true(_hazard.trigger(6))
	for i: int in 600:
		_hazard.tick(STEP)
	assert_eq(_hazard.fallen_count(), 2)
	assert_eq(_hazard.stage_of(0), RuinHazard.Stage.STANDING, "the others still stand")


func test_a_ruin_only_falls_once_per_race() -> void:
	_arm()
	assert_true(_bring_down(2))
	assert_false(_hazard.trigger(2), "it is down already")
	assert_eq(_hazard.fallen_count(), 1)


func test_when_every_ruin_is_down_the_opening_gaps_are_open_and_the_sealing_ones_shut() -> void:
	_arm()
	_bring_down_all()
	for i: int in OPENING:
		assert_true(_hazard.is_gap_open(i), "gap %d is a shortcut now" % i)
	for i: int in SEALING:
		assert_false(_hazard.is_gap_open(i), "gap %d is sealed now" % i)
	for i: int in TOPPLING:
		assert_false(_hazard.is_gap_open(i), "a toppled tower leaves no gap")


func test_the_same_seed_makes_the_same_ruins_live() -> void:
	_arm(9, 2)
	var first: Array[bool] = _live_set()
	_hazard.disarm()
	_arm(9, 2)
	assert_eq(_live_set(), first)


func test_which_ruins_are_live_depends_on_the_seed_and_the_hazard_level() -> void:
	var sets: Dictionary = {}
	for seed_value: int in range(1, 13):
		_hazard.disarm()
		_arm(seed_value, 2)
		sets[str(_live_set())] = true
	assert_gt(sets.size(), 1, "twelve seeds give more than one set of live ruins")
	var at_one: int = 0
	var at_five: int = 0
	for seed_value: int in range(1, 13):
		_hazard.disarm()
		_arm(seed_value, 1)
		at_one += _live_set().count(true)
		_hazard.disarm()
		_arm(seed_value, 5)
		at_five += _live_set().count(true)
	assert_lt(at_one, at_five, "a higher hazard level keeps more ruins live")
	assert_eq(at_five, 12 * _hazard.ruin_count(), "the top level keeps them all live")


func test_the_telegraph_shakes_and_glows_before_anything_changes() -> void:
	watch_signals(_hazard)
	_arm()
	_hazard.trigger(0)
	for i: int in 50:
		_hazard.tick(STEP)
	assert_eq(_hazard.stage_of(0), RuinHazard.Stage.TELEGRAPH)
	assert_eq(_hazard.phase, Hazard.Phase.TELEGRAPH)
	assert_eq(_hazard.fallen_count(), 0, "nothing has fallen yet")
	assert_signal_emitted(_hazard, "burst_played", "dust falls during the warning")
	var runes: CanvasItem = _hazard.get_ruins()[0].get_node("Tower/Runes") as CanvasItem
	assert_gt(runes.modulate.a, 0.4, "the runes of the doomed tower light up")
	assert_false(_hazard.is_gap_open(0), "the floor still holds")


func test_the_crash_throws_dust() -> void:
	watch_signals(_hazard)
	_arm()
	_bring_down(0)
	assert_gte(get_signal_emit_count(_hazard, "burst_played"), 3, "warning dust, then the crash")


func test_disarming_puts_the_towers_and_the_floor_back() -> void:
	_arm()
	_bring_down(0)
	_bring_down(5)
	assert_eq(_hazard.fallen_count(), 2)
	_hazard.disarm()
	assert_eq(_hazard.fallen_count(), 0)
	for i: int in OPENING:
		assert_false(_hazard.is_gap_open(i))
	for i: int in SEALING:
		assert_true(_hazard.is_gap_open(i))
	for child: Node in _hazard.get_ruins():
		var tower: Node2D = child.get_node("Tower") as Node2D
		assert_almost_eq(tower.rotation, 0.0, 0.0001)
		assert_almost_eq(tower.modulate.a, 1.0, 0.0001)


func test_a_fallen_tower_lies_along_the_lane() -> void:
	_arm()
	_bring_down_all()
	for child: Node in _hazard.get_ruins():
		var tower: Node2D = child.get_node("Tower") as Node2D
		assert_almost_eq(tower.rotation, deg_to_rad(float(child.get_meta("lie_degrees"))), 0.001)


func test_a_toppled_tower_leaves_rubble_that_does_not_block_the_lane() -> void:
	_arm()
	_bring_down(4)
	var slab: Node = _hazard.get_ruins()[4].get_node("Slab")
	assert_null(slab.get_node_or_null("Collider"), "a fish at rest cannot climb any step")
	assert_almost_eq((slab.get_node("Visual") as CanvasItem).modulate.a, 1.0, 0.001)
