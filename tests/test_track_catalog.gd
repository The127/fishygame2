extends GutTest

const MARBLE_RADIUS: float = 14.0


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_has_at_least_two_maps_with_unique_ids() -> void:
	var ids: PackedStringArray = TrackCatalog.ids()
	assert_gte(ids.size(), 2)
	var seen: Dictionary = {}
	for id: String in ids:
		assert_false(seen.has(id), "duplicate id %s" % id)
		seen[id] = true
		assert_ne(TrackCatalog.get_name_of(id), "")


func test_every_map_has_music_ambience_and_jingle_files() -> void:
	for id: String in TrackCatalog.ids():
		for path: String in [
			TrackCatalog.music_path(id),
			TrackCatalog.ambience_path(id),
			TrackCatalog.jingle_path(id)
		]:
			assert_ne(path, "", "no audio path for map %s" % id)
			assert_true(ResourceLoader.exists(path), "missing file %s" % path)


func test_unknown_id_has_no_audio_paths() -> void:
	assert_eq(TrackCatalog.music_path("nope"), "")
	assert_eq(TrackCatalog.ambience_path("nope"), "")
	assert_eq(TrackCatalog.jingle_path("nope"), "")


func test_every_map_instantiates_a_track() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = TrackCatalog.instantiate(id)
		assert_not_null(track, id)
		track.free()


func test_unknown_id_instantiates_nothing() -> void:
	assert_null(TrackCatalog.instantiate("nope"))
	assert_eq(TrackCatalog.get_name_of("nope"), "")


func test_resolve_keeps_a_known_choice() -> void:
	for id: String in TrackCatalog.ids():
		assert_eq(TrackCatalog.resolve(id, _rng(1), "other"), id)


func test_resolve_random_covers_all_maps() -> void:
	var rng: RandomNumberGenerator = _rng(3)
	var seen: Dictionary = {}
	for i: int in 50:
		seen[TrackCatalog.resolve(TrackCatalog.RANDOM_ID, rng)] = true
	assert_eq(seen.size(), TrackCatalog.ids().size())


func test_resolve_random_avoids_the_previous_map() -> void:
	var rng: RandomNumberGenerator = _rng(4)
	for id: String in TrackCatalog.ids():
		for i: int in 20:
			assert_ne(TrackCatalog.resolve(TrackCatalog.RANDOM_ID, rng, id), id)


func test_maps_have_a_layout_of_their_own() -> void:
	var lengths: Dictionary = {}
	for id: String in TrackCatalog.ids():
		var track: Track = TrackCatalog.instantiate(id)
		add_child_autofree(track)
		var curve: Curve2D = (track.get_node("Centerline") as Path2D).curve
		lengths[snappedf(curve.get_baked_length(), 1.0)] = true
	assert_eq(lengths.size(), TrackCatalog.ids().size(), "maps share a centerline length")


func test_track_contract_and_spawn_slots() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = TrackCatalog.instantiate(id)
		add_child_autofree(track)
		var finish: Area2D = track.get_node("Finish") as Area2D
		assert_not_null(finish, id)
		var last: float = -1.0
		# 20 is the default lobby size; every slot must sit inside the viewport and
		# start at (or near) the beginning of the centerline.
		for i: int in 20:
			var pos: Vector2 = track.get_spawn_position(i)
			assert_true(
				pos.x > MARBLE_RADIUS and pos.x < 1920.0 - MARBLE_RADIUS, "%s slot %d x" % [id, i]
			)
			assert_lt(pos.y, 1080.0, "%s slot %d y" % [id, i])
			last = maxf(last, track.get_progress(pos))
		assert_lt(last, 0.2, "%s spawn slots are near the start" % id)
		assert_gt(track.get_progress(finish.global_position), 0.9, "%s finish is at the end" % id)


func _make_game() -> Game:
	var game: Game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Game
	add_child_autofree(game)
	return game


func _track_of(game: Game) -> Track:
	for child: Node in game.get_children():
		if child is Track:
			return child as Track
	return null


func _map_scene_path(game: Game) -> String:
	return _track_of(game).scene_file_path


func test_game_opens_with_a_track_in_the_lobby() -> void:
	var game: Game = _make_game()
	assert_not_null(_track_of(game))


func test_panel_choice_swaps_the_track_during_the_lobby() -> void:
	var game: Game = _make_game()
	var panel: ControlPanel = game.get_node("ControlPanel") as ControlPanel
	for id: String in TrackCatalog.ids():
		panel.map_selected.emit(id)
		var expected: String = autofree(TrackCatalog.instantiate(id)).scene_file_path
		assert_eq(_map_scene_path(game), expected, id)
		await get_tree().process_frame
		var tracks: int = (
			game.get_children().filter(func(n: Node) -> bool: return n is Track).size()
		)
		assert_eq(tracks, 1, "old track left behind")


func test_random_choice_never_repeats_the_last_map() -> void:
	var game: Game = _make_game()
	var flow: GameFlow = game.get_node("GameFlow") as GameFlow
	var panel: ControlPanel = game.get_node("ControlPanel") as ControlPanel
	panel.map_selected.emit(TrackCatalog.RANDOM_ID)
	var previous: String = _map_scene_path(game)
	for i: int in 10:
		flow.stop()
		flow.open_lobby()
		assert_ne(_map_scene_path(game), previous)
		previous = _map_scene_path(game)
