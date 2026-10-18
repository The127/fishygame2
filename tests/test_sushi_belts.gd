extends GutTest
## The belts of Sushi Bar carry the fish toward each belt's far end, every fish with its own seeded
## knack, and the route runs along every belt to the finish.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"

var _track: Track
var _belts: SushiBelts


func before_each() -> void:
	_track = TrackCatalog.instantiate("sushi")
	add_child_autofree(_track)
	_belts = _track.get_node("Centerline") as SushiBelts


func test_the_belts_take_turns_running_right_and_left() -> void:
	assert_eq(_belts.direction(0), 1.0)
	assert_eq(_belts.direction(1), -1.0)
	assert_eq(_belts.direction(2), 1.0)


func test_a_belt_carries_a_fish_toward_its_far_end() -> void:
	_belts.reseed(3)
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	var start: Vector2 = Vector2(600.0, _belts.belt_y(1) - Marble.RADIUS - 1.0)
	marble.global_position = start
	await wait_physics_frames(60)
	assert_lt(marble.global_position.x, start.x - 100.0, "the second belt runs to the left")


func test_knacks_are_seeded_and_small() -> void:
	_belts.reseed(7)
	var first: float = _belts.knack(3, 1)
	_belts.reseed(7)
	assert_eq(_belts.knack(3, 1), first, "the same seed gives the same knack")
	for id: int in 20:
		assert_lte(absf(_belts.knack(id, 0)), SushiBelts.KNACK)


func test_the_seed_sets_each_belt_speed_within_its_spread() -> void:
	_belts.reseed(11)
	for i: int in _belts.belt_count:
		var ratio: float = _belts.belt_speed(i) / _belts.speed
		assert_between(ratio, 1.0 - _belts.speed_spread, 1.0 + _belts.speed_spread)


func test_progress_grows_down_the_belts() -> void:
	var on_first: float = _track.get_progress(Vector2(900.0, _belts.belt_y(0) - 18.0))
	var on_second: float = _track.get_progress(Vector2(900.0, _belts.belt_y(1) - 18.0))
	var on_last: float = _track.get_progress(Vector2(900.0, _belts.belt_y(3) - 18.0))
	assert_lt(on_first, on_second)
	assert_lt(on_second, on_last)


func test_the_chef_keeps_clear_of_the_humps() -> void:
	var chef: SushiChef = _belts.get_chefs()[0]
	var index: int = _belts.nearest_belt(chef.position.y)
	for x: float in _belts.hump_xs(index):
		assert_gt(absf(x - chef.position.x), SushiChef.BLADE_HALF + Marble.RADIUS * 2.0)


func test_a_jam_turns_a_belt_round_and_back() -> void:
	var jam: BeltReverseHazard = _track.get_node("Jam") as BeltReverseHazard
	jam.arm(4, 5)
	var first: float = jam.get_schedule()[0]
	jam.tick(first + 0.01)
	var index: int = jam.belt()
	var normal: float = _belts.belt_velocity(index)
	_tick(jam, jam.telegraph_seconds + BeltReverseHazard.TURN + 0.1)
	assert_lt(_belts.belt_velocity(index) * normal, 0.0, "the jammed belt runs backwards")
	_tick(jam, jam.active_seconds)
	assert_eq(_belts.belt_velocity(index), normal, "and its proper way again afterwards")


func _tick(hazard: Hazard, seconds: float) -> void:
	for i: int in roundi(seconds * 60.0):
		hazard.tick(1.0 / 60.0)
