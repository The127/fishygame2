extends GutTest
## GameFlow hands the last finisher a participation trophy on a lucky race.

var _flow: GameFlow
var _source: DebugChatSource
var _chat: Node


func before_each() -> void:
	_flow = GameFlow.new()
	_flow.countdown_seconds = 3
	add_child_autofree(_flow)
	_chat = load("res://scripts/chat/chat.gd").new()
	add_child_autofree(_chat)
	_source = DebugChatSource.new()
	_chat.set_source(_source)
	_chat.command_received.connect(_flow.handle_command)


func _race(count: int) -> void:
	_flow.max_players = count
	_flow.open_lobby()
	for i: int in count:
		_source.inject(str(i), "P%d" % i, "#join")
	_flow.start_race()
	_flow.tick(3.0)


## Results in the order of `ids`, all finished.
func _results(ids: Array[int]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for i: int in ids.size():
		results.append({"id": ids[i], "place": i + 1, "finished": true, "time": 10.0 + i})
	return results


func test_trophy_goes_to_the_last_finisher_before_the_podium() -> void:
	_flow.participation_chance = 1.0
	_race(5)
	watch_signals(_flow)
	var results: Array[Dictionary] = _results([4, 3, 2, 1, 0])
	results[4]["finished"] = false
	_flow.report_race_finished(results)
	assert_signal_emitted(_flow, "participation_trophy")
	var entry: Dictionary = get_signal_parameters(_flow, "participation_trophy", 0)[0]
	assert_eq(entry["name"], "P1", "last fish that finished, not the DNF")
	assert_eq(entry["place"], 4)
	assert_eq(entry["user_id"], "1")
	assert_eq(get_signal_parameters(_flow, "podium_ready", 0)[0].size(), 3)


func test_no_trophy_without_luck() -> void:
	_flow.participation_chance = 0.0
	_race(5)
	watch_signals(_flow)
	_flow.report_race_finished(_results([4, 3, 2, 1, 0]))
	assert_signal_not_emitted(_flow, "participation_trophy")


func test_no_trophy_when_every_finisher_is_on_the_podium() -> void:
	_flow.participation_chance = 1.0
	_race(3)
	watch_signals(_flow)
	_flow.report_race_finished(_results([2, 1, 0]))
	assert_signal_not_emitted(_flow, "participation_trophy")
	assert_signal_emitted(_flow, "podium_ready")
