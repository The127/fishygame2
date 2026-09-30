extends GutTest
## The screen edges the streamer blocked out are drawn solid black.


func test_mask_is_opaque_black() -> void:
	assert_eq(BlockedMask.COLOR, Color(0.0, 0.0, 0.0, 1.0))


func test_overlay_has_a_mask_that_ignores_the_mouse() -> void:
	var overlay: Overlay = add_child_autofree(Overlay.new())
	overlay.set_play_fraction(Rect2(0.25, 0.1, 0.5, 0.8))
	var mask: BlockedMask = null
	for child: Node in overlay.get_children():
		if child is BlockedMask:
			mask = child
	assert_not_null(mask)
	assert_eq(mask.mouse_filter, Control.MOUSE_FILTER_IGNORE)
