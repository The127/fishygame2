extends GutTest
## Switchback: ramps that flip their slope when a fish crosses a hidden trigger zone, with a
## bounded number of flips so a race can never stall.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _hazard: SwitchbackHazard


func before_each() -> void:
	_track = TrackCatalog.instantiate("switchback")
	add_child_autofree(_track)
	_hazard = _track.get_hazards()[0] as SwitchbackHazard
	await wait_physics_frames(2)


func _marble_at(pos: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


func _step(ramp: SwitchbackRamp, seconds: float) -> void:
	for i: int in int(seconds / STEP):
		ramp._physics_process(STEP)


## Puts a fish in the ramp's trigger zone and lets the physics engine notice it.
func _feed_trigger(ramp: SwitchbackRamp) -> Marble:
	var zone: Area2D = ramp.get_node("Trigger") as Area2D
	var marble: Marble = _marble_at(zone.global_position)
	await wait_physics_frames(3)
	return marble


func test_the_map_is_three_ramps_under_one_hazard() -> void:
	assert_eq(_hazard.get_ramps().size(), 3)
	assert_ne(_track.get_progress(_track.get_spawn_position(0)), 1.0)


func test_a_seed_plans_the_same_triggers_and_budgets() -> void:
	var first: Array[SwitchbackRamp] = _hazard.get_ramps()
	_hazard.reseed(5)
	var plan: Array = []
	for ramp: SwitchbackRamp in first:
		plan.append([ramp.trigger_share(), ramp.max_flips, ramp.hold_seconds])
		assert_true(ramp.is_armed())
		assert_between(ramp.trigger_share(), SwitchbackRamp.TRIGGER_MIN, SwitchbackRamp.TRIGGER_MAX)
		assert_between(ramp.max_flips, 1, 2)
	_hazard.reseed(5)
	var again: Array = []
	for ramp: SwitchbackRamp in first:
		again.append([ramp.trigger_share(), ramp.max_flips, ramp.hold_seconds])
	assert_eq(again, plan)
	_hazard.reseed(6)
	var other: Array = []
	for ramp: SwitchbackRamp in first:
		other.append([ramp.trigger_share(), ramp.max_flips, ramp.hold_seconds])
	assert_ne(other, plan)


func test_a_fish_in_the_trigger_shudders_then_tips_the_ramp_then_it_swings_back() -> void:
	_hazard.reseed(3)
	var ramp: SwitchbackRamp = _hazard.get_ramps()[0]
	ramp.max_flips = 1
	ramp.hold_seconds = 3.0
	var rest: float = ramp.target_angle()
	var marble: Marble = await _feed_trigger(ramp)
	_step(ramp, 0.1)
	assert_eq(ramp.phase, SwitchbackRamp.Phase.WARN, "shudders first")
	assert_false(ramp.reversed)
	_step(ramp, SwitchbackRamp.WARN_SECONDS)
	assert_eq(ramp.phase, SwitchbackRamp.Phase.HOLD)
	assert_true(ramp.reversed)
	assert_eq(ramp.flips_used, 1)
	marble.global_position = Vector2(-500.0, -500.0)
	# The body only takes its transform inside physics frames.
	await wait_physics_frames(90)
	var slab: AnimatableBody2D = ramp.get_node("Slab") as AnimatableBody2D
	assert_almost_eq(slab.rotation, -rest, 0.01, "tipped against its slope")
	ramp.hold_seconds = 0.1
	await wait_physics_frames(120)
	assert_false(ramp.reversed)
	assert_almost_eq(slab.rotation, rest, 0.01, "back at rest")


func test_a_ramp_never_flips_more_than_its_budget() -> void:
	_hazard.reseed(3)
	var ramp: SwitchbackRamp = _hazard.get_ramps()[1]
	ramp.max_flips = 2
	var marble: Marble = await _feed_trigger(ramp)
	for i: int in 6:
		_step(ramp, SwitchbackRamp.WARN_SECONDS + ramp.hold_seconds + SwitchbackRamp.COOLDOWN + 0.2)
	assert_eq(ramp.flips_used, 2)
	assert_false(ramp.reversed, "settled forward for good")
	assert_not_null(marble)


func test_nothing_flips_after_the_horizon_and_a_tipped_ramp_settles() -> void:
	_hazard.reseed(3)
	var ramp: SwitchbackRamp = _hazard.get_ramps()[2]
	ramp.max_flips = 2
	var marble: Marble = await _feed_trigger(ramp)
	_step(ramp, SwitchbackRamp.WARN_SECONDS + 0.1)
	assert_true(ramp.reversed)
	ramp.hold_seconds = 1000.0
	ramp.clock = SwitchbackRamp.HORIZON
	_step(ramp, STEP * 2.0)
	assert_false(ramp.reversed, "the hold is cut short at the horizon")
	_step(ramp, SwitchbackRamp.COOLDOWN + 1.0)
	assert_eq(ramp.phase, SwitchbackRamp.Phase.REST)
	assert_eq(ramp.flips_used, 1)
	assert_not_null(marble)


func test_an_unarmed_ramp_ignores_fish() -> void:
	var ramp: SwitchbackRamp = _hazard.get_ramps()[0]
	var marble: Marble = await _feed_trigger(ramp)
	_step(ramp, 3.0)
	assert_eq(ramp.phase, SwitchbackRamp.Phase.REST)
	assert_false(ramp.is_tipped())
	assert_not_null(marble)


func test_backwash_tips_the_chosen_ramp_then_lets_it_go() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4
	_track.arm_hazards(rng, 3)
	var spent: float = 0.0
	while _hazard.phase != Hazard.Phase.ACTIVE and spent < 60.0:
		_hazard.tick(STEP)
		spent += STEP
	assert_eq(_hazard.phase, Hazard.Phase.ACTIVE)
	var ramp: SwitchbackRamp = _hazard.get_ramps()[_hazard.chosen_index()]
	assert_true(ramp.is_tipped())
	while _hazard.phase != Hazard.Phase.IDLE and spent < 120.0:
		_hazard.tick(STEP)
		spent += STEP
	assert_false(ramp.is_tipped())
	assert_eq(_hazard.chosen_index(), -1)


func test_stopping_the_gimmick_puts_every_ramp_back() -> void:
	_hazard.reseed(3)
	var ramp: SwitchbackRamp = _hazard.get_ramps()[0]
	ramp.set_forced(true)
	_step(ramp, 2.0)
	_hazard.stop_gimmick()
	assert_false(ramp.is_tipped())
	assert_false(ramp.is_armed())
	var slab: AnimatableBody2D = ramp.get_node("Slab") as AnimatableBody2D
	assert_almost_eq(slab.rotation, ramp.target_angle(), 0.0001)


func test_replay_state_round_trips() -> void:
	_hazard.reseed(3)
	var ramp: SwitchbackRamp = _hazard.get_ramps()[0]
	ramp.set_forced(true)
	_step(ramp, 1.0)
	var state: PackedFloat32Array = ramp.replay_state()
	_hazard.stop_gimmick()
	ramp.replay_apply(state, state, 0.0)
	assert_eq(ramp.replay_state(), state)
