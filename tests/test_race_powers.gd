extends GutTest
## Race: the physical effects of the streamer's rod, net and bubble blast.

const TRACK_SCENE: String = "res://scenes/tracks/test_track.tscn"
const MARBLE_SCENE: String = "res://scenes/marble.tscn"

var _race: Race
var _track: Track


func before_each() -> void:
	_track = (load(TRACK_SCENE) as PackedScene).instantiate() as Track
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_race.start(_track, 3, rng)
	for marble: Marble in _race.get_marbles():
		# Nothing but the power under test may move the fish.
		marble.gravity_scale = 0.0
		marble.collision_mask = 0
		marble.global_position = Vector2(500.0 + 1000.0 * marble.id, 500.0)
		marble.linear_velocity = Vector2.ZERO
	# Let the physics server pick up the new positions before a test pushes anything.
	await get_tree().physics_frame


func _marble(id: int) -> Marble:
	for marble: Marble in _race.get_marbles():
		if marble.id == id:
			return marble
	return null


func test_hook_picks_the_nearest_fish_in_reach() -> void:
	_marble(1).global_position = Vector2(1560.0, 500.0)
	assert_eq(_race.hook_near(Vector2(1500.0, 500.0), 150.0), 1)


func test_hook_misses_when_no_fish_is_in_reach() -> void:
	assert_eq(_race.hook_near(Vector2(5000.0, 5000.0), 150.0), -1)


func test_hook_yanks_the_fish_back_against_the_track() -> void:
	var marble: Marble = _marble(0)
	var forward: Vector2 = _track.get_forward(marble.global_position)
	marble.linear_velocity = forward * 400.0
	assert_eq(_race.hook_near(marble.global_position, 150.0), 0)
	await get_tree().physics_frame
	assert_lt(marble.linear_velocity.dot(forward), 0.0)


func test_hook_drops_even_on_a_miss() -> void:
	var before: int = _race.get_child_count()
	_race.hook_near(Vector2(5000.0, 5000.0), 150.0)
	assert_eq(_race.get_child_count(), before + 1)


func test_hook_ignores_a_finished_fish() -> void:
	_track.marble_reached_finish.emit(_marble(0))
	assert_eq(_race.hook_near(_marble(0).global_position, 150.0), -1)


func test_net_counts_the_fish_inside() -> void:
	assert_eq(_race.place_net(Vector2(500.0, 500.0), 170.0, 2.5), 1)
	assert_eq(_race.place_net(Vector2(5000.0, 5000.0), 170.0, 2.5), 0)


func test_net_holds_fish_inside_and_lets_others_go() -> void:
	_race.place_net(Vector2(500.0, 500.0), 170.0, 2.5)
	var held: Marble = _marble(0)
	var free: Marble = _marble(1)
	held.linear_velocity = Vector2(300.0, 0.0)
	free.linear_velocity = Vector2(300.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_lt(held.linear_velocity.length(), 300.0 * 0.6)
	assert_gt(free.linear_velocity.length(), 300.0 * 0.9)


func test_blast_pushes_fish_away_from_the_centre() -> void:
	var marble: Marble = _marble(0)
	marble.global_position = Vector2(550.0, 500.0)
	assert_eq(_race.blast(Vector2(500.0, 500.0), 200.0), 1)
	await get_tree().physics_frame
	assert_gt(marble.linear_velocity.x, 0.0)
	assert_almost_eq(marble.linear_velocity.y, 0.0, 0.5)


func test_blast_on_the_exact_centre_still_moves_the_fish() -> void:
	var marble: Marble = _marble(0)
	assert_eq(_race.blast(marble.global_position, 200.0), 1)
	await get_tree().physics_frame
	assert_gt(marble.linear_velocity.length(), 0.0)


func test_powers_do_nothing_once_the_race_is_over() -> void:
	_race.clear()
	assert_eq(_race.hook_near(Vector2(500.0, 500.0), 150.0), -1)
	assert_eq(_race.place_net(Vector2(500.0, 500.0), 170.0, 2.5), 0)
	assert_eq(_race.blast(Vector2(500.0, 500.0), 200.0), 0)


func test_clear_removes_nets() -> void:
	_race.place_net(Vector2(500.0, 500.0), 170.0, 2.5)
	_race.clear()
	assert_eq(_race._powers.nets.size(), 0)
