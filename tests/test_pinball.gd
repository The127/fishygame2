extends GutTest
## Pinball Reef: the table's flippers, bumpers and plunger, and the cooldowns, tally and
## automatic fires of the chat-driven flippers.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _table: PinballTable


func before_each() -> void:
	_track = TrackCatalog.instantiate("pinball")
	add_child_autofree(_track)
	_table = _track.get_node("PinballTable") as PinballTable
	# A body only takes its transform inside physics frames.
	await wait_physics_frames(3)


func _marble_at(pos: Vector2, gravity: float = 0.0) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = gravity
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


func _flipper(side: int) -> PinballFlipper:
	for flipper: PinballFlipper in _table.get_flippers():
		if flipper.side == side:
			return flipper
	return null


func _tick(seconds: float) -> void:
	for i: int in int(seconds / STEP):
		_table.tick(STEP)


func test_the_map_is_registered_with_flippers_and_bumpers() -> void:
	assert_true(TrackCatalog.has_map("pinball"))
	assert_eq(TrackCatalog.get_name_of("pinball"), "Pinball Reef")
	assert_not_null(_table)
	assert_eq(_table.get_flippers().size(), 6)
	assert_gte(_table.bumper_count(), 8)


func test_flippers_rest_pointing_toward_the_drain() -> void:
	for flipper: PinballFlipper in _table.get_flippers():
		assert_almost_eq(flipper.rotation, flipper.rest_angle(), 0.001)
		# Left blades point right and down, right blades left and down.
		var along: Vector2 = Vector2.from_angle(flipper.rotation)
		assert_eq(signf(along.x), float(-flipper.side))
		assert_gt(along.y, 0.0)


func test_a_fire_raises_the_blades_of_that_side_only() -> void:
	_table.reseed(1)
	assert_true(_table.fire(PinballTable.LEFT, "a"))
	var swing: Dictionary = {}
	for i: int in 15:
		await wait_physics_frames(1)
		for flipper: PinballFlipper in _table.get_flippers():
			var moved: float = absf(flipper.rotation - flipper.rest_angle())
			swing[flipper.side] = maxf(float(swing.get(flipper.side, 0.0)), moved)
	assert_gt(float(swing[PinballTable.LEFT]), 0.5, "the left blades swing up")
	assert_lt(float(swing[PinballTable.RIGHT]), 0.001, "the right blades stay at rest")


func test_blades_come_back_down_after_a_fire() -> void:
	_table.reseed(1)
	_table.fire(PinballTable.RIGHT, "a")
	var flipper: PinballFlipper = _flipper(PinballTable.RIGHT)
	await wait_physics_frames(10)
	assert_ne(flipper.rotation, flipper.rest_angle())
	await wait_physics_frames(90)
	assert_almost_eq(flipper.rotation, flipper.rest_angle(), 0.001)
	assert_false(flipper.raised)


func test_a_side_has_a_cooldown_but_every_press_counts() -> void:
	_table.reseed(1)
	assert_true(_table.fire(PinballTable.LEFT, "a"))
	assert_false(_table.fire(PinballTable.LEFT, "b"), "still cooling down")
	assert_true(_table.fire(PinballTable.RIGHT, "c"), "the other side is separate")
	assert_eq(_table.presses(PinballTable.LEFT), 2)
	assert_eq(_table.presses(PinballTable.RIGHT), 1)
	_tick(PinballTable.COOLDOWN + 0.1)
	assert_true(_table.fire(PinballTable.LEFT, "a"))


func test_nothing_fires_before_the_race_arms_the_table() -> void:
	assert_false(_table.is_armed())
	assert_false(_table.fire(PinballTable.LEFT, "a"))
	assert_eq(_table.presses(PinballTable.LEFT), 0)


func test_the_tally_lists_counts_and_the_latest_viewers() -> void:
	var texts: Array[String] = []
	_track.flipper_tally_changed.connect(func(text: String) -> void: texts.append(text))
	_table.reseed(1)
	assert_eq(texts[-1], "FLIPPERS   #left 0   #right 0")
	_table.fire(PinballTable.LEFT, "ann")
	_table.fire(PinballTable.RIGHT, "bob")
	_table.fire(PinballTable.LEFT, "cy")
	_table.fire(PinballTable.LEFT, "dee")
	_table.fire(PinballTable.LEFT, "bob")
	assert_eq(texts[-1], "FLIPPERS   #left 4   #right 1\ncy, dee, bob")
	_track.stop_gimmicks()
	assert_eq(texts[-1], "", "the tally is hidden when the race is cleared")
	assert_false(_table.is_armed())


func test_the_automatic_fires_come_from_the_seed() -> void:
	_table.reseed(7)
	var first: PackedFloat32Array = _table.get_schedule(PinballTable.LEFT).duplicate()
	var right: PackedFloat32Array = _table.get_schedule(PinballTable.RIGHT).duplicate()
	_table.reseed(7)
	assert_eq(_table.get_schedule(PinballTable.LEFT), first)
	assert_eq(_table.get_schedule(PinballTable.RIGHT), right)
	_table.reseed(8)
	assert_ne(_table.get_schedule(PinballTable.LEFT), first)
	assert_gt(first.size(), 10)
	assert_gte(first[0], PinballTable.AUTO_FIRST_MIN)
	assert_lte(first[0], PinballTable.AUTO_FIRST_MAX)
	for i: int in range(1, first.size()):
		var gap: float = first[i] - first[i - 1]
		assert_gte(gap, PinballTable.AUTO_MIN - 0.001)
		assert_lte(gap, PinballTable.AUTO_MAX + 0.001)


func test_a_quiet_chat_still_gets_flipper_fires() -> void:
	_table.reseed(3)
	var seen: Dictionary = {}
	for step: int in int(20.0 / STEP):
		_table.tick(STEP)
		for flipper: PinballFlipper in _table.get_flippers():
			if flipper._lit > 0.9:
				seen[flipper.side] = true
	assert_true(seen.has(PinballTable.LEFT) and seen.has(PinballTable.RIGHT))
	assert_eq(_table.presses(PinballTable.LEFT), 0, "automatic fires are not viewer presses")


func test_automatic_fires_stay_out_of_the_way_of_a_busy_chat() -> void:
	_table.reseed(3)
	var first_left: float = _table.get_schedule(PinballTable.LEFT)[0]
	_tick(first_left - 0.5)
	_table.fire(PinballTable.RIGHT, "a")
	var left: PinballFlipper = _flipper(PinballTable.LEFT)
	_tick(1.0)
	assert_lt(left._lit, 0.01, "the planned fire was skipped after a chat press")


func test_a_fire_flings_a_fish_lying_on_the_blade() -> void:
	_table.reseed(1)
	var flipper: PinballFlipper = _flipper(PinballTable.LEFT)
	var marble: Marble = _marble_at(flipper.to_global(Vector2(flipper.length * 0.7, -24.0)))
	await wait_physics_frames(2)
	assert_gt(flipper.fire(), 0)
	await wait_physics_frames(2)
	assert_lt(marble.linear_velocity.y, -300.0, "the fish flies upward")
	assert_gt(marble.linear_velocity.x * float(-flipper.side), -1.0, "and toward the middle")


func test_a_fire_leaves_a_far_away_fish_alone() -> void:
	_table.reseed(1)
	var flipper: PinballFlipper = _flipper(PinballTable.LEFT)
	var marble: Marble = _marble_at(flipper.to_global(Vector2(flipper.length * 0.5, -400.0)))
	await wait_physics_frames(2)
	assert_eq(flipper.fire(), 0)
	assert_almost_eq(marble.linear_velocity.length(), 0.0, 0.5)


func test_a_bumper_pops_a_fish_away() -> void:
	_table.reseed(1)
	var bumper: StaticBody2D = _track.get_node("Bumper1") as StaticBody2D
	var center: Vector2 = bumper.get_node("Collider").global_position
	var marble: Marble = _marble_at(center + Vector2(0.0, -60.0), 0.0)
	await wait_physics_frames(2)
	# Roll the fish into the bumper from above.
	marble.linear_velocity = Vector2(0.0, 300.0)
	await wait_physics_frames(4)
	assert_lt(marble.linear_velocity.y, 0.0, "it is sent back up")
	assert_gt(marble.linear_velocity.length(), PinballTable.POP_SPEED * 0.3)


func test_the_plunger_launches_fish_up_the_lane() -> void:
	_table.reseed(1)
	var marble: Marble = _marble_at(_track.get_spawn_position(0), 1.0)
	await wait_physics_frames(30)
	var best: float = 0.0
	for i: int in int((PinballTable.LAUNCH_DELAY + 0.5) / STEP):
		await wait_physics_frames(1)
		best = minf(best, marble.linear_velocity.y)
	assert_lt(best, -PinballTable.LAUNCH_SPEED * 0.8, "the plunger shot it upward")


func test_a_fish_that_fell_back_is_launched_again() -> void:
	_table.reseed(1)
	var marble: Marble = _marble_at(_track.get_spawn_position(0), 1.0)
	await wait_physics_frames(20)
	assert_eq(_table.launch(), 1)
	marble.linear_velocity = Vector2.ZERO
	await wait_physics_frames(2)
	assert_eq(_table.launch(), 1)


func test_the_current_carries_fish_out_of_the_lane_top() -> void:
	_table.reseed(1)
	var marble: Marble = _marble_at(Vector2(1800.0, 250.0), 0.0)
	await wait_physics_frames(18)
	assert_lt(marble.linear_velocity.x, -400.0)


func test_stop_gimmicks_puts_the_flippers_back() -> void:
	_table.reseed(1)
	_table.fire(PinballTable.LEFT, "a")
	await wait_physics_frames(10)
	_track.stop_gimmicks()
	await wait_physics_frames(60)
	for flipper: PinballFlipper in _table.get_flippers():
		assert_almost_eq(flipper.rotation, flipper.rest_angle(), 0.001)
	assert_eq(_table.presses(PinballTable.LEFT), 0)


func test_seed_gimmicks_arms_the_table() -> void:
	_track.seed_gimmicks(RandomNumberGenerator.new())
	assert_true(_table.is_armed())
	assert_false(_table.get_schedule(PinballTable.LEFT).is_empty())


func test_other_maps_have_no_flippers() -> void:
	var zigzag: Track = TrackCatalog.instantiate("zigzag")
	add_child_autofree(zigzag)
	assert_true(zigzag.find_children("*", "PinballTable", true, false).is_empty())
	assert_eq(get_tree().get_nodes_in_group(PinballTable.CHAT_GROUP), [_table])
