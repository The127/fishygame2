extends GutTest
## Home screen layout and marble wrapping.


func _make_marbles(area: Vector2) -> HomeMarbles:
	var marbles: HomeMarbles = HomeMarbles.new()
	add_child_autofree(marbles)
	marbles.size = area
	return marbles


func test_marbles_wait_for_a_size_before_spawning() -> void:
	var marbles: HomeMarbles = _make_marbles(Vector2.ZERO)
	marbles._process(0.016)
	assert_eq(marbles._marbles.size(), 0, "no spawn while the size is zero")
	marbles.size = Vector2(800, 600)
	marbles._process(0.016)
	assert_eq(marbles._marbles.size(), HomeMarbles.MARBLE_COUNT)
	var xs: Dictionary = {}
	for marble: Dictionary in marbles._marbles:
		xs[snappedf(Vector2(marble["pos"]).x, 1.0)] = true
	assert_gt(xs.size(), 1, "marbles are spread out, not clustered")


func test_wrap_keeps_positions_inside_margin() -> void:
	var marbles: HomeMarbles = _make_marbles(Vector2(800, 600))
	marbles._process(0.016)
	var m: float = HomeMarbles.WRAP_MARGIN
	var wrapped: Vector2 = marbles._wrap(Vector2(800 + m + 10.0, -m - 10.0))
	assert_almost_eq(wrapped.x, -m + 10.0, 0.001)
	assert_almost_eq(wrapped.y, 600.0 + m - 10.0, 0.001)
	var inside: Vector2 = Vector2(100, 200)
	assert_eq(marbles._wrap(inside), inside, "positions in range are unchanged")


func test_title_fits_narrow_window() -> void:
	var home: HomeScreen = (load("res://scenes/ui/home_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(home)
	home.set_deferred("size", Vector2(500, 700))
	await wait_process_frames(4)
	var title: Label = home.get_node("Center/Box/Title")
	var rect: Rect2 = title.get_global_rect()
	assert_gte(rect.position.x, 0.0)
	assert_lte(rect.end.x, 500.0, "title stays inside a 500px window")
	assert_lt(title.get_theme_font_size("font_size"), HomeScreen.TITLE_FONT_SIZE)
