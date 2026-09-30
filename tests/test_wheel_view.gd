extends GutTest
## The random-event wheel lands on the slice it was told to.


func test_wheel_settles_on_the_chosen_slice() -> void:
	var slices: Array[String] = RaceEvent.wheel(true)
	for index: int in slices.size():
		var wheel := WheelView.new()
		add_child_autofree(wheel)
		wheel.spin(slices, index, 2.0)
		assert_false(wheel.is_settled())
		wheel._process(0.5)
		assert_false(wheel.is_settled(), "still turning after a quarter of the time")
		wheel._process(5.0)
		assert_true(wheel.is_settled())
		assert_eq(wheel.current_index(), index)


func test_angle_puts_the_slice_under_the_pointer() -> void:
	assert_almost_eq(WheelView.angle_for(0, 12), 0.0, 0.0001)
	assert_almost_eq(WheelView.angle_for(3, 12), -PI * 0.5, 0.0001)
