extends GutTest
## The impostor duck's bookkeeping: scored results without it and the podium with it.


func _result(id: int, place: int, finished: bool = true) -> Dictionary:
	return {
		"id": id,
		"place": place,
		"finished": finished,
		"time": 10.0 + place if finished else -1.0,
		"progress": 1.0
	}


func _podium_entry(id: int, place: int) -> Dictionary:
	return {"id": id, "place": place, "user_id": str(id), "name": "P%d" % id, "finished": true}


func test_scored_results_drop_the_duck_and_close_up_the_places() -> void:
	var results: Array[Dictionary] = [_result(1, 1), _result(3, 2), _result(0, 3), _result(2, 4)]
	var scored: Array[Dictionary] = ImpostorDuck.scored(results, 3)
	var ids: Array[int] = []
	var places: Array[int] = []
	for r: Dictionary in scored:
		ids.append(int(r["id"]))
		places.append(int(r["place"]))
	assert_eq(ids, [1, 0, 2])
	assert_eq(places, [1, 2, 3])
	assert_eq(int(results[2]["place"]), 3, "the original results are left alone")


func test_scored_results_without_a_duck_are_unchanged() -> void:
	var results: Array[Dictionary] = [_result(0, 1), _result(1, 2)]
	assert_eq(ImpostorDuck.scored(results, -1), results)


func test_a_winning_duck_takes_the_top_step_and_pushes_the_rest_down() -> void:
	var results: Array[Dictionary] = [_result(3, 1), _result(0, 2), _result(1, 3), _result(2, 4)]
	var podium: Array[Dictionary] = [_podium_entry(0, 1), _podium_entry(1, 2), _podium_entry(2, 3)]
	var shown: Array[Dictionary] = ImpostorDuck.display_podium(podium, results, 3, 3)
	assert_eq(shown.size(), 3)
	assert_eq(str(shown[0]["name"]), ImpostorDuck.NAME)
	assert_true(bool(shown[0]["impostor"]))
	assert_eq(str(shown[0]["user_id"]), "", "the duck is nobody")
	assert_eq(float(shown[0]["time"]), 11.0)
	assert_eq([int(shown[1]["id"]), int(shown[1]["place"])], [0, 2])
	assert_eq([int(shown[2]["id"]), int(shown[2]["place"])], [1, 3])
	assert_eq(int(podium[0]["place"]), 1, "the scored podium is left alone")


func test_a_duck_off_the_podium_or_unfinished_changes_nothing() -> void:
	var podium: Array[Dictionary] = [_podium_entry(0, 1), _podium_entry(1, 2), _podium_entry(2, 3)]
	var fourth: Array[Dictionary] = [_result(0, 1), _result(1, 2), _result(2, 3), _result(3, 4)]
	assert_eq(ImpostorDuck.display_podium(podium, fourth, 3, 3), podium)
	var dnf: Array[Dictionary] = [_result(0, 1), _result(1, 2), _result(2, 3), _result(3, 4, false)]
	assert_eq(ImpostorDuck.display_podium(podium, dnf, 3, 3), podium)


func test_a_duck_alone_at_the_finish_gets_the_podium_to_itself() -> void:
	var results: Array[Dictionary] = [_result(1, 1), _result(0, 2, false)]
	var shown: Array[Dictionary] = ImpostorDuck.display_podium([], results, 1, 3)
	assert_eq(shown.size(), 1)
	assert_eq(int(shown[0]["place"]), 1)


func test_chance_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 50:
		assert_false(ImpostorDuck.joins(rng, 0))
		assert_true(ImpostorDuck.joins(rng, 100))


func test_the_podium_draws_a_duck_for_the_impostor() -> void:
	var view := PodiumView.new()
	add_child_autofree(view)
	view.set_podium([ImpostorDuck.entry(5, 1, 12.0)] as Array[Dictionary])
	var fish: Array[Node] = view.find_children("*", "FishVisual", true, false)
	assert_eq(fish.size(), 1)
	assert_true((fish[0] as FishVisual).impostor)
