extends GutTest
## Flip gates on the cave map: each marble that rolls off a gate flips it, and a race
## always starts them in the same state.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"

var _track: Track


func before_each() -> void:
	_track = TrackCatalog.instantiate("cave")
	add_child_autofree(_track)
	# A body only takes its transform inside physics frames.
	await wait_physics_frames(12)


func _gates() -> Array[FlipGate]:
	var result: Array[FlipGate] = []
	for child: Node in _track.get_hazards()[0].get_children():
		if child is FlipGate:
			result.append(child as FlipGate)
	return result


func _marble_at(pos: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


func test_cave_map_has_six_gates_in_three_tiers() -> void:
	var tiers: Dictionary = {}
	for gate: FlipGate in _gates():
		tiers[snappedf(gate.position.y, 1.0)] = true
	assert_eq(_gates().size(), 6)
	assert_eq(tiers.size(), 3)


func test_gate_starts_tilted_toward_its_state() -> void:
	for gate: FlipGate in _gates():
		assert_eq(gate.state, gate.initial_state)
		var paddle: AnimatableBody2D = gate.get_node("Paddle") as AnimatableBody2D
		assert_almost_eq(paddle.rotation, gate.target_angle(), 0.0001)
		assert_eq(signf(paddle.rotation), float(gate.state))


func test_flip_swings_the_paddle_to_the_other_side() -> void:
	var gate: FlipGate = _gates()[0]
	watch_signals(gate)
	var before: int = gate.state
	gate.flip()
	assert_eq(gate.state, -before)
	assert_signal_emitted_with_parameters(gate, "flipped", [-before])
	await wait_physics_frames(40)
	var paddle: AnimatableBody2D = gate.get_node("Paddle") as AnimatableBody2D
	assert_almost_eq(paddle.rotation, gate.target_angle(), 0.001)


func test_set_state_only_flips_when_needed() -> void:
	var gate: FlipGate = _gates()[0]
	watch_signals(gate)
	gate.set_state(gate.state)
	assert_signal_not_emitted(gate, "flipped")
	gate.set_state(-gate.state)
	assert_signal_emit_count(gate, "flipped", 1)


func test_a_marble_rolling_off_the_paddle_flips_the_gate() -> void:
	var gate: FlipGate = _gates()[0]
	var before: int = gate.state
	var marble: Marble = _marble_at(gate.global_position + Vector2(118.0, 20.0))
	await wait_physics_frames(6)
	assert_eq(gate.state, before, "still over the paddle end")
	marble.global_position = gate.global_position + Vector2(400.0, 300.0)
	await wait_physics_frames(6)
	assert_eq(gate.state, -before)


func test_a_marble_waiting_on_the_paddle_does_not_flip_it() -> void:
	var gate: FlipGate = _gates()[0]
	var before: int = gate.state
	_marble_at(gate.global_position + Vector2(0.0, -40.0))
	await wait_physics_frames(10)
	assert_eq(gate.state, before)


func test_a_marble_removed_from_the_map_does_not_flip_the_gate() -> void:
	var gate: FlipGate = _gates()[0]
	var before: int = gate.state
	var marble: Marble = _marble_at(gate.global_position + Vector2(118.0, 20.0))
	await wait_physics_frames(6)
	remove_child(marble)
	await wait_physics_frames(6)
	assert_eq(gate.state, before)


func test_stopping_hazards_puts_every_gate_back() -> void:
	var start: Array[int] = []
	for gate: FlipGate in _gates():
		start.append(gate.state)
		gate.flip()
	_track.stop_hazards()
	for i: int in _gates().size():
		assert_eq(_gates()[i].state, start[i])


func test_tremor_throws_the_gates_and_the_same_seed_throws_them_the_same_way() -> void:
	var runs: Array[Array] = []
	for i: int in 2:
		var track: Track = TrackCatalog.instantiate("cave")
		add_child_autofree(track)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 12
		track.arm_hazards(rng, 5)
		var hazard: Hazard = track.get_hazards()[0]
		var seen: Array[int] = []
		for step: int in 60 * 12:
			hazard.tick(1.0 / 60.0)
			for child: Node in hazard.get_children():
				if child is FlipGate and step % 30 == 0:
					seen.append((child as FlipGate).state)
		runs.append(seen)
	assert_eq(runs[0], runs[1])
	assert_true(runs[0].has(1) and runs[0].has(-1))


func test_tremor_warns_with_the_arrows_before_it_hits() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	_track.arm_hazards(rng, 3)
	var hazard: Hazard = _track.get_hazards()[0]
	var spent: float = 0.0
	while hazard.phase != Hazard.Phase.TELEGRAPH and spent < 100.0:
		hazard.tick(1.0 / 60.0)
		spent += 1.0 / 60.0
	assert_eq(hazard.phase, Hazard.Phase.TELEGRAPH)
	var before: Array[int] = []
	for gate: FlipGate in _gates():
		before.append(gate.state)
	for i: int in 60:
		hazard.tick(1.0 / 60.0)
	var after: Array[int] = []
	for gate: FlipGate in _gates():
		after.append(gate.state)
	assert_eq(after, before, "gates hold still while the tremor is only telegraphed")
