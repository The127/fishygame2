extends GutTest
## The living whale: the rippling stomach floor and the mouth in the background.

const STEP: float = 1.0 / 60.0

var _track: Track


func _whale() -> Track:
	_track = TrackCatalog.instantiate("whale")
	add_child_autofree(_track)
	return _track


func _floors(track: Track) -> Array[WigglingFloor]:
	var result: Array[WigglingFloor] = []
	for node: Node in track.find_children("*", "WigglingFloor", true, false):
		result.append(node as WigglingFloor)
	return result


func test_the_stomach_has_two_rippling_stretches() -> void:
	assert_eq(_floors(_whale()).size(), 2)


func test_the_wave_stays_inside_its_amplitude_and_is_fixed_at_the_ends() -> void:
	var floor_piece: WigglingFloor = _floors(_whale())[0]
	floor_piece.reseed(3)
	var length: float = floor_piece.surface[0].distance_to(floor_piece.surface[1])
	var biggest: float = 0.0
	for i: int in 200:
		var t: float = float(i) * 0.05
		biggest = maxf(biggest, absf(floor_piece.lift_at(length * 0.5, t)))
		assert_almost_eq(floor_piece.lift_at(0.0, t), 0.0, 0.001)
		assert_almost_eq(floor_piece.lift_at(length, t), 0.0, 0.001)
	assert_gt(biggest, floor_piece.amplitude * 0.8, "the wave really lifts the floor")
	assert_lte(biggest, floor_piece.amplitude + 0.001)


func test_the_floor_never_turns_uphill() -> void:
	# The floor falls 0.237 px per px; the wave must never climb back faster than that, so no
	# dip can hold a fish.
	for piece: WigglingFloor in _floors(_whale()):
		var direction: Vector2 = piece.surface[piece.surface.size() - 1] - piece.surface[0]
		var length: float = direction.length()
		var slope: float = direction.y / length
		var worst: float = INF
		for i: int in 400:
			var t: float = float(i) * 0.05
			for k: int in 100:
				var a: float = length * float(k) / 100.0
				var rise: float = piece.lift_at(a + 1.0, t) - piece.lift_at(a, t)
				worst = minf(worst, slope + rise)
		assert_gt(worst, 0.0, "%s keeps running downhill" % piece.name)


func test_the_colliders_follow_the_wave() -> void:
	var piece: WigglingFloor = _floors(_whale())[0]
	piece.reseed(5)
	await wait_physics_frames(1)
	var first: PackedVector2Array = (piece.get_child(1) as CollisionShape2D).shape.get("points")
	await wait_physics_frames(40)
	var later: PackedVector2Array = (piece.get_child(1) as CollisionShape2D).shape.get("points")
	assert_ne(first, later, "the collider moved with the wave")
	var visual: Polygon2D = piece.get_node("Visual") as Polygon2D
	assert_gt(visual.polygon.size(), 4, "the picture follows too")


func test_a_seed_always_starts_the_wave_at_the_same_point() -> void:
	var piece: WigglingFloor = _floors(_whale())[0]
	piece.reseed(7)
	var expected: float = piece.lift_at(100.0, 1.0)
	piece.reseed(9)
	assert_ne(piece.lift_at(100.0, 1.0), expected)
	piece.reseed(7)
	assert_eq(piece.lift_at(100.0, 1.0), expected)


func test_stopping_the_gimmicks_flattens_the_wave_back() -> void:
	var track: Track = _whale()
	var piece: WigglingFloor = _floors(track)[0]
	piece.reseed(4)
	await wait_physics_frames(10)
	track.stop_gimmicks()
	assert_eq(piece.replay_state()[0], 0.0)
	assert_eq(piece.replay_state()[1], 0.0)


func test_the_floor_follows_the_replay_state() -> void:
	var piece: WigglingFloor = _floors(_whale())[0]
	var from: PackedFloat32Array = PackedFloat32Array([1.0, 0.25])
	var to: PackedFloat32Array = PackedFloat32Array([2.0, 0.25])
	piece.replay_apply(from, to, 0.5)
	assert_almost_eq(piece.replay_state()[0], 1.5, 0.001)
	assert_almost_eq(piece.replay_state()[1], 0.25, 0.001)


func test_the_mouth_opens_and_closes() -> void:
	var mouth: WhaleMouth = _whale().find_child("Mouth") as WhaleMouth
	var low: float = INF
	var high: float = -INF
	for i: int in 400:
		var gap: float = mouth.gap_at(float(i) * 0.1)
		low = minf(low, gap)
		high = maxf(high, gap)
	assert_gt(high - low, 40.0, "the jaws move")


func test_a_yawn_opens_the_mouth_wider() -> void:
	var mouth: WhaleMouth = _whale().find_child("Mouth") as WhaleMouth
	var calm: float = mouth.gap_at(2.0)
	mouth.yawn = 1.0
	assert_gt(mouth.gap_at(2.0), calm + 30.0)


func test_the_mouth_follows_the_replay_state() -> void:
	var mouth: WhaleMouth = _whale().find_child("Mouth") as WhaleMouth
	mouth.replay_apply(PackedFloat32Array([1.0, 0.0]), PackedFloat32Array([2.0, 1.0]), 0.5)
	assert_almost_eq(mouth.replay_state()[0], 1.5, 0.001)
	assert_almost_eq(mouth.replay_state()[1], 0.5, 0.001)
