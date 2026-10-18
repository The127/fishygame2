extends GutTest
## Board Game: the die, its chat meter and the rolls it makes on its own.

const STEP: float = 1.0 / 60.0

var _track: Track
var _board: SnakeBoard
var _dice: BoardDice


func before_each() -> void:
	_track = TrackCatalog.instantiate("board")
	add_child_autofree(_track)
	_board = _track.get_node("Centerline") as SnakeBoard
	_dice = _board.get_dice()
	await wait_physics_frames(1)


func _tick_dice(seconds: float) -> void:
	for i: int in int(seconds / STEP):
		_dice.tick(STEP)


## Presses as `count` different viewers.
func _spam(count: int, viewers: int = 0) -> void:
	for i: int in count:
		_dice.press("viewer%d" % i, viewers)


func test_presses_needed_scale_with_the_viewers_within_limits() -> void:
	assert_eq(BoardDice.presses_needed(0), BoardDice.NEED_MIN)
	assert_eq(BoardDice.presses_needed(20), 8)
	assert_eq(BoardDice.presses_needed(1000), BoardDice.NEED_MAX)


func test_a_disarmed_die_ignores_presses() -> void:
	assert_false(_dice.press("a", 10))
	assert_eq(_dice.counted_presses(), 0)


func test_enough_presses_roll_the_die() -> void:
	_board.reseed(1)
	_spam(BoardDice.NEED_MIN - 1)
	assert_eq(_dice.roll_count(), 0)
	_dice.press("one_more", 0)
	assert_eq(_dice.roll_count(), 1)
	assert_true(_dice.is_tumbling())


func test_one_viewer_cannot_roll_alone() -> void:
	_board.reseed(1)
	for i: int in 30:
		_dice.press("spammer", 0)
	assert_eq(_dice.roll_count(), 0)
	assert_eq(_dice.counted_presses(), BoardDice.PER_VIEWER)


func test_a_roll_has_a_cooldown() -> void:
	_board.reseed(1)
	_spam(BoardDice.NEED_MIN)
	_spam(BoardDice.NEED_MIN)
	assert_eq(_dice.roll_count(), 1)
	_tick_dice(BoardDice.COOLDOWN + 0.1)
	_spam(BoardDice.NEED_MIN)
	assert_eq(_dice.roll_count(), 2)


func test_the_die_rolls_on_its_own_when_chat_is_quiet() -> void:
	_board.reseed(5)
	var first: float = _dice.next_auto_time()
	assert_between(first, BoardDice.FIRST_MIN, BoardDice.FIRST_MAX)
	_tick_dice(first + BoardDice.ROLL_SECONDS + 0.1)
	assert_eq(_dice.roll_count(), 1)
	_tick_dice(BoardDice.AUTO_MAX + BoardDice.ROLL_SECONDS)
	assert_eq(_dice.roll_count(), 2)


func test_a_seed_rolls_the_same_faces() -> void:
	var faces: Array[int] = []
	_dice.rolled.connect(func(value: int) -> void: faces.append(value))
	for attempt: int in 2:
		_board.reseed(9)
		_tick_dice(30.0)
	assert_eq(faces.size() % 2, 0)
	var half: int = faces.size() / 2
	assert_gt(half, 3)
	assert_eq(faces.slice(0, half), faces.slice(half))
	for value: int in faces:
		assert_between(value, 1, 6)


func test_the_meter_counts_presses() -> void:
	var texts: Array[String] = []
	_board.meter_changed.connect(func(text: String) -> void: texts.append(text))
	_board.reseed(1)
	_dice.press("a", 0)
	assert_string_contains(texts[-1], "#roll")
	assert_string_contains(texts[-1], "1 / %d" % BoardDice.NEED_MIN)
	_board.freeze()
	assert_eq(texts[-1], "")
