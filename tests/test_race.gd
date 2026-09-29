extends GutTest

const TRACK_SCENE: String = "res://scenes/tracks/test_track.tscn"
const MARBLE_SCENE: String = "res://scenes/marble.tscn"


func _make_race() -> Array:
	var track: Track = (load(TRACK_SCENE) as PackedScene).instantiate() as Track
	add_child_autofree(track)
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(race)
	return [race, track]


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_restart_replaces_marbles_and_ignores_stale_finish() -> void:
	var parts: Array = _make_race()
	var race: Race = parts[0] as Race
	var track: Track = parts[1] as Track
	race.start(track, 4, _rng(1))
	var old: Marble = race.get_marbles()[0]
	race.start(track, 4, _rng(1))
	assert_eq(race.get_marbles().size(), 4)
	assert_false(race.get_marbles().has(old))
	watch_signals(race)
	track.marble_reached_finish.emit(old)
	assert_signal_not_emitted(race, "marble_finished")


func test_finish_signal_reports_place() -> void:
	var parts: Array = _make_race()
	var race: Race = parts[0] as Race
	var track: Track = parts[1] as Track
	race.start(track, 3, _rng(2))
	watch_signals(race)
	var marbles: Array[Marble] = race.get_marbles()
	track.marble_reached_finish.emit(marbles[2])
	assert_signal_emitted_with_parameters(race, "marble_finished", [2, 1])
