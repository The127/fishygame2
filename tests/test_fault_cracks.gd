extends GutTest
## Earthquake Fault: the cracks in the floor, the pit rubble and what the finish replay records.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _fault: QuakeFault


func before_each() -> void:
	_track = TrackCatalog.instantiate("fault")
	add_child_autofree(_track)
	_fault = _track.get_node("Fault") as QuakeFault
	# A body only takes its transform inside physics frames.
	await wait_physics_frames(3)


func _marble_at(pos: Vector2, gravity: float = 0.0) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = gravity
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


func _tick(seconds: float) -> void:
	for i: int in int(seconds / STEP):
		_fault.tick(STEP)


func _crack(node_name: String) -> FaultCrack:
	return _fault.get_node(node_name) as FaultCrack


## Presses as `count` different viewers.
func _spam(count: int, viewers: int = 0) -> void:
	for i: int in count:
		_fault.shake("viewer%d" % i, viewers)


func test_the_map_is_registered_with_four_cracks() -> void:
	assert_true(TrackCatalog.has_map("fault"))
	assert_eq(TrackCatalog.get_name_of("fault"), "Earthquake Fault")
	assert_not_null(_fault)
	assert_eq(_fault.get_cracks().size(), 4)
	var shortcuts: int = 0
	var pits: int = 0
	for crack: FaultCrack in _fault.get_cracks():
		if crack.kind == FaultCrack.Kind.SHORTCUT:
			shortcuts += 1
		else:
			pits += 1
	assert_eq(shortcuts, 2)
	assert_eq(pits, 2)


func test_the_floor_is_whole_until_a_crack_opens() -> void:
	for crack: FaultCrack in _fault.get_cracks():
		assert_false(crack.is_open())
		assert_false((crack.get_node("Plug/Collider") as CollisionPolygon2D).disabled)


func test_an_open_crack_drops_its_plug_and_lets_fish_through() -> void:
	var crack: FaultCrack = _crack("CrackA")
	var marble: Marble = _marble_at(Vector2(1030, 200), 1.0)
	crack.close()
	await wait_physics_frames(60)
	assert_lt(marble.global_position.y, 260.0, "the shut crack holds the fish up")
	crack.open()
	await wait_physics_frames(2)
	assert_true((crack.get_node("Plug/Collider") as CollisionPolygon2D).disabled)
	for i: int in 90:
		crack.tick(STEP)
	assert_almost_eq(crack.openness, 1.0, 0.001)
	await wait_physics_frames(60)
	assert_gt(marble.global_position.y, 300.0, "the fish fell through to the shelf below")


func test_closing_a_crack_restores_the_plug() -> void:
	var crack: FaultCrack = _crack("CrackB")
	crack.open()
	crack.tick(1.0)
	crack.close()
	await wait_physics_frames(2)
	assert_false(crack.is_open())
	assert_false((crack.get_node("Plug/Collider") as CollisionPolygon2D).disabled)
	assert_almost_eq(crack.openness, 0.0, 0.001)


func test_pit_rubble_slows_fish_and_pushes_them_out() -> void:
	var pit: FaultCrack = _crack("PitC")
	pit.open()
	await wait_physics_frames(2)
	# A fish dropped into the pit from rest always gets out the far side.
	var start: Vector2 = pit.center() + Vector2(-40, -20)
	var marble: Marble = _marble_at(start, 1.0)
	var exit_x: float = start.x + 160.0
	var frames: int = 0
	while marble.global_position.x < exit_x and frames < 600:
		await wait_physics_frames(1)
		pit.tick(STEP)
		frames += 1
	assert_lt(frames, 600, "the fish left the pit")
	assert_gt(frames, 40, "and the rubble held it up a moment")


func test_a_shut_pit_has_no_rubble() -> void:
	var pit: FaultCrack = _crack("PitC")
	var marble: Marble = _marble_at(pit.center() + Vector2(0, -60), 0.0)
	marble.linear_velocity = Vector2(300, 0)
	await wait_physics_frames(2)
	pit.tick(STEP)
	assert_gt(marble.linear_velocity.x, 250.0)


func test_cracks_and_the_fault_are_part_of_the_finish_replay() -> void:
	var nodes: Array[Node] = Replayable.find_in(_track)
	assert_true(nodes.has(_fault))
	for crack: FaultCrack in _fault.get_cracks():
		assert_true(nodes.has(crack), "%s is recorded" % crack.name)


func test_the_replay_shows_a_crack_opening() -> void:
	var crack: FaultCrack = _crack("CrackB")
	var shut: PackedFloat32Array = crack.replay_state()
	crack.open()
	crack.tick(1.0)
	var open: PackedFloat32Array = crack.replay_state()
	crack.close()
	crack.replay_apply(shut, open, 0.5)
	assert_almost_eq(crack.openness, 0.5, 0.01)
	crack.replay_apply(shut, open, 1.0)
	assert_almost_eq(crack.openness, 1.0, 0.01)
	assert_gt((crack.get_node("Plug/Visual") as Polygon2D).position.y, 1.0, "the plug sank")
