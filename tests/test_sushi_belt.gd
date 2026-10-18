extends GutTest
## The DNF fish ride past the podium on plates, once, within the podium's time.


func _fish(count: int) -> Array[Dictionary]:
	var fish: Array[Dictionary] = []
	for i: int in count:
		fish.append({"name": "P%d" % i, "color": Color.RED, "species": i, "fate": "stranded"})
	return fish


func _make(count: int, seconds: float = 8.0) -> SushiBelt:
	var belt := SushiBelt.new()
	add_child_autofree(belt)
	belt.serve(_fish(count), seconds)
	return belt


func test_each_fish_gets_a_plate_in_order() -> void:
	var belt: SushiBelt = _make(3)
	assert_eq(belt.plate_count(), 3)
	assert_eq(belt.find_children("*", "FishVisual", false, false).size(), 3)
	assert_true(belt.plate_x(0) > belt.plate_x(1), "the first fish leads")
	assert_true(belt.plate_x(0) > 0.0, "the first plate starts on the belt")


func test_too_many_fish_are_capped_and_counted() -> void:
	var belt: SushiBelt = _make(SushiBelt.MAX_PLATES + 3)
	assert_eq(belt.plate_count(), SushiBelt.MAX_PLATES)
	assert_eq(belt.hidden_count(), 3)


func test_every_plate_has_left_before_the_podium_ends() -> void:
	var belt: SushiBelt = _make(SushiBelt.MAX_PLATES, 8.0)
	for i: int in 76:
		belt._process(0.1)
	var last: int = belt.plate_count() - 1
	assert_true(belt.plate_x(last) - SushiBelt.TAG_SIZE.x * 0.5 >= SushiBelt.VIEW_SIZE.x)


func test_serving_again_replaces_the_plates() -> void:
	var belt: SushiBelt = _make(4)
	belt._process(1.0)
	belt.serve(_fish(1), 8.0)
	assert_eq(belt.plate_x(0), SushiBelt.TAG_SIZE.x * 0.5, "the new plate starts at the start")
	await wait_frames(2)
	assert_eq(belt.plate_count(), 1)
	assert_eq(belt.find_children("*", "FishVisual", false, false).size(), 1)


func test_price_tags_follow_the_fate() -> void:
	assert_string_contains(SushiBelt.price_tag("dissolved", "a"), "acid-cured")
	assert_string_contains(SushiBelt.price_tag("", "a"), "fresh catch")
	assert_string_contains(SushiBelt.price_tag("unknown", "a"), "fresh catch")
	assert_eq(SushiBelt.price_tag("snapped", "bob"), SushiBelt.price_tag("snapped", "bob"))
	assert_true(SushiBelt.price_tag("cut", "a").begins_with("¥"))
