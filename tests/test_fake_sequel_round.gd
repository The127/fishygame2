extends GameTestBase
## The fake "Fishy Marble Run 3" round: the normal race and payouts, drawn in 3D.


func _configure(settings: GameSettings) -> void:
	_game.fake_sequel = true
	_game.home_scene = ""
	settings.hazards_enabled = true
	settings.treasures_enabled = true
	settings.default_map = "pachinko"


func test_round_is_drawn_in_3d_on_its_own_map() -> void:
	var view: Race3DView = _game.get_node_or_null("View3D")
	assert_not_null(view, "the 3D view is up")
	assert_false(_race.visible, "the 2D fish are hidden")
	var track: Track = _current_track()
	assert_not_null(track)
	assert_false(track.visible, "the 2D track is hidden")
	assert_eq(
		track.scene_file_path, TrackCatalog.instantiate(ReleaseSurprise.MAP_ID).scene_file_path
	)
	assert_gt(view.track_3d.piece_count(), 5, "the track's slabs were built")


func test_round_drops_the_2d_only_extras_without_saving() -> void:
	assert_false(_game.settings.hazards_enabled)
	assert_false(_game.settings.treasures_enabled)
	assert_false(_game.settings.powers_enabled)
	assert_eq(_game.settings.save_path, "", "the overrides are never written")


func test_fish_race_in_3d_and_finish_with_payouts() -> void:
	_start_race(3)
	await wait_process_frames(2)
	var view: Race3DView = _game.get_node("View3D")
	assert_eq(view.fish_count(), 3, "one 3D fish per racer")
	_finish_marbles([2, 0, 1])
	assert_eq(_flow.state, GameFlow.State.PODIUM, "a normal podium")


func test_round_returns_home_when_the_podium_ends() -> void:
	_start_race(2)
	_finish_marbles([0, 1])
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	_flow.tick(_flow.podium_seconds + 0.1)
	await wait_process_frames(2)
	assert_eq(_flow.state, GameFlow.State.IDLE, "the game leaves instead of opening a new lobby")


func test_finishing_the_round_readies_the_4d_joke() -> void:
	ReleaseSurprise.stage = ReleaseSurprise.Stage.THREE
	_start_race(2)
	_finish_marbles([0, 1])
	_flow.tick(_flow.podium_seconds + 0.1)
	var stage: ReleaseSurprise.Stage = ReleaseSurprise.stage
	ReleaseSurprise.end()
	assert_eq(stage, ReleaseSurprise.Stage.THREE_PLAYED)


func test_map_picker_cannot_change_the_map() -> void:
	var before: Track = _current_track()
	_game._on_map_selected("pachinko")
	assert_eq(_current_track(), before)


func test_extrude_builds_caps_and_sides() -> void:
	var square := PackedVector2Array(
		[Vector2(0, 0), Vector2(100, 0), Vector2(100, 50), Vector2(0, 50)]
	)
	var mesh: ArrayMesh = FlatTo3D.extrude(square, 0.5)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# Two caps of two triangles, four sides of two triangles.
	assert_eq(vertices.size(), 36)
	var box: AABB = mesh.get_aabb()
	assert_almost_eq(box.size.x, 1.0, 0.001)
	assert_almost_eq(box.size.y, 0.5, 0.001)
	assert_almost_eq(box.size.z, 0.5, 0.001)


func test_transform_matches_the_2d_one() -> void:
	var flat := Transform2D(0.7, Vector2(1.5, 1.5), 0.0, Vector2(300, -40))
	var p := Vector2(25, 60)
	var moved: Vector3 = FlatTo3D.transform(flat) * FlatTo3D.point(p)
	var expected: Vector3 = FlatTo3D.point(flat * p)
	assert_almost_eq(moved.distance_to(expected), 0.0, 0.0001)
