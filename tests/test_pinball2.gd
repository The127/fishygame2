extends GutTest
## Pinball Reef 2: the tall table, its slingshots and the lock saucer that holds fish and fires them
## out together. The drop targets and the ramp gate are in test_pinball2_ramp.gd.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _saucer: LockSaucer


func before_each() -> void:
	_track = TrackCatalog.instantiate("pinball2")
	add_child_autofree(_track)
	_saucer = _track.get_node("Saucer") as LockSaucer
	# A body only takes its transform inside physics frames.
	await wait_physics_frames(3)


func _marble_at(pos: Vector2, gravity: float = 0.0) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = gravity
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


func _cup_spot(slot: int) -> Vector2:
	return _saucer.global_position + Vector2(25.0 + 40.0 * float(slot), -20.0)


func _arm() -> void:
	_track.seed_gimmicks(RandomNumberGenerator.new())


func test_the_map_is_registered_as_a_tall_table_with_the_same_chat_flippers() -> void:
	assert_true(TrackCatalog.has_map("pinball2"))
	assert_eq(TrackCatalog.get_name_of("pinball2"), "Pinball Reef 2")
	assert_gt(_track.view_bounds.size.y, 1900.0)
	var table: PinballTable = _track.get_node("PinballTable") as PinballTable
	assert_eq(table.get_flippers().size(), 4)
	assert_gte(table.bumper_count(), 8)
	assert_eq(get_tree().get_nodes_in_group(PinballTable.CHAT_GROUP), [table])
	assert_true(_track.has_method("get_hazards") and not _track.get_hazards().is_empty())


func test_the_plunger_reaches_the_top_of_the_lane() -> void:
	var table: PinballTable = _track.get_node("PinballTable") as PinballTable
	table.reseed(1)
	var marble: Marble = _marble_at(_track.get_spawn_position(0), 1.0)
	await wait_physics_frames(30)
	var top: float = marble.global_position.y
	for i: int in int(5.0 / STEP):
		await wait_physics_frames(1)
		top = minf(top, marble.global_position.y)
	assert_lt(top, 300.0, "the shot clears the divider at the top of the lane")


func test_a_slingshot_kicks_a_fish_along_its_face_normal() -> void:
	var sling: Slingshot = _track.get_node("SlingshotL") as Slingshot
	var marble: Marble = _marble_at(Vector2(1000.0, 100.0))
	assert_true(sling.kick_marble(marble))
	await wait_physics_frames(1)
	var direction: Vector2 = sling.kick.normalized()
	assert_almost_eq(marble.linear_velocity.dot(direction), Slingshot.KICK_SPEED, 5.0)
	assert_gt(sling.get_flash(), 0.9)


func test_a_slingshot_leaves_a_fish_that_is_leaving_fast_alone() -> void:
	var sling: Slingshot = _track.get_node("SlingshotR") as Slingshot
	var marble: Marble = _marble_at(Vector2(1000.0, 100.0))
	marble.linear_velocity = sling.kick.normalized() * Slingshot.KICK_SPEED * 2.0
	assert_false(sling.kick_marble(marble))


func test_a_fish_rolling_over_a_slingshot_gets_kicked() -> void:
	var sling: Slingshot = _track.get_node("SlingshotL") as Slingshot
	var face: PackedVector2Array = (sling.get_node("Collider") as CollisionPolygon2D).polygon
	var middle: Vector2 = sling.to_global((face[0] + face[1]) * 0.5)
	var marble: Marble = _marble_at(middle + sling.kick.normalized() * 40.0)
	await wait_physics_frames(2)
	marble.linear_velocity = -sling.kick.normalized() * 200.0
	await wait_physics_frames(12)
	assert_gt(marble.linear_velocity.dot(sling.kick.normalized()), 100.0, "it was sent off")


func test_the_saucer_holds_fish_until_a_full_lock() -> void:
	_arm()
	# A fish is still coming from the lane, so two locked fish wait.
	_marble_at(Vector2(1800.0, 1500.0))
	_marble_at(_cup_spot(0))
	_marble_at(_cup_spot(1))
	await wait_physics_frames(4)
	assert_false(_saucer.is_open())
	assert_eq(_saucer.locked_count, 2)
	assert_eq(_saucer.releases, 0)


func test_a_full_lock_fires_the_fish_out_together() -> void:
	_arm()
	_marble_at(Vector2(1800.0, 1500.0))
	var released: Array[int] = [0]
	_saucer.released.connect(func(count: int) -> void: released[0] = count)
	var fish: Array[Marble] = []
	for slot: int in _saucer.lock_count:
		fish.append(_marble_at(_cup_spot(slot)))
	await wait_physics_frames(4)
	assert_eq(released[0], _saucer.lock_count)
	assert_true(_saucer.is_open())
	await wait_physics_frames(14)
	for marble: Marble in fish:
		assert_gt(marble.linear_velocity.y, 100.0, "fired downward")
	assert_lt(fish[0].linear_velocity.x, fish[2].linear_velocity.x, "and fanned apart")


func test_locked_fish_are_let_go_when_no_fish_are_left_coming() -> void:
	_arm()
	# Another fish below the saucer has passed it already, one above is still coming.
	var passed: Marble = _marble_at(_saucer.global_position + Vector2(0.0, 600.0))
	var coming: Marble = _marble_at(_saucer.global_position + Vector2(0.0, -300.0))
	_marble_at(_cup_spot(0))
	await wait_physics_frames(4)
	assert_false(_saucer.is_open(), "a fish above the saucer is still coming")
	coming.global_position = _saucer.global_position + Vector2(0.0, 700.0)
	coming.linear_velocity = Vector2.ZERO
	await wait_physics_frames(4)
	assert_true(_saucer.is_open(), "nobody is left above the saucer")
	assert_eq(_saucer.releases, 1)
	assert_not_null(passed)


func test_fish_waiting_in_the_plunger_lane_keep_the_saucer_locked() -> void:
	_arm()
	_marble_at(Vector2(_saucer.lane_x + 100.0, _saucer.global_position.y + 900.0))
	_marble_at(_cup_spot(0))
	await wait_physics_frames(4)
	assert_false(_saucer.is_open())


func test_finished_fish_do_not_hold_the_saucer() -> void:
	_arm()
	var done: Marble = _marble_at(_saucer.global_position + Vector2(0.0, -300.0))
	done.has_finished = true
	_marble_at(_cup_spot(0))
	await wait_physics_frames(4)
	assert_true(_saucer.is_open())


func test_the_hatch_shuts_again_once_the_cup_is_empty() -> void:
	_arm()
	_marble_at(_cup_spot(0))
	await wait_physics_frames(4)
	assert_true(_saucer.is_open())
	await wait_physics_frames(90)
	assert_false(_saucer.is_open())
	var hatch: AnimatableBody2D = _saucer.get_node("Hatch") as AnimatableBody2D
	assert_almost_eq(hatch.rotation, 0.0, 0.001)


func test_an_unarmed_saucer_never_opens() -> void:
	_marble_at(_cup_spot(0))
	await wait_physics_frames(6)
	assert_false(_saucer.is_open())


func test_stop_gimmicks_shuts_the_saucer() -> void:
	_arm()
	_marble_at(_cup_spot(0))
	await wait_physics_frames(4)
	_track.stop_gimmicks()
	assert_false(_saucer.is_armed())
	assert_false(_saucer.is_open())
	assert_eq(_saucer.locked_count, 0)


func test_a_fish_on_the_drain_floor_rolls_into_the_finish_from_either_side() -> void:
	# The wedges either side of the finish keep a fish from resting under a slope.
	var finished: Array[Marble] = []
	_track.marble_reached_finish.connect(
		func(body: Node2D) -> void: finished.append(body as Marble)
	)
	var left: Marble = _marble_at(Vector2(200.0, 1860.0), 1.0)
	var right: Marble = _marble_at(Vector2(1600.0, 1860.0), 1.0)
	await wait_physics_frames(300)
	assert_true(finished.has(left), "from the left")
	assert_true(finished.has(right), "from the right")
