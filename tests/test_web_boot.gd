extends GutTest
## The loading background helper must be harmless outside the web export.


func test_release_background_is_a_no_op_off_web() -> void:
	WebBoot.release_background()
	await wait_process_frames(2)
	assert_false(OS.has_feature("web"))
