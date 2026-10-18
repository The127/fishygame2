extends GutTest
## Victory dances: every dance moves the fish, stays on its step and keeps a usable transform.


func test_chat_names_map_to_kinds() -> void:
	assert_eq(FishDance.kind_of("Floss"), FishDance.Kind.FLOSS)
	assert_eq(FishDance.kind_of("worm"), FishDance.Kind.WORM)
	assert_eq(FishDance.kind_of("macarena"), FishDance.Kind.RANDOM)


func test_pick_keeps_a_chosen_dance_and_rolls_random_ones() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	assert_eq(FishDance.pick(FishDance.Kind.DAB, rng), FishDance.Kind.DAB)
	var seen: Dictionary = {}
	for i: int in 200:
		seen[FishDance.pick(FishDance.Kind.RANDOM, rng)] = true
	assert_eq(seen.size(), FishDance.NAMES.size(), "every dance comes up")
	assert_false(seen.has(FishDance.Kind.RANDOM))


func test_every_dance_moves_and_stays_on_the_step() -> void:
	for dance: int in range(1, FishDance.NAMES.size() + 1):
		var moved: bool = false
		var start: Dictionary = FishDance.pose(dance, 0.0)
		for i: int in 120:
			var p: Dictionary = FishDance.pose(dance, i * 0.05)
			var offset: Vector2 = p["offset"]
			var scale: Vector2 = p["scale"]
			assert_lte(absf(offset.x), 20.0, "%s stays on its step" % FishDance.NAMES[dance - 1])
			assert_lte(offset.y, 0.5, "%s never sinks into the step" % FishDance.NAMES[dance - 1])
			assert_gt(absf(scale.x), 0.0, "%s never collapses to zero" % FishDance.NAMES[dance - 1])
			if p != start:
				moved = true
		assert_true(moved, "%s moves" % FishDance.NAMES[dance - 1])


func test_floss_swaps_which_arm_is_in_front() -> void:
	var a: Dictionary = FishDance.pose(FishDance.Kind.FLOSS, 0.0)
	var b: Dictionary = FishDance.pose(FishDance.Kind.FLOSS, 0.45)
	assert_false(is_nan(a["front_arm"]))
	assert_gt(a["front_arm"], a["back_arm"])
	assert_lt(b["front_arm"], b["back_arm"])


func test_dab_throws_one_arm_up_and_switches_sides() -> void:
	var held: Dictionary = FishDance.pose(FishDance.Kind.DAB, 0.5)
	assert_lt(sin(held["front_arm"]), -0.3, "the thrown arm points up")
	assert_lt(cos(held["front_arm"]), -0.3, "and back, away from the snout")
	assert_gt(held["rotation"], 0.3, "the head ducks into the elbow")
	var other: Dictionary = FishDance.pose(FishDance.Kind.DAB, 1.9)
	assert_eq((other["scale"] as Vector2).x, -1.0)


func test_the_worm_has_no_arms() -> void:
	assert_true(is_nan(FishDance.pose(FishDance.Kind.WORM, 0.3)["front_arm"]))


func test_dancer_carries_the_fish_and_animates() -> void:
	var dancer := FishDance.new()
	dancer.kind = FishDance.Kind.FLOSS
	dancer.fish = FishVisual.new()
	add_child_autofree(dancer)
	assert_false(dancer.fish.top_level)
	assert_true(dancer.is_ancestor_of(dancer.fish))
	var before: Vector2 = dancer.fish.global_position
	await wait_seconds(0.2)
	assert_ne(dancer.fish.global_position, before)
