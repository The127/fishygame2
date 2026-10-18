extends GutTest
## Cardboard cutout fish: when they fill in, how many, and how they leave and rejoin the results.

const SETTINGS_PATH: String = "user://test_cardboard_settings.cfg"


func after_each() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _results(ids: Array[int]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for i: int in ids.size():
		results.append({"id": ids[i], "place": i + 1, "finished": true, "time": 10.0 + i})
	return results


func test_count_fills_up_to_the_target_below_three_viewers() -> void:
	assert_eq(CardboardCutouts.count_for(1, 5, 20), 4)
	assert_eq(CardboardCutouts.count_for(2, 10, 20), 8)
	assert_eq(CardboardCutouts.count_for(3, 5, 20), 0, "three viewers race on their own")
	assert_eq(CardboardCutouts.count_for(1, 0, 20), 0, "off")
	assert_eq(CardboardCutouts.count_for(1, 10, 4), 3, "never past the lobby size")


func test_line_up_takes_the_ids_after_the_field_with_different_names() -> void:
	var cutouts := CardboardCutouts.new()
	# Two viewers and the duck (id 2) already lined up.
	assert_eq(cutouts.line_up(3, 2, 10, 20), 11)
	assert_eq(cutouts.names.size(), 8)
	assert_false(cutouts.names.has(2))
	assert_true(cutouts.names.has(3))
	assert_true(cutouts.names.has(10))
	var unique: Dictionary = {}
	for name: String in cutouts.names.values():
		unique[name] = true
	assert_eq(unique.size(), 8)
	assert_eq(cutouts.line_up(3, 3, 10, 20), 3, "a fresh race forgets the old cutouts")
	assert_true(cutouts.names.is_empty())


func test_settle_drops_the_cutouts_and_the_podium_puts_them_back() -> void:
	var cutouts := CardboardCutouts.new()
	cutouts.line_up(1, 1, 5, 20)
	# Cutout 3 wins, the viewer (id 0) is second, cutout 1 third.
	var scored: Array[Dictionary] = cutouts.settle(_results([3, 0, 1, 2, 4]))
	assert_eq(scored.size(), 1)
	assert_eq(int(scored[0]["id"]), 0)
	assert_eq(int(scored[0]["place"]), 1, "scoring sees the viewer as the winner")
	var podium: Array[Dictionary] = [
		{"id": 0, "place": 1, "user_id": "v", "name": "Viewer", "finished": true, "time": 11.0}
	]
	var shown: Array[Dictionary] = cutouts.podium_with_cutouts(podium, 3)
	assert_eq(shown.size(), 3)
	assert_eq(int(shown[0]["id"]), 3)
	assert_true(bool(shown[0]["cardboard"]))
	assert_eq(str(shown[0]["user_id"]), "", "a cutout is nobody")
	assert_eq(str(shown[0]["name"]), cutouts.names[3])
	assert_eq(int(shown[1]["id"]), 0)
	assert_eq(int(shown[1]["place"]), 2)
	assert_eq(int(shown[2]["id"]), 1)
	assert_eq(int(shown[2]["place"]), 3)


func test_settings_default_on_with_five_and_round_trip() -> void:
	var settings := GameSettings.new(SETTINGS_PATH)
	assert_true(settings.cardboard_fish)
	assert_eq(settings.cardboard_target(), 5)
	settings.cardboard_fill = GameSettings.CARDBOARD_TEN
	settings.cardboard_fish = false
	assert_eq(settings.cardboard_target(), 0)
	assert_true(settings.save())
	var loaded := GameSettings.new(SETTINGS_PATH)
	loaded.load_settings()
	assert_false(loaded.cardboard_fish)
	assert_eq(loaded.cardboard_fill, GameSettings.CARDBOARD_TEN)
	loaded.cardboard_fish = true
	assert_eq(loaded.cardboard_target(), 10)
	loaded.reset_to_defaults()
	assert_true(loaded.cardboard_fish)
	assert_eq(loaded.cardboard_target(), 5)


func test_cutout_outline_never_crosses_itself() -> void:
	for seed: int in 200:
		var cutout := CardboardFish.new()
		cutout.cut_seed = seed
		var outline: PackedVector2Array = cutout.get("_outline")
		assert_false(Geometry2D.triangulate_polygon(outline).is_empty(), "seed %d" % seed)
		cutout.free()
