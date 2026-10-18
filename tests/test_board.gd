extends GutTest
## Board Game: the squares, the ladders and snakes and how the fish move on the board.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _board: SnakeBoard
var _dice: BoardDice


func before_each() -> void:
	_track = TrackCatalog.instantiate("board")
	add_child_autofree(_track)
	_board = _track.get_node("Centerline") as SnakeBoard
	_dice = _board.get_dice()
	# A body only takes its transform inside physics frames.
	await wait_physics_frames(3)


func _marble_at(pos: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


## Waits until the board lets go of `marble`, or `seconds` pass.
func _wait_until_still(marble: Marble, seconds: float = 4.0) -> void:
	for i: int in int(seconds / STEP):
		if not _board.is_moving(marble):
			return
		await wait_physics_frames(1)


func test_squares_run_back_and_forth_up_the_board() -> void:
	for square: int in range(1, SnakeBoard.LAST_SQUARE + 1):
		assert_eq(SnakeBoard.square_at(SnakeBoard.square_center(square)), square)
	var one: Vector2 = SnakeBoard.square_center(1)
	var ten: Vector2 = SnakeBoard.square_center(10)
	var eleven: Vector2 = SnakeBoard.square_center(11)
	var hundred: Vector2 = SnakeBoard.square_center(100)
	assert_lt(one.x, ten.x, "the bottom row runs to the right")
	assert_almost_eq(eleven.x, ten.x, 0.1, "the next row starts above the end of the last")
	assert_lt(eleven.y, ten.y)
	assert_almost_eq(hundred.x, one.x, 0.1, "the finish is top left")
	assert_lt(hundred.y, one.y)


func test_the_pen_and_the_tray_are_off_the_board() -> void:
	assert_eq(SnakeBoard.square_at(_track.get_spawn_position(0)), 0)
	assert_eq(SnakeBoard.square_at(SnakeBoard.TRAY.get_center()), 0)


func test_the_finish_is_square_100() -> void:
	assert_eq(SnakeBoard.square_at(_track.get_finish_position()), SnakeBoard.LAST_SQUARE)


func test_ladders_go_up_and_snakes_go_down() -> void:
	for foot: int in SnakeBoard.LADDERS:
		assert_gt(int(SnakeBoard.LADDERS[foot]), foot)
	for head: int in SnakeBoard.SNAKES:
		assert_lt(int(SnakeBoard.SNAKES[head]), head)


func test_no_ladder_or_snake_ends_where_another_starts() -> void:
	var starts: Array = SnakeBoard.LADDERS.keys() + SnakeBoard.SNAKES.keys()
	var ends: Array = SnakeBoard.LADDERS.values() + SnakeBoard.SNAKES.values()
	for square: int in starts:
		assert_false(ends.has(square), "square %d" % square)
		assert_true(square > 1 and square < SnakeBoard.LAST_SQUARE)
	var seen: Dictionary = {}
	for square: int in starts:
		assert_false(seen.has(square), "two links start on square %d" % square)
		seen[square] = true


func test_the_route_runs_from_the_pen_to_the_finish() -> void:
	var first: Vector2 = _board.to_global(_board.curve.get_point_position(0))
	var last: Vector2 = _board.to_global(
		_board.curve.get_point_position(_board.curve.point_count - 1)
	)
	assert_eq(SnakeBoard.square_at(first), 0)
	assert_eq(SnakeBoard.square_at(last), SnakeBoard.LAST_SQUARE)
	assert_lt(
		_track.get_progress(SnakeBoard.square_center(20)),
		_track.get_progress(SnakeBoard.square_center(21))
	)
	assert_lt(
		_track.get_progress(SnakeBoard.square_center(55)),
		_track.get_progress(SnakeBoard.square_center(99))
	)


func test_a_roll_hops_a_fish_that_many_squares() -> void:
	_board.reseed(1)
	var marble: Marble = _marble_at(SnakeBoard.square_center(4))
	await wait_physics_frames(2)
	_board.roll(2)
	assert_eq(_board.move_of(marble), SnakeBoard.Move.HOP)
	await _wait_until_still(marble)
	assert_eq(SnakeBoard.square_at(marble.global_position), 6)
	assert_false(marble.freeze)
	assert_eq(marble.collision_layer, 1, "collisions are back")


func test_landing_on_a_ladder_climbs_it() -> void:
	_board.reseed(1)
	var marble: Marble = _marble_at(SnakeBoard.square_center(1))
	await wait_physics_frames(2)
	_board.roll(2)
	await _wait_until_still(marble)
	assert_eq(SnakeBoard.square_at(marble.global_position), int(SnakeBoard.LADDERS[3]))
	assert_eq(_board.climb_count(), 1)


func test_landing_on_a_snake_slides_down_it() -> void:
	_board.reseed(1)
	var marble: Marble = _marble_at(SnakeBoard.square_center(14))
	await wait_physics_frames(2)
	_board.roll(3)
	await _wait_until_still(marble)
	assert_eq(SnakeBoard.square_at(marble.global_position), int(SnakeBoard.SNAKES[17]))
	assert_eq(_board.bite_count(), 1)


func test_sleeping_snakes_do_not_bite() -> void:
	_board.reseed(1)
	_board.clock = SnakeBoard.SNAKE_SLEEP + 1.0
	assert_false(_board.snakes_awake())
	var marble: Marble = _marble_at(SnakeBoard.square_center(14))
	await wait_physics_frames(2)
	_board.roll(3)
	await _wait_until_still(marble)
	assert_eq(SnakeBoard.square_at(marble.global_position), 17)
	assert_eq(_board.bite_count(), 0)


func test_fish_in_the_pen_do_not_hop() -> void:
	_board.reseed(1)
	var marble: Marble = _marble_at(_track.get_spawn_position(0))
	await wait_physics_frames(2)
	_board.roll(6)
	assert_false(_board.is_moving(marble))


func test_fish_landing_on_the_same_square_do_not_overlap() -> void:
	_board.reseed(1)
	# Two fish stacked on one square both land on square 6.
	var low: Marble = _marble_at(SnakeBoard.square_center(4))
	var high: Marble = _marble_at(SnakeBoard.square_center(4) + Vector2(0.0, -30.0))
	await wait_physics_frames(2)
	_board.roll(2)
	await _wait_until_still(low)
	await _wait_until_still(high)
	assert_gt(low.global_position.distance_to(high.global_position), Marble.RADIUS * 2.0)


func test_the_lift_takes_a_fish_up_to_the_next_row() -> void:
	_board.reseed(1)
	var marble: Marble = _marble_at(SnakeBoard.square_center(10) + Vector2(36.0, 0.0))
	await wait_physics_frames(3)
	assert_eq(_board.move_of(marble), SnakeBoard.Move.LIFT)
	await _wait_until_still(marble)
	assert_eq(SnakeBoard.square_at(marble.global_position), 11)


func test_the_current_carries_a_fish_along_its_row() -> void:
	_board.reseed(1)
	var marble: Marble = _marble_at(SnakeBoard.square_center(13))
	var start: float = marble.global_position.x
	await wait_physics_frames(30)
	assert_lt(marble.global_position.x, start - 20.0, "row 2 runs to the left")


func test_a_finished_fish_is_carried_to_the_tray() -> void:
	_board.reseed(1)
	var marble: Marble = _marble_at(SnakeBoard.square_center(SnakeBoard.LAST_SQUARE))
	marble.has_finished = true
	await wait_physics_frames(3)
	assert_eq(_board.move_of(marble), SnakeBoard.Move.TRAY)
	await _wait_until_still(marble)
	assert_true(SnakeBoard.TRAY.grow(Marble.RADIUS).has_point(marble.global_position))


func test_a_fish_knocked_off_the_board_is_put_back() -> void:
	_board.reseed(1)
	var marble: Marble = _marble_at(SnakeBoard.square_center(25))
	await wait_physics_frames(3)
	marble.global_position = Vector2(1700.0, 1200.0)
	await wait_physics_frames(3)
	await _wait_until_still(marble)
	assert_between(SnakeBoard.square_at(marble.global_position), 25, 27)


func test_freezing_lets_go_of_the_fish_and_stops_the_die() -> void:
	_board.reseed(1)
	var marble: Marble = _marble_at(SnakeBoard.square_center(4))
	await wait_physics_frames(2)
	_board.roll(4)
	assert_true(_board.is_moving(marble))
	_track.stop_hazards()
	assert_false(_board.is_moving(marble))
	assert_eq(marble.collision_layer, 1)
	assert_false(_dice.is_armed())
	assert_false(_dice.press("late", 0))
