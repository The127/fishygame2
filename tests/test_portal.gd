extends GutTest
## Portal pairs, the rift hazard and the Abyss map around them.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _track() -> Track:
	var track: Track = TrackCatalog.instantiate("abyss")
	add_child_autofree(track)
	return track


func _marble(at: Vector2, velocity: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = at
	marble.linear_velocity = velocity
	return marble


func _rift(track: Track) -> RiftHazard:
	return track.get_hazards()[0] as RiftHazard


func _pair(track: Track, node_name: String) -> PortalPair:
	return _rift(track).get_node(node_name) as PortalPair


func test_abyss_is_a_dark_glowing_map_with_a_rift() -> void:
	var track: Track = _track()
	assert_eq(track.style_id, "abyss")
	assert_gt(track.fish_glow, 1.0)
	assert_eq(track.get_hazards().size(), 2, "the rift and the anglers")
	assert_not_null(_rift(track))
	assert_eq(_rift(track).kind, "rift")
	assert_gt(track.find_children("*", "AnglerLure", false, false).size(), 2)


func test_fish_touching_the_entry_reappear_at_the_exit_with_their_velocity() -> void:
	var track: Track = _track()
	var pair: PortalPair = _pair(track, "PortalA")
	var velocity: Vector2 = Vector2(420.0, 60.0)
	var marble: Marble = _marble(pair.entry_point, velocity)
	await wait_physics_frames(3)
	assert_lt(marble.global_position.distance_to(pair.exit_point), 60.0, "came out at the exit")
	assert_gt(marble.linear_velocity.x, 300.0, "kept its speed")


func test_arrivals_come_out_side_by_side() -> void:
	var track: Track = _track()
	var pair: PortalPair = _pair(track, "PortalA")
	var spots: Dictionary = {}
	for i: int in PortalPair.EXIT_SLOTS:
		spots[pair.next_destination()] = true
		pair._sent += 1
	assert_eq(spots.size(), PortalPair.EXIT_SLOTS)


func test_a_teleported_fish_is_ignored_for_a_moment() -> void:
	var track: Track = _track()
	var pair: PortalPair = _pair(track, "PortalA")
	var marble: Marble = _marble(pair.entry_point, Vector2.ZERO)
	await wait_physics_frames(3)
	assert_true(pair.is_cooling_down(marble))
	# Put it straight back on the entry: it stays there while the cooldown runs.
	marble.global_position = pair.entry_point
	marble.linear_velocity = Vector2.ZERO
	await wait_physics_frames(3)
	assert_lt(marble.global_position.distance_to(pair.entry_point), 5.0)
	await wait_physics_frames(int((PortalPair.COOLDOWN + 0.3) / STEP))
	assert_false(pair.is_cooling_down(marble))


func test_a_rift_sends_fish_back_instead_of_ahead() -> void:
	var track: Track = _track()
	var pair: PortalPair = _pair(track, "PortalA")
	pair.diverted = true
	assert_lt(pair.next_destination().distance_to(pair.divert_point), 60.0)
	var marble: Marble = _marble(pair.entry_point, Vector2.ZERO)
	await wait_physics_frames(3)
	assert_lt(marble.global_position.distance_to(pair.divert_point), 60.0)


func test_rift_event_makes_a_portal_unstable_then_stable_again() -> void:
	var track: Track = _track()
	var hazard: RiftHazard = _rift(track)
	track.arm_hazards(_rng(3), 3)
	var spent: float = 0.0
	while hazard.phase != Hazard.Phase.TELEGRAPH and spent < 100.0:
		hazard.tick(STEP)
		spent += STEP
	var pair: PortalPair = hazard.get_active_pair()
	assert_not_null(pair)
	assert_false(pair.diverted, "only a warning while telegraphing")
	while hazard.phase != Hazard.Phase.ACTIVE:
		hazard.tick(STEP)
	assert_true(pair.diverted)
	while hazard.phase != Hazard.Phase.IDLE:
		hazard.tick(STEP)
	assert_false(pair.diverted)
	assert_eq(pair.unstable, 0.0)


func test_stopping_hazards_puts_the_portals_back() -> void:
	var track: Track = _track()
	var hazard: RiftHazard = _rift(track)
	track.arm_hazards(_rng(3), 3)
	while hazard.phase != Hazard.Phase.ACTIVE:
		hazard.tick(STEP)
	var pair: PortalPair = hazard.get_active_pair()
	track.stop_hazards()
	assert_false(pair.diverted)
	assert_null(hazard.get_active_pair())


func test_portals_are_inside_the_camera_view() -> void:
	var track: Track = _track()
	for node_name: String in ["PortalA", "PortalB"]:
		var pair: PortalPair = _pair(track, node_name)
		for point: Vector2 in [pair.entry_point, pair.exit_point, pair.divert_point]:
			assert_true(track.view_bounds.has_point(point), "%s %s" % [node_name, point])
