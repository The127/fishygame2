extends GutTest
## The timed trapdoors of Fork Reef and the switch that splits its second half.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _fork() -> Track:
	var track: Track = TrackCatalog.instantiate("fork")
	add_child_autofree(track)
	return track


func _doors(track: Track) -> Array[TrapDoor]:
	var result: Array[TrapDoor] = []
	for child: Node in track.get_children():
		if child is TrapDoor:
			result.append(child as TrapDoor)
	return result


func _timeline(track: Track, seconds: int) -> Array[int]:
	var result: Array[int] = []
	for door: TrapDoor in _doors(track):
		for t: int in seconds:
			result.append(door.phase_at(float(t)))
	return result


func test_fork_has_two_doors_and_a_switch() -> void:
	var track: Track = _fork()
	assert_eq(_doors(track).size(), 2)
	var gates: int = 0
	for child: Node in track.get_children():
		if child is FlipGate:
			gates += 1
	assert_eq(gates, 1)


func test_unarmed_doors_stay_shut() -> void:
	for door: TrapDoor in _doors(_fork()):
		assert_false(door.is_armed())
		for t: int in 30:
			assert_eq(door.phase_at(float(t)), TrapDoor.Phase.SHUT)


func test_same_seed_opens_the_doors_the_same_way() -> void:
	var first: Track = _fork()
	var second: Track = _fork()
	first.seed_gimmicks(_rng(4))
	second.seed_gimmicks(_rng(4))
	assert_eq(_timeline(first, 60), _timeline(second, 60))


func test_every_cycle_warns_before_it_opens() -> void:
	var track: Track = _fork()
	track.seed_gimmicks(_rng(9))
	for door: TrapDoor in _doors(track):
		var seen: Array[int] = []
		var t: float = 0.0
		while t < door.get_cycle() * 2.0:
			var phase: int = door.phase_at(t)
			if seen.is_empty() or seen[-1] != phase:
				seen.append(phase)
			t += 0.05
		var opened: int = seen.find(TrapDoor.Phase.OPEN)
		assert_gt(opened, 0, "the door opens")
		assert_eq(seen[opened - 1], TrapDoor.Phase.TELEGRAPH, "a telegraph comes first")


func test_plate_swings_open_and_back() -> void:
	var track: Track = _fork()
	track.seed_gimmicks(_rng(3))
	await wait_physics_frames(2)
	var door: TrapDoor = _doors(track)[0]
	var plate: AnimatableBody2D = door.get_node("Plate") as AnimatableBody2D
	var widest: float = 0.0
	for i: int in int(door.get_cycle() * 60.0) + 120:
		await wait_physics_frames(1)
		widest = maxf(widest, absf(plate.rotation))
	assert_almost_eq(widest, deg_to_rad(absf(door.open_degrees)), 0.05)
	# Stopping the gimmicks puts the plate back in the floor.
	track.stop_gimmicks()
	await wait_physics_frames(2)
	assert_almost_eq(plate.rotation, 0.0, 0.001)
	assert_false(door.is_armed())


func test_a_fish_above_an_open_door_falls_through() -> void:
	var track: Track = _fork()
	track.seed_gimmicks(_rng(3))
	var door: TrapDoor = _doors(track)[0]
	# Run the clock to the middle of an opening.
	var start: float = door.get_cycle() - door.telegraph_seconds - door.open_seconds
	door.clock = fposmod(start - _offset_of(door), door.get_cycle()) + door.telegraph_seconds + 0.6
	await wait_physics_frames(40)
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = door.to_global(Vector2(door.length * 0.5, -40.0))
	await wait_physics_frames(30)
	assert_gt(marble.global_position.y, door.global_position.y + 50.0)


func _offset_of(door: TrapDoor) -> float:
	return float(door.get("_offset"))


func test_switch_sends_fish_alternately_each_way() -> void:
	var track: Track = _fork()
	await wait_physics_frames(12)
	var gate: FlipGate = null
	for child: Node in track.get_children():
		if child is FlipGate:
			gate = child as FlipGate
	assert_not_null(gate)
	var first: int = gate.state
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = gate.global_position + Vector2(0.0, -40.0)
	await wait_physics_frames(120)
	assert_eq(gate.state, -first, "the switch flipped after the fish rolled off")
	assert_eq(signf(marble.global_position.x - gate.global_position.x), float(first))
	track.stop_gimmicks()
	assert_eq(gate.state, gate.initial_state)


func test_progress_on_both_routes_rises_toward_the_finish() -> void:
	var track: Track = _fork()
	var branch: Path2D = track.get_node("Branches/Rapids") as Path2D
	var curve: Curve2D = branch.curve
	var last: float = -1.0
	for i: int in 11:
		var at: Vector2 = branch.to_global(curve.sample_baked(curve.get_baked_length() * float(i) / 10.0))
		var progress: float = track.get_progress(at)
		assert_gte(progress, last - 0.001)
		last = progress
	assert_gt(last, 0.9)
	var centerline: Path2D = track.get_node("Centerline") as Path2D
	var end: Vector2 = centerline.to_global(centerline.curve.get_point_position(centerline.curve.point_count - 1))
	assert_gt(track.get_progress(end), 0.95)
