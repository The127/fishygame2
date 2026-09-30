extends GutTest
## The random-event catalog and its wheel.


func test_wheel_is_mostly_nothing() -> void:
	var slices: Array[String] = RaceEvent.wheel(true)
	var events: int = 0
	for id: String in slices:
		if RaceEvent.is_event(id):
			events += 1
	assert_gt(events, 0, "some slices are modifiers")
	assert_lt(events * 2, slices.size(), "most slices are nothing")


func test_wheel_offers_every_event_when_hazards_are_on() -> void:
	var slices: Array[String] = RaceEvent.wheel(true)
	for id: String in RaceEvent.EVENTS:
		assert_true(slices.has(id), "%s is on the wheel" % id)


func test_wheel_drops_double_hazards_when_hazards_are_off() -> void:
	var slices: Array[String] = RaceEvent.wheel(false)
	assert_false(slices.has(RaceEvent.DOUBLE_HAZARDS))
	assert_eq(slices.size(), RaceEvent.wheel(true).size())


func test_spin_stays_inside_the_wheel_and_is_seeded() -> void:
	var slices: Array[String] = RaceEvent.wheel(true)
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 42
	b.seed = 42
	for i: int in 50:
		var index: int = RaceEvent.spin(slices, a)
		assert_between(index, 0, slices.size() - 1)
		assert_eq(index, RaceEvent.spin(slices, b))


func test_double_hazards_doubles_the_level_up_to_the_maximum() -> void:
	assert_eq(RaceEvent.hazard_level(RaceEvent.DOUBLE_HAZARDS, 2), 4)
	assert_eq(RaceEvent.hazard_level(RaceEvent.DOUBLE_HAZARDS, 4), RaceEvent.MAX_HAZARD_LEVEL)
	assert_eq(RaceEvent.hazard_level(RaceEvent.DOUBLE_HAZARDS, 0), 0, "off stays off")
	assert_eq(RaceEvent.hazard_level(RaceEvent.NOTHING, 3), 3)
	assert_eq(RaceEvent.hazard_level(RaceEvent.LOW_GRAVITY, 3), 3)


func test_other_modifiers_only_change_their_own_rule() -> void:
	assert_lt(RaceEvent.gravity_scale(RaceEvent.LOW_GRAVITY), 1.0)
	assert_eq(RaceEvent.gravity_scale(RaceEvent.BOUNCY), 1.0)
	assert_gt(RaceEvent.bounce(RaceEvent.BOUNCY), 0.0)
	assert_lt(RaceEvent.bounce(RaceEvent.NOTHING), 0.0)
	assert_ne(RaceEvent.track_tint(RaceEvent.LIGHTS_OUT), Color.WHITE)
	assert_eq(RaceEvent.track_tint(RaceEvent.NOTHING), Color.WHITE)
	assert_gt(RaceEvent.glow_scale(RaceEvent.LIGHTS_OUT), 1.0)
	assert_eq(RaceEvent.glow_scale(RaceEvent.NOTHING), 1.0)


func test_every_event_has_display_text() -> void:
	for id: String in RaceEvent.EVENTS:
		assert_ne(RaceEvent.name_of(id), "")
		assert_ne(RaceEvent.blurb_of(id), "")
		assert_ne(RaceEvent.short_of(id), "")
	assert_eq(RaceEvent.name_of(RaceEvent.NOTHING), "Nothing")
