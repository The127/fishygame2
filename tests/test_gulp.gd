extends GutTest
## The whale's gulp: the mouth yawns, then sea junk is dragged in through the top of the map.

const STEP: float = 1.0 / 60.0

var _track: Track


func _gulps() -> GulpHazard:
	_track = TrackCatalog.instantiate("whale")
	add_child_autofree(_track)
	for hazard: Hazard in _track.get_hazards():
		if hazard is GulpHazard:
			return hazard as GulpHazard
	return null


## Runs the armed hazard until it is `seconds` into its active phase.
func _run_to_active(gulp: GulpHazard, seconds: float) -> void:
	gulp.arm(7, 5)
	gulp.clock = gulp.get_schedule()[0] - 0.1
	var guard: int = 0
	while (gulp.phase != Hazard.Phase.ACTIVE or gulp.phase_time < seconds) and guard < 2000:
		await wait_physics_frames(1)
		guard += 1


func test_the_whale_has_a_gulp_hazard_with_a_pool_of_junk() -> void:
	var gulp: GulpHazard = _gulps()
	assert_not_null(gulp)
	assert_eq(gulp.get_pool().size(), GulpHazard.POOL_SIZE)
	assert_eq(gulp.active_count(), 0, "no junk before a gulp")


func test_the_mouth_listens_to_the_gulp() -> void:
	var gulp: GulpHazard = _gulps()
	var mouth: WhaleMouth = _track.find_child("Mouth") as WhaleMouth
	assert_true(gulp.yawn_changed.is_connected(mouth.set_yawn))


func test_a_gulp_yawns_wide_then_closes() -> void:
	var gulp: GulpHazard = _gulps()
	var mouth: WhaleMouth = _track.find_child("Mouth") as WhaleMouth
	await _run_to_active(gulp, 0.5)
	assert_almost_eq(mouth.yawn, 1.0, 0.001, "the mouth is wide open during the gulp")
	gulp.disarm()
	assert_eq(mouth.yawn, 0.0, "and closed again when the map is reset")


func test_a_gulp_brings_junk_in() -> void:
	var gulp: GulpHazard = _gulps()
	await _run_to_active(gulp, gulp.active_seconds * 0.9)
	var count: int = gulp.active_count()
	assert_gte(count, 1)
	assert_lte(count, GulpHazard.MAX_PIECES)
	for piece: GulpDebris in gulp.get_pool():
		if piece.is_active:
			assert_true(piece.visible)
			assert_ne(piece.collision_layer, 0, "it bumps into fish")


func test_the_same_seed_brings_the_same_junk() -> void:
	var gulp: GulpHazard = _gulps()
	await _run_to_active(gulp, gulp.active_seconds * 0.9)
	var first: Array[int] = []
	for piece: GulpDebris in gulp.get_pool():
		first.append(piece.kind if piece.is_active else -1)
	gulp.disarm()
	await _run_to_active(gulp, gulp.active_seconds * 0.9)
	var second: Array[int] = []
	for piece: GulpDebris in gulp.get_pool():
		second.append(piece.kind if piece.is_active else -1)
	assert_eq(first, second)


func test_junk_fizzles_away_after_its_lifetime() -> void:
	var gulp: GulpHazard = _gulps()
	gulp.max_events = 1
	await _run_to_active(gulp, gulp.active_seconds * 0.9)
	assert_gt(gulp.active_count(), 0)
	watch_signals(gulp)
	for i: int in int((GulpHazard.LIFETIME + gulp.active_seconds) / STEP) + 30:
		await wait_physics_frames(1)
	assert_eq(gulp.active_count(), 0, "nothing stays in the race for good")
	assert_signal_emitted(gulp, "burst_played")


func test_junk_in_the_acid_dissolves() -> void:
	var gulp: GulpHazard = _gulps()
	var pit: AcidPit = _track.find_child("AcidA") as AcidPit
	gulp.arm(3, 5)
	var piece: GulpDebris = gulp.get_pool()[0]
	piece.activate(GulpDebris.Kind.BARREL, pit.global_position, Vector2.ZERO, 0.0)
	await wait_physics_frames(4)
	assert_false(piece.is_active, "the acid took the piece")
	assert_eq(pit.skeleton_count(), 0, "junk leaves no skeleton")


func test_stopping_the_hazards_clears_the_junk() -> void:
	var gulp: GulpHazard = _gulps()
	await _run_to_active(gulp, gulp.active_seconds * 0.9)
	_track.stop_hazards()
	assert_eq(gulp.active_count(), 0)


func test_the_gulp_follows_the_replay_state() -> void:
	var gulp: GulpHazard = _gulps()
	await _run_to_active(gulp, gulp.active_seconds * 0.9)
	var from: PackedFloat32Array = gulp.replay_state()
	var moved: GulpDebris = null
	for piece: GulpDebris in gulp.get_pool():
		if piece.is_active:
			moved = piece
	assert_not_null(moved)
	gulp.disarm()
	assert_eq(gulp.active_count(), 0)
	gulp.replay_apply(from, from, 0.0)
	assert_true(moved.visible, "the junk comes back with the state")
	assert_eq(gulp.replay_state().size(), from.size(), "the state always has the same length")
