extends GutTest


func after_each() -> void:
	Engine.time_scale = 1.0


func test_is_close_needs_distance_and_speed() -> void:
	assert_true(PhotoFinish.is_close(40.0, 400.0))
	assert_false(PhotoFinish.is_close(400.0, 4000.0), "too far even if fast")
	assert_false(PhotoFinish.is_close(100.0, 100.0), "would take a second")
	assert_false(PhotoFinish.is_close(10.0, 0.0), "not moving")


func test_time_scale_curve() -> void:
	assert_eq(PhotoFinish.time_scale_at(0.0), PhotoFinish.SLOW_SCALE)
	assert_eq(PhotoFinish.time_scale_at(PhotoFinish.HOLD_SECONDS), PhotoFinish.SLOW_SCALE)
	var mid: float = PhotoFinish.time_scale_at(
		PhotoFinish.HOLD_SECONDS + PhotoFinish.RAMP_SECONDS * 0.5
	)
	assert_between(mid, PhotoFinish.SLOW_SCALE, 1.0)
	assert_eq(PhotoFinish.time_scale_at(PhotoFinish.HOLD_SECONDS + PhotoFinish.RAMP_SECONDS), 1.0)
	assert_eq(PhotoFinish.time_scale_at(99.0), 1.0)


func test_start_slows_and_stop_restores() -> void:
	var photo: PhotoFinish = PhotoFinish.new()
	add_child_autofree(photo)
	watch_signals(photo)
	photo.start()
	assert_true(photo.active)
	assert_eq(Engine.time_scale, PhotoFinish.SLOW_SCALE)
	assert_signal_emitted(photo, "started")
	photo.stop()
	assert_false(photo.active)
	assert_eq(Engine.time_scale, 1.0)
	assert_signal_emitted(photo, "ended")


func test_leaving_the_tree_restores_speed() -> void:
	var photo: PhotoFinish = PhotoFinish.new()
	add_child(photo)
	photo.start()
	remove_child(photo)
	photo.free()
	assert_eq(Engine.time_scale, 1.0)


func test_camera_hold_ignores_follow_until_released() -> void:
	var camera: RaceCamera = RaceCamera.new()
	add_child_autofree(camera)
	camera.hold_on(Vector2(500.0, 500.0))
	assert_true(camera.is_holding())
	camera.follow({0: Vector2(100, 100)}, {0: 0.1})
	assert_true(camera.is_holding())
	camera.release_hold()
	assert_false(camera.is_holding())
	camera.hold_on(Vector2(500.0, 500.0))
	camera.show_overview()
	assert_false(camera.is_holding(), "overview ends the hold")
