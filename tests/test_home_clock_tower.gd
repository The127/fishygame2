extends GutTest
## The clock tower in the home screen backdrop: local time, closed on Sundays.


func _make_tower() -> HomeClockTower:
	var tower: HomeClockTower = HomeClockTower.new()
	add_child_autofree(tower)
	tower.set_process(false)
	return tower


func test_hand_angles_follow_the_time() -> void:
	var noon: Vector3 = HomeClockTower.angles_for(12, 0, 0)
	assert_almost_eq(noon, Vector3.ZERO, Vector3.ONE * 0.0001)
	var three: Vector3 = HomeClockTower.angles_for(15, 0, 0)
	assert_almost_eq(three.x, PI * 0.5, 0.0001, "15:00 points the hour hand at three")
	var half_past: Vector3 = HomeClockTower.angles_for(6, 30, 15)
	assert_almost_eq(half_past.y, PI + PI / 120.0, 0.0001, "minute hand creeps with the seconds")
	assert_almost_eq(half_past.z, PI * 0.5, 0.0001)
	assert_gt(half_past.x, PI, "hour hand sits past six at half past")


func test_closed_only_on_sundays() -> void:
	assert_true(HomeClockTower.is_closed_on(Time.WEEKDAY_SUNDAY))
	for day: int in [
		Time.WEEKDAY_MONDAY,
		Time.WEEKDAY_TUESDAY,
		Time.WEEKDAY_WEDNESDAY,
		Time.WEEKDAY_THURSDAY,
		Time.WEEKDAY_FRIDAY,
		Time.WEEKDAY_SATURDAY,
	]:
		assert_false(HomeClockTower.is_closed_on(day), "open on day %d" % day)


func test_weekday_shows_the_time() -> void:
	var tower: HomeClockTower = _make_tower()
	tower.set_clock({"weekday": Time.WEEKDAY_WEDNESDAY, "hour": 10, "minute": 9, "second": 30})
	assert_false(tower.closed)
	assert_almost_eq(tower.hand_angles, HomeClockTower.angles_for(10, 9, 30), Vector3.ONE * 0.0001)
	assert_false(tower.get_node("ClosedSign").visible)
	assert_true((tower.get_node("Bubbles") as CPUParticles3D).emitting)


func test_sunday_closes_the_tower() -> void:
	var tower: HomeClockTower = _make_tower()
	tower.set_clock({"weekday": Time.WEEKDAY_SUNDAY, "hour": 10, "minute": 9, "second": 30})
	assert_true(tower.closed)
	assert_eq(
		tower.hand_angles,
		Vector3(HomeClockTower.CLOSED_HOUR_ANGLE, HomeClockTower.CLOSED_MINUTE_ANGLE, 0.0),
		"hands stop"
	)
	assert_true(tower.get_node("ClosedSign").visible)
	assert_eq((tower.get_node("ClosedSign/Label") as Label3D).text, "CLOSED")
	var face: ShaderMaterial = (tower.get_node("Face0") as MeshInstance3D).mesh.material
	assert_eq(face.get_shader_parameter("lit"), 0.0, "face goes dark")
	tower.set_clock({"weekday": Time.WEEKDAY_MONDAY, "hour": 0, "minute": 0, "second": 1})
	assert_false(tower.closed, "opens again on Monday")
	assert_false(tower.get_node("ClosedSign").visible)
	assert_eq(face.get_shader_parameter("lit"), 1.0)


func test_home_backdrop_has_the_tower() -> void:
	var home: HomeScreen = (
		(load("res://scenes/ui/home_screen.tscn") as PackedScene).instantiate() as HomeScreen
	)
	add_child_autofree(home)
	var scene: HomeScene3D = home.get_node("Scene3D")
	assert_not_null(scene.clock_tower)
	assert_true(scene.clock_tower.is_inside_tree())
	assert_gt(scene.clock_tower.position.x, 0.0, "stands on the right")
