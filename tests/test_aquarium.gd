extends GutTest
## The aquarium: who is in it and how the fake 3D behaves.


func _points() -> PointsStore:
	var points := PointsStore.new()
	points.set_name("1", "Zed")
	points.set_name("2", "amy")
	points.add_win("3")
	points.stats.record_race("4")
	return points


func test_roster_has_everyone_the_data_knows_sorted_by_name() -> void:
	var shop := ShopStore.new()
	shop.grant("5", ShopStore.KIND_HAT, "crown")
	var roster: Array[Contestant] = AquariumRoster.build(_points(), shop)
	assert_eq(roster.size(), 5)
	assert_eq(roster[0].display_name, "amy")
	var ids: Array[String] = []
	for who: Contestant in roster:
		ids.append(who.user_id)
	for id: String in ["1", "2", "3", "4", "5"]:
		assert_true(ids.has(id), "viewer %s has a fish" % id)


func test_roster_fish_wear_what_they_equipped() -> void:
	var points := PointsStore.new()
	points.set_name("1", "Amy")
	var shop := ShopStore.new()
	shop.grant("1", ShopStore.KIND_SPECIES, "pike")
	shop.equip("1", ShopStore.KIND_SPECIES, "pike")
	shop.grant("1", ShopStore.KIND_COLOR, "blue")
	shop.equip("1", ShopStore.KIND_COLOR, "blue")
	shop.grant("1", ShopStore.KIND_HAT, "tophat")
	shop.equip("1", ShopStore.KIND_HAT, "tophat")
	var who: Contestant = AquariumRoster.build(points, shop)[0]
	assert_eq(who.species, 2)
	assert_eq(who.color, Contestant.PALETTE[3])
	assert_eq(who.accessory, FishAccessory.Kind.TOP_HAT)
	assert_eq(AquariumRoster.describe(who), "pike, blue, tophat")


func test_empty_data_gives_an_empty_roster() -> void:
	assert_eq(AquariumRoster.build(PointsStore.new(), ShopStore.new()).size(), 0)
	assert_eq(AquariumRoster.build(null, null).size(), 0)


func _roster(count: int) -> Array[Contestant]:
	var roster: Array[Contestant] = []
	for i: int in count:
		roster.append(Contestant.create("id%d" % i, "Fish %d" % i, i))
	return roster


func _make_tank(count: int) -> AquariumTank:
	var tank := AquariumTank.new(7)
	tank.size = Vector2(1280.0, 720.0)
	add_child_autofree(tank)
	tank.set_roster(_roster(count))
	return tank


func test_a_big_roster_is_capped_and_the_rest_wait() -> void:
	var tank: AquariumTank = _make_tank(130)
	assert_eq(tank.fish_total(), 130)
	assert_eq(tank.swimmers().size(), AquariumTank.MAX_FISH)
	assert_eq(tank.waiting().size(), 130 - AquariumTank.MAX_FISH)


func test_far_fish_are_smaller_and_follow_the_camera_less() -> void:
	var tank: AquariumTank = _make_tank(1)
	var fish: AquariumFish = tank.swimmers()[0]
	fish.z = 0.0
	var near: Dictionary = tank.project(fish)
	fish.z = 1.0
	var far: Dictionary = tank.project(fish)
	assert_gt(near["scale"], far["scale"])
	assert_eq(near["scale"], AquariumTank.NEAR_SCALE)


func test_fish_keep_swimming_inside_the_water() -> void:
	var tank: AquariumTank = _make_tank(10)
	for i: int in 600:
		tank._process(1.0 / 30.0)
	for fish: AquariumFish in tank.swimmers():
		assert_between(fish.z, 0.0, 1.0)
		assert_between(fish.depth_y, 0.05, 0.92)
		assert_between(fish.world_x, 0.0, tank.world_width_px())


func test_the_crowd_rotates_when_fish_are_waiting() -> void:
	var tank: AquariumTank = _make_tank(AquariumTank.MAX_FISH + 5)
	var before: Array[String] = []
	for fish: AquariumFish in tank.swimmers():
		before.append(fish.contestant.user_id)
	for i: int in int(AquariumTank.ROTATE_SECONDS * 30.0 * 4.0):
		tank._process(1.0 / 30.0)
	var changed: int = 0
	for fish: AquariumFish in tank.swimmers():
		if not before.has(fish.contestant.user_id):
			changed += 1
	assert_gt(changed, 0, "someone new took a turn")
	assert_eq(tank.swimmers().size(), AquariumTank.MAX_FISH)
	assert_eq(tank.swimmers().size() + tank.waiting().size(), AquariumTank.MAX_FISH + 5)


func test_home_has_an_aquarium_button_that_opens_the_screen() -> void:
	var home: HomeScreen = (load("res://scenes/ui/home_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(home)
	var button: Button = home.get_node("Center/Box/Aquarium")
	assert_eq(button.text, "AQUARIUM")
	assert_true(button.pressed.is_connected(home._on_aquarium_pressed))
	assert_true(load(HomeScreen.AQUARIUM_SCENE) is PackedScene)


func test_screen_shows_a_hint_when_nobody_exists_yet() -> void:
	var screen: AquariumScreen = (load(HomeScreen.AQUARIUM_SCENE) as PackedScene).instantiate()
	screen.roster = _roster(0)
	screen.use_roster = true
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_true((screen.get_node("Empty") as Label).visible)


func test_fish_with_a_trail_draw_it_behind_them() -> void:
	var tank: AquariumTank = _make_tank(2)
	var plain: AquariumFish = tank.swimmers()[0]
	var trailed: AquariumFish = tank.swimmers()[1]
	trailed.contestant.trail = FishTrail.Kind.STARS
	trailed.assign(trailed.contestant)
	trailed.z = 0.0
	trailed.world_x = 0.2
	plain.z = 0.0
	for i: int in 10:
		tank._process(1.0 / 30.0)
	assert_null(plain._trail, "the plain trail is left to the tank's own bubbles")
	assert_not_null(trailed._trail)
	assert_true(trailed._trail.top_level)
	assert_gt(
		trailed._trail.scale_amount_max,
		FishTrail.make(FishTrail.Kind.STARS).scale_amount_max,
		"near fish get bigger particles"
	)


func test_far_fish_do_not_emit_a_trail() -> void:
	var tank: AquariumTank = _make_tank(1)
	var fish: AquariumFish = tank.swimmers()[0]
	fish.contestant.trail = FishTrail.Kind.RAINBOW
	fish.assign(fish.contestant)
	fish.fade = 1.0
	fish.world_x = 0.2
	fish.z = 1.0
	fish._target_z = 1.0
	fish.visual.frozen = true
	tank._process(1.0 / 30.0)
	assert_false(fish._trail.emitting)
