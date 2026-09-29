extends GameTestBase
## Photo finish in the game scene: camera hold and slow-mo, always restored afterwards.


func after_each() -> void:
	Engine.time_scale = 1.0
	super.after_each()


func test_photo_finish_holds_camera_and_slows_then_state_change_restores() -> void:
	_start_race(2)
	var camera: RaceCamera = _game.get_node("RaceCamera") as RaceCamera
	_race.photo_finish.emit(0, 1)
	assert_true(camera.is_holding())
	assert_eq(Engine.time_scale, PhotoFinish.SLOW_SCALE)
	_finish_marbles([0, 1])
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	assert_false(camera.is_holding())
	assert_eq(Engine.time_scale, 1.0)


func test_photo_finish_is_ignored_outside_a_race() -> void:
	_race.photo_finish.emit(0, 1)
	assert_eq(Engine.time_scale, 1.0)


func test_race_results_do_not_depend_on_photo_finish() -> void:
	_start_race(2)
	_race.photo_finish.emit(0, 1)
	_finish_marbles([1, 0])
	assert_eq(_flow.state, GameFlow.State.PODIUM)
