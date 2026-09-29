extends GutTest
## The podium draws steps for places 1 to 3 and puts each winner's fish on their own step.


func _entry(place: int, id: int) -> Dictionary:
	return {
		"id": id,
		"place": place,
		"user_id": "u%d" % id,
		"name": "P%d" % id,
		"color": Color.RED,
		"time": 12.5,
		"finished": true,
	}


func _make(entries: Array[Dictionary]) -> PodiumView:
	var view := PodiumView.new()
	add_child_autofree(view)
	view.set_podium(entries)
	return view


func test_fish_stand_on_their_steps_with_first_in_the_middle() -> void:
	var view: PodiumView = _make([_entry(1, 4), _entry(2, 7), _entry(3, 1)])
	var fish: Array[Node] = view.find_children("*", "FishVisual", false, false)
	assert_eq(fish.size(), 3)
	var by_species: Dictionary = {}
	for f: FishVisual in fish:
		by_species[f.species] = f
	assert_eq(by_species[4].position.x, view.step_rect(1).get_center().x)
	assert_eq(by_species[7].position.x, view.step_rect(2).get_center().x)
	assert_true(view.step_rect(2).position.x < view.step_rect(1).position.x)
	assert_true(view.step_rect(1).position.x < view.step_rect(3).position.x)
	assert_true(view.step_rect(1).position.y < view.step_rect(2).position.y)
	assert_false(by_species[4].top_level)


func test_fewer_than_three_finishers_leave_steps_empty() -> void:
	var view: PodiumView = _make([_entry(1, 0)])
	assert_eq(view.find_children("*", "FishVisual", false, false).size(), 1)


func test_set_podium_replaces_previous_winners() -> void:
	var view: PodiumView = _make([_entry(1, 0), _entry(2, 1)])
	view.set_podium([_entry(1, 2)])
	await wait_frames(2)
	assert_eq(view.find_children("*", "FishVisual", false, false).size(), 1)
