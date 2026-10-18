extends GutTest
## Board Game's hazard: a reverse card runs the current of two rows backwards for a moment.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _hazard: ReverseHazard


func before_each() -> void:
	_track = TrackCatalog.instantiate("board")
	add_child_autofree(_track)
	_hazard = _track.get_node("Reverse") as ReverseHazard
	await wait_physics_frames(2)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _run_until(phase: Hazard.Phase) -> void:
	var spent: float = 0.0
	while _hazard.phase != phase and spent < 100.0:
		_hazard.tick(STEP)
		spent += STEP


func test_it_is_the_maps_hazard() -> void:
	assert_eq(_track.get_hazards(), [_hazard] as Array[Hazard])
	assert_eq(_hazard.kind, "reverse")


func test_a_card_reverses_two_different_rows() -> void:
	for seed_value: int in range(1, 30):
		_hazard.arm(seed_value, 3)
		_run_until(Hazard.Phase.TELEGRAPH)
		var rows: Array[int] = _hazard.reversed_rows()
		assert_eq(rows.size(), ReverseHazard.ROWS_PER_EVENT)
		assert_ne(rows[0], rows[1])
		for row: int in rows:
			assert_between(row, 0, SnakeBoard.ROWS - 1)


func test_fish_on_a_reversed_row_drift_back_and_others_do_not() -> void:
	var board: SnakeBoard = _track.get_node("Centerline") as SnakeBoard
	board.reseed(1)
	_hazard.arm(4, 3)
	_run_until(Hazard.Phase.ACTIVE)
	var rows: Array[int] = _hazard.reversed_rows()
	var other: int = 0
	while rows.has(other):
		other += 1
	var hit: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	var free: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(hit)
	add_child_autofree(free)
	hit.global_position = SnakeBoard.square_center(rows[0] * SnakeBoard.COLS + 5)
	free.global_position = SnakeBoard.square_center(other * SnakeBoard.COLS + 5)
	var hit_start: float = hit.global_position.x
	var free_start: float = free.global_position.x
	await wait_physics_frames(40)
	var hit_moved: float = (hit.global_position.x - hit_start) * float(SnakeBoard.row_dir(rows[0]))
	var free_moved: float = (free.global_position.x - free_start) * float(SnakeBoard.row_dir(other))
	assert_lt(hit_moved, 0.0, "pushed back against its row")
	assert_gt(free_moved, 20.0, "carried on along its row")


func test_the_rows_clear_when_the_card_ends() -> void:
	_hazard.arm(2, 3)
	_run_until(Hazard.Phase.ACTIVE)
	_run_until(Hazard.Phase.IDLE)
	assert_true(_hazard.reversed_rows().is_empty())
