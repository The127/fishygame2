extends GutTest
## Inside the Whale: the pulsing stomach lobes, the digestive pools, the gut that squeezes fish
## along and the blowhole at the finish.

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


## A fish floating at `at` with gravity off, so only the map's own forces move it.
func _fish(at: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = at
	return marble


func test_the_whale_is_a_map_with_a_burp_and_a_gulp_hazard() -> void:
	assert_true(TrackCatalog.has_map("whale"))
	var track: Track = _whale()
	assert_eq(track.get_hazards().size(), 2)
	assert_eq(track.get_hazards()[0].kind, "burp")
	assert_eq(track.get_hazards()[1].kind, "gulp")


func test_the_stomach_lobes_swell_and_relax() -> void:
	var track: Track = _whale()
	var lobes: Array[Node] = track.find_children("Pulser*", "PulsingBumper", false, false)
	assert_eq(lobes.size(), 3)
	var lobe: PulsingBumper = lobes[0] as PulsingBumper
	var low: float = INF
	var high: float = -INF
	for i: int in 200:
		var size: float = lobe.scale_at(float(i) * 0.02)
		low = minf(low, size)
		high = maxf(high, size)
	assert_almost_eq(low, PulsingBumper.REST_SCALE, 0.001)
	assert_gt(high, PulsingBumper.REST_SCALE + 0.3)
	assert_lte(high, PulsingBumper.PEAK_SCALE + 0.001)


func test_the_lobes_pulse_out_of_step() -> void:
	var track: Track = _whale()
	var sizes: Dictionary = {}
	for lobe: Node in track.find_children("Pulser*", "PulsingBumper", false, false):
		sizes[snappedf((lobe as PulsingBumper).scale_at(0.2), 0.001)] = true
	assert_gt(sizes.size(), 1)


func test_a_seed_always_starts_the_pulse_at_the_same_point() -> void:
	var first: PulsingBumper = _whale().find_child("Pulser1") as PulsingBumper
	first.reseed(7)
	var expected: float = first.scale_at(0.3)
	first.reseed(9)
	assert_ne(first.scale_at(0.3), expected)
	first.reseed(7)
	assert_eq(first.scale_at(0.3), expected)


func test_the_lobe_follows_the_replay_state() -> void:
	var lobe: PulsingBumper = _whale().find_child("Pulser1") as PulsingBumper
	lobe.sync_to_physics = false
	lobe._physics_process(0.1)
	var from: PackedFloat32Array = lobe.replay_state()
	lobe._physics_process(0.2)
	var to: PackedFloat32Array = lobe.replay_state()
	lobe.replay_apply(from, to, 0.5)
	assert_almost_eq(lobe.clock, 0.2, 0.001)
	assert_almost_eq(lobe.scale.x, lobe.scale_at(0.2), 0.001)


func test_a_digestive_pool_slows_a_fish() -> void:
	var pool: DigestivePool = _whale().find_child("Pool1") as DigestivePool
	var inside: Marble = _fish(pool.global_position)
	inside.linear_velocity = Vector2(-300.0, 0.0)
	var outside: Marble = _fish(pool.global_position + Vector2(0.0, -400.0))
	outside.linear_velocity = Vector2(-300.0, 0.0)
	await wait_physics_frames(30)
	assert_gt(inside.linear_velocity.length(), 0.0)
	assert_lt(inside.linear_velocity.length(), outside.linear_velocity.length() * 0.6)


func test_the_gut_squeezes_a_fish_along() -> void:
	var gut: Peristalsis = _whale().find_child("Gut") as Peristalsis
	var fish: Marble = _fish(gut.global_position)
	await wait_physics_frames(30)
	assert_gt(fish.linear_velocity.dot(gut.get_direction()), 100.0)


func test_the_blowhole_throws_only_fish_that_have_finished() -> void:
	var hole: Blowhole = _whale().find_child("Blowhole") as Blowhole
	var at: Vector2 = hole.global_position + Vector2(0.0, -60.0)
	var done: Marble = _fish(at)
	done.has_finished = true
	var racing: Marble = _fish(at + Vector2(30.0, 0.0))
	await wait_physics_frames(20)
	assert_lt(done.linear_velocity.y, -200.0, "the finished fish is launched")
	assert_almost_eq(racing.linear_velocity.y, 0.0, 1.0, "a fish still racing is left alone")


func test_the_blowhole_plume_follows_the_replay_state() -> void:
	var hole: Blowhole = _whale().find_child("Blowhole") as Blowhole
	var from: PackedFloat32Array = PackedFloat32Array([0.0, 1.0])
	var to: PackedFloat32Array = PackedFloat32Array([1.0, 2.0])
	hole.replay_apply(from, to, 0.5)
	assert_almost_eq(hole.replay_state()[0], 0.5, 0.001)
	assert_almost_eq(hole.replay_state()[1], 1.5, 0.001)
