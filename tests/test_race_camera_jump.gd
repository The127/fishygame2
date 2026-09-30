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


func test_camera_follows_down_a_map_several_screens_tall() -> void:
	var camera: RaceCamera = RaceCamera.new()
	add_child_autofree(camera)
	var bounds: Rect2 = Rect2(0.0, -160.0, 1920.0, 2840.0)
	camera.set_bounds(bounds)
	camera.show_overview(true)
	assert_lt(camera.zoom.x, 0.5, "the overview zooms out to fit the whole map")
	assert_almost_eq(camera._center.y, bounds.get_center().y, 1.0)
	var y: float = 100.0
	for i: int in 2400:
		y += 1.0
		camera.follow({0: Vector2(900.0, y)}, {0: y / 2600.0})
		camera._process(1.0 / 60.0)
	assert_gt(camera._center.y, 1800.0, "the view has followed the fish down the map")
	assert_lte(camera._center.y + 540.0 / camera.zoom.x, bounds.end.y + 1.0, "and stays inside")
