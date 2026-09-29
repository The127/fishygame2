class_name GameTestBase
extends GutTest
## Shared setup and helpers for the Game scene tests (test_game_*.gd).

const POINTS_PATH: String = "user://test_game_points.json"

var _game: Game
var _flow: GameFlow
var _betting: Betting
var _chaos: Chaos
var _race: Race
var _panel: ControlPanel
var _source: DebugChatSource


func before_each() -> void:
	_remove_points_files()
	_source = DebugChatSource.new()
	Chat.set_source(_source)
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Game
	_flow = _game.get_node("GameFlow") as GameFlow
	_betting = _game.get_node("Betting") as Betting
	_chaos = _game.get_node("Chaos") as Chaos
	_race = _game.get_node("Race") as Race
	_panel = _game.get_node("ControlPanel") as ControlPanel
	_betting.points_path = POINTS_PATH
	_chaos.points_path = POINTS_PATH
	_flow.max_players = 4
	_flow.countdown_seconds = 3
	_flow.podium_seconds = 5.0
	add_child_autofree(_game)


func after_each() -> void:
	_remove_points_files()


func _remove_points_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = ProjectSettings.globalize_path(POINTS_PATH + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _say(user_id: String, text: String) -> void:
	_source.inject(user_id, "User" + user_id, text)


func _join(count: int) -> void:
	for i: int in count:
		_say(str(i), "#join")


func _balance(user_id: String) -> int:
	return _betting.points.get_balance(user_id)


## Joins `count` players and runs the countdown into the race.
func _start_race(count: int) -> void:
	_join(count)
	assert_true(_flow.start_race(), "race should start")
	_flow.tick(float(_flow.countdown_seconds))
	assert_eq(_flow.state, GameFlow.State.RACING)


## Every marble crosses the finish, best place to worst in the given id order.
func _finish_marbles(order: Array[int]) -> void:
	var track: Track = _current_track()
	assert_not_null(track, "a track is loaded")
	for id: int in order:
		var marble: Marble = _marble(id)
		assert_not_null(marble, "marble %d exists" % id)
		track.marble_reached_finish.emit(marble)


func _current_track() -> Track:
	for child: Node in _game.get_children():
		if child is Track:
			return child as Track
	return null


func _marble(id: int) -> Marble:
	for marble: Marble in _race.get_marbles():
		if marble.id == id:
			return marble
	return null
