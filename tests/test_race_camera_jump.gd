extends GutTest
## The camera glides after a followed fish that a portal sent across the map.


func _camera() -> RaceCamera:
	var camera: RaceCamera = RaceCamera.new()
	add_child_autofree(camera)
	camera.set_bounds(Rect2(0.0, -160.0, 1920.0, 1240.0))
	return camera


func _follow(camera: RaceCamera, at: Vector2) -> void:
	camera.follow({0: at}, {0: 0.5})


func test_a_teleport_does_not_lurch_the_view() -> void:
	var camera: RaceCamera = _camera()
	_follow(camera, Vector2(1700.0, 400.0))
	for i: int in 120:
		camera.follow({0: Vector2(1700.0, 400.0)}, {0: 0.5})
		camera._process(1.0 / 60.0)
	var far: Vector2 = Vector2(800.0, 450.0)
	var worst: float = 0.0
	var before: Vector2 = camera._center
	for i: int in 180:
		camera.follow({0: far}, {0: 0.6})
		camera._process(1.0 / 60.0)
		worst = maxf(worst, camera._center.distance_to(before) * 60.0)
		before = camera._center
	assert_lte(worst, RaceCamera.JUMP_PAN_SPEED + 1.0, "pan speed stays capped")
	assert_lt(camera._center.distance_to(far), 250.0, "and it arrives within three seconds")


func test_ordinary_following_is_not_slowed() -> void:
	var camera: RaceCamera = _camera()
	_follow(camera, Vector2(600.0, 300.0))
	camera.follow({0: Vector2(700.0, 330.0)}, {0: 0.5})
	assert_eq(camera._jump_left, 0.0)
