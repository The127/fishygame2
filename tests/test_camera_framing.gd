extends GutTest

const VIEWPORT: Vector2 = Vector2(1920.0, 1080.0)
const BOUNDS: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)


func test_leader_group_drops_stragglers() -> void:
	var positions: Dictionary = {0: Vector2(100, 100), 1: Vector2(900, 500), 2: Vector2(950, 520)}
	var progress: Dictionary = {0: 0.05, 1: 0.6, 2: 0.62}
	var group: Array[Vector2] = CameraFraming.leader_group(positions, progress)
	assert_eq(group.size(), 2)
	assert_false(group.has(Vector2(100, 100)))


func test_leader_group_of_empty_field_is_empty() -> void:
	assert_eq(CameraFraming.leader_group({}, {}).size(), 0)


func test_focus_rect_has_margin_and_minimum_size() -> void:
	var points: Array[Vector2] = [Vector2(500, 500), Vector2(510, 505)]
	var rect: Rect2 = CameraFraming.focus_rect(points, 50.0, Vector2(640, 360))
	assert_almost_eq(rect.size.x, 640.0, 0.01)
	assert_almost_eq(rect.size.y, 360.0, 0.01)
	assert_true(rect.has_point(Vector2(505, 502)))
	assert_almost_eq(rect.get_center().x, 505.0, 0.01)


func test_focus_rect_grows_with_spread() -> void:
	var points: Array[Vector2] = [Vector2(0, 0), Vector2(1000, 400)]
	var rect: Rect2 = CameraFraming.focus_rect(points, 100.0, Vector2(640, 360))
	assert_eq(rect.size, Vector2(1200, 600))


func test_fit_zoom_is_clamped() -> void:
	assert_eq(CameraFraming.fit_zoom(Vector2(100, 100), VIEWPORT, 1.0, 2.0), 2.0)
	assert_eq(CameraFraming.fit_zoom(Vector2(5000, 5000), VIEWPORT, 1.0, 2.0), 1.0)
	assert_almost_eq(CameraFraming.fit_zoom(Vector2(1280, 720), VIEWPORT, 1.0, 2.0), 1.5, 0.001)


func test_clamp_center_keeps_view_inside_bounds() -> void:
	var center: Vector2 = CameraFraming.clamp_center(Vector2(0, 0), 2.0, VIEWPORT, BOUNDS)
	assert_eq(center, Vector2(480, 270))
	center = CameraFraming.clamp_center(Vector2(5000, 5000), 2.0, VIEWPORT, BOUNDS)
	assert_eq(center, Vector2(1440, 810))


func test_clamp_center_centers_when_view_exceeds_bounds() -> void:
	var center: Vector2 = CameraFraming.clamp_center(Vector2(0, 0), 1.0, VIEWPORT, BOUNDS)
	assert_eq(center, Vector2(960, 540))


func test_damping_is_frame_rate_independent() -> void:
	var one_step: float = CameraFraming.damping(3.0, 0.1)
	var two_steps: float = 1.0 - pow(1.0 - CameraFraming.damping(3.0, 0.05), 2.0)
	assert_almost_eq(one_step, two_steps, 0.0001)
	assert_eq(CameraFraming.damping(3.0, 0.0), 0.0)


func test_camera_follows_leader_and_returns_to_overview() -> void:
	var cam: RaceCamera = RaceCamera.new()
	add_child_autofree(cam)
	cam.show_overview(true)
	var positions: Dictionary = {0: Vector2(1500, 900), 1: Vector2(1520, 910)}
	var progress: Dictionary = {0: 0.8, 1: 0.81}
	cam.follow(positions, progress)
	for i: int in 300:
		cam._process(1.0 / 60.0)
	assert_gt(cam.zoom.x, 1.4, "zooms in on the group")
	assert_gt(cam.global_position.x, 1200.0, "moves toward the group")
	cam.show_overview()
	for i: int in 600:
		cam._process(1.0 / 60.0)
	assert_almost_eq(cam.zoom.x, 1.0, 0.01)
	assert_almost_eq(cam.global_position.x, 960.0, 1.0)


func test_camera_move_is_smooth() -> void:
	var cam: RaceCamera = RaceCamera.new()
	add_child_autofree(cam)
	cam.show_overview(true)
	cam.follow({0: Vector2(1500, 900)}, {0: 0.9})
	cam._process(1.0 / 60.0)
	assert_lt(cam.global_position.distance_to(Vector2(960, 540)), 40.0, "no jump in one frame")


func test_handover_scale_ramps_from_slow_to_normal() -> void:
	assert_almost_eq(CameraFraming.handover_scale(2.0, 2.0, 0.25), 0.25, 0.001)
	assert_eq(CameraFraming.handover_scale(0.0, 2.0, 0.25), 1.0)
	var mid: float = CameraFraming.handover_scale(1.0, 2.0, 0.25)
	assert_gt(mid, 0.25)
	assert_lt(mid, 1.0)


func test_finish_hands_over_slower_than_normal_follow() -> void:
	var normal: RaceCamera = RaceCamera.new()
	var handover: RaceCamera = RaceCamera.new()
	add_child_autofree(normal)
	add_child_autofree(handover)
	var lead: Dictionary = {0: Vector2(1500, 900), 1: Vector2(500, 300)}
	var progress: Dictionary = {0: 0.9, 1: 0.2}
	for cam: RaceCamera in [normal, handover]:
		cam.show_overview(true)
		cam.follow(lead, progress)
	# Fish 0 finishes: only the pack at the back remains.
	handover.follow({1: Vector2(500, 300)}, {1: 0.2})
	normal.follow({0: Vector2(1500, 900), 1: Vector2(500, 300)}, progress)
	normal._target_center = Vector2(500, 300)
	normal._target_zoom = handover._target_zoom
	var start: Vector2 = normal.global_position
	for i: int in 30:
		normal._process(1.0 / 60.0)
		handover._process(1.0 / 60.0)
	assert_lt(
		handover.global_position.distance_to(start),
		normal.global_position.distance_to(start),
		"a finish slows the hand-over"
	)


func test_per_frame_pan_is_capped_during_handover() -> void:
	var cam: RaceCamera = RaceCamera.new()
	add_child_autofree(cam)
	cam.show_overview(true)
	cam._target_center = Vector2(1900, 1000)
	cam._handover_left = RaceCamera.HANDOVER_TIME
	var before: Vector2 = cam.global_position
	cam._process(1.0)
	assert_lte(cam.global_position.distance_to(before), RaceCamera.MAX_PAN_SPEED + 0.01)


func test_play_shift_is_zero_for_the_whole_screen() -> void:
	assert_eq(CameraFraming.play_shift(Rect2(Vector2.ZERO, VIEWPORT), VIEWPORT), Vector2.ZERO)


func test_play_shift_points_towards_the_free_area() -> void:
	# Left quarter blocked: the play area's middle sits right of the screen's middle.
	var play := Rect2(480.0, 0.0, 1440.0, 1080.0)
	assert_eq(CameraFraming.play_shift(play, VIEWPORT), Vector2(240.0, 0.0))
