class_name GameTestBase
extends GutTest
## Shared setup and helpers for the Game scene tests (test_game_*.gd).

const POINTS_PATH: String = "user://test_game_points.json"
const SHOP_PATH: String = "user://test_game_shop.json"

var _game: Game
var _flow: GameFlow
var _betting: Betting
var _chaos: Chaos
var _shop: Shop
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
	_shop = _game.get_node("Shop") as Shop
	_race = _game.get_node("Race") as Race
	_panel = _game.get_node("ControlPanel") as ControlPanel
	_betting.points_path = POINTS_PATH
	_chaos.points_path = POINTS_PATH
	_shop.shop_path = SHOP_PATH
	_game.settings = GameSettings.new()
	_game.settings.max_players = 4
	_game.settings.welcome_hat = false
	# Placement rewards have their own tests; the rest assert exact balances.
	_game.settings.win_reward = 0
	_game.settings.second_reward = 0
	_game.settings.third_reward = 0
	_game.settings.countdown_seconds = 3
	_flow.podium_seconds = 5.0
	_game.settings.finish_replay = GameSettings.REPLAY_OFF
	_configure(_game.settings)
	add_child_autofree(_game)


## Override to change the settings before the game scene starts.
func _configure(_settings: GameSettings) -> void:
	pass


func after_each() -> void:
	_remove_points_files()


func _remove_points_files() -> void:
	for base: String in [POINTS_PATH, SHOP_PATH]:
		for suffix: String in ["", ".tmp", ".bak"]:
			var path: String = ProjectSettings.globalize_path(base + suffix)
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
