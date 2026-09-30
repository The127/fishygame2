extends GutTest
## Sunken City: ruined towers come down one by one. The first two ruins' floor patches crumble
## away and open shortcuts, the last two ruins' slabs drop and seal the shortcuts that started
## open.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0
## Ruins whose floor patch crumbles (their gap starts shut), then the ones that seal a gap.
const OPENING: Array[int] = [0, 1]
const SEALING: Array[int] = [2, 3]

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


## Steps until the next event is over. Returns whether one ran.
func _run_one_event() -> bool:
	var spent: float = 0.0
	while _hazard.phase == Hazard.Phase.IDLE and spent < 100.0:
		_hazard.tick(STEP)
		spent += STEP
	while _hazard.phase != Hazard.Phase.IDLE and spent < 100.0:
		_hazard.tick(STEP)
		spent += STEP
	return spent < 100.0


func _gaps() -> Array[bool]:
	var gaps: Array[bool] = []
	for i: int in _hazard.ruin_count():
		gaps.append(_hazard.is_gap_open(i))
	return gaps


## Runs every planned event and returns the ruins in the order they came down.
func _collapse_order() -> Array[int]:
	var order: Array[int] = []
	var before: Array[bool] = _gaps()
	while _run_one_event():
		var after: Array[bool] = _gaps()
		for i: int in after.size():
			if after[i] != before[i]:
				order.append(i)
		before = after
		if _hazard.fallen_count() == _hazard.ruin_count():
			break
	return order


func _marble_at(pos: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


## Drops a fish `height` above the gap of ruin `index` and returns how far below the lane it got.
func _drop_fish_over(index: int, height: float = 60.0) -> float:
	# Let the slabs take their poses in the physics server first.
	for i: int in 2:
		await get_tree().physics_frame
	var ruin: Node2D = _hazard.get_ruins()[index]
	var marble: Marble = _marble_at(ruin.global_position + Vector2(0.0, -height))
	for i: int in 100:
		await get_tree().physics_frame
	return marble.global_position.y - ruin.global_position.y


func test_the_city_has_a_ruin_hazard_with_four_ruins() -> void:
	assert_not_null(_hazard)
	assert_eq(_hazard.ruin_count(), 4)
	assert_eq(_hazard.fallen_count(), 0)


func test_before_any_collapse_the_floor_patches_hold_and_the_sealable_gaps_are_open() -> void:
	for i: int in OPENING:
		assert_false(_hazard.is_gap_open(i), "gap %d starts shut" % i)
	for i: int in SEALING:
		assert_true(_hazard.is_gap_open(i), "gap %d starts open" % i)


func test_with_hazards_off_nothing_collapses() -> void:
	_track.arm_hazards(_rng(1), 0)
	for i: int in 600:
		_hazard.tick(STEP)
	assert_eq(_hazard.fallen_count(), 0)
	assert_false(_hazard.is_armed())


func test_each_event_brings_down_exactly_one_more_ruin() -> void:
	_arm()
	for expected: int in range(1, 5):
		assert_true(_run_one_event())
		assert_eq(_hazard.fallen_count(), expected)


func test_when_every_ruin_is_down_the_opening_gaps_are_open_and_the_sealing_ones_shut() -> void:
	_arm()
	for i: int in 4:
		_run_one_event()
	for i: int in OPENING:
		assert_true(_hazard.is_gap_open(i), "gap %d is a shortcut now" % i)
	for i: int in SEALING:
		assert_false(_hazard.is_gap_open(i), "gap %d is sealed now" % i)


func test_a_ruin_only_falls_once_per_race() -> void:
	_arm()
	var order: Array[int] = _collapse_order()
	var seen: Dictionary = {}
	for i: int in order:
		assert_false(seen.has(i), "ruin %d fell twice" % i)
		seen[i] = true
	assert_eq(order.size(), 4)


func test_the_same_seed_brings_the_ruins_down_in_the_same_order() -> void:
	_arm(9)
	var first: Array[int] = _collapse_order()
	var other: Track = TrackCatalog.instantiate("city")
	add_child_autofree(other)
	_track = other
	_hazard = other.get_hazards()[0] as RuinHazard
	_arm(9)
	assert_eq(_collapse_order(), first)


func test_the_order_depends_on_the_seed() -> void:
	var orders: Dictionary = {}
	for seed_value: int in range(1, 9):
		_hazard.disarm()
		_arm(seed_value)
		orders[str(_collapse_order())] = true
	assert_gt(orders.size(), 1, "eight seeds give more than one order")


func test_the_telegraph_shakes_and_glows_before_anything_changes() -> void:
	watch_signals(_hazard)
	_arm()
	var spent: float = 0.0
	while _hazard.phase != Hazard.Phase.TELEGRAPH and spent < 100.0:
		_hazard.tick(STEP)
		spent += STEP
	for i: int in 70:
		_hazard.tick(STEP)
	assert_eq(_hazard.phase, Hazard.Phase.TELEGRAPH)
	assert_eq(_hazard.fallen_count(), 0, "nothing has fallen yet")
	assert_signal_emitted(_hazard, "burst_played", "dust falls during the warning")
	var glowing: bool = false
	for child: Node in _hazard.get_ruins():
		var runes: CanvasItem = child.get_node("Tower/Runes") as CanvasItem
		glowing = glowing or runes.modulate.a > 0.5
	assert_true(glowing, "the runes of the doomed tower light up")


func test_the_crash_throws_dust() -> void:
	watch_signals(_hazard)
	_arm()
	_run_one_event()
	assert_gte(get_signal_emit_count(_hazard, "burst_played"), 3, "warning dust, then the crash")


func test_disarming_puts_the_towers_and_the_floor_back() -> void:
	_arm()
	_run_one_event()
	_run_one_event()
	assert_eq(_hazard.fallen_count(), 2)
	_hazard.disarm()
	assert_eq(_hazard.fallen_count(), 0)
	for i: int in OPENING:
		assert_false(_hazard.is_gap_open(i))
	for i: int in SEALING:
		assert_true(_hazard.is_gap_open(i))
	for child: Node in _hazard.get_ruins():
		assert_almost_eq((child.get_node("Tower") as Node2D).rotation, 0.0, 0.0001)


func test_a_fallen_tower_lies_along_the_lane() -> void:
	_arm()
	_run_one_event()
	for child: Node in _hazard.get_ruins():
		var tower: Node2D = child.get_node("Tower") as Node2D
		if absf(tower.rotation) > 0.01:
			assert_almost_eq(
				tower.rotation, deg_to_rad(float(child.get_meta("lie_degrees"))), 0.001
			)


func test_fish_stay_on_a_floor_patch_and_fall_through_an_open_gap() -> void:
	# Before any collapse: the first gaps are covered, the last ones are open.
	var on_patch: float = await _drop_fish_over(0)
	assert_lt(on_patch, 45.0, "a fish stays on the floor patch")
	# The slab hangs 175 px above the gap, so the fish starts under it.
	var through: float = await _drop_fish_over(2, 100.0)
	assert_gt(through, 100.0, "a fish falls through an open gap")


func test_after_the_collapses_the_shortcuts_work_and_the_sealed_gaps_hold() -> void:
	_arm()
	for i: int in 4:
		_run_one_event()
	# Let the deferred collider changes and the moved slabs reach the physics server.
	for i: int in 3:
		await get_tree().physics_frame
	var shortcut: float = await _drop_fish_over(0)
	assert_gt(shortcut, 100.0, "a fish falls through the gap the floor patch left")
	var sealed: float = await _drop_fish_over(2)
	assert_lt(sealed, 45.0, "a fish stays on the slab that sealed the gap")


func test_a_cut_short_event_leaves_every_floor_patch_solid() -> void:
	_arm()
	var spent: float = 0.0
	while _hazard.phase != Hazard.Phase.TELEGRAPH and spent < 100.0:
		_hazard.tick(STEP)
		spent += STEP
	# Cut the event short and start over, all in one frame, like the next race starting.
	_hazard.disarm()
	_arm()
	for i: int in 3:
		await get_tree().physics_frame
	for ruin: Node2D in _hazard.get_ruins():
		var collider: CollisionPolygon2D = ruin.get_node("Slab/Collider") as CollisionPolygon2D
		assert_false(collider.disabled, "every slab collides again")
