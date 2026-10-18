extends GutTest
## Claw Machine: the claw that chat steers and drops, the grab, the carry to the prize chute,
## the slips, the automatic play and the shelf that empties the cabinet by itself.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _claw: ClawMachine


func before_each() -> void:
	_track = TrackCatalog.instantiate("claw")
	add_child_autofree(_track)
	_claw = _track.get_node("ClawMachine") as ClawMachine
	# A body only takes its transform inside physics frames.
	await wait_physics_frames(3)


func _marble_at(pos: Vector2, gravity: float = 1.0) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = gravity
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


## A fish resting on the shelf at world x `x`.
func _fish_on_shelf(x: float) -> Marble:
	return _marble_at(Vector2(x, _claw.shelf_y(x) - Marble.RADIUS - 2.0))


## Waits physics frames until `done` returns true, at most `seconds`. Returns whether it did.
func _wait_until(done: Callable, seconds: float) -> bool:
	for i: int in int(seconds / STEP):
		if done.call():
			return true
		await wait_physics_frames(1)
	return bool(done.call())


## Puts the claw over world x `x`, waiting there for chat.
func _park(x: float) -> void:
	_claw.claw_x = x
	_claw.target_x = x
	_claw.steer(1, "parker")
	_claw.claw_x = x
	_claw.target_x = x


func test_the_map_is_registered_with_a_claw_and_a_shelf() -> void:
	assert_true(TrackCatalog.has_map("claw"))
	assert_eq(TrackCatalog.get_name_of("claw"), "Claw Machine")
	assert_not_null(_claw)
	assert_not_null(_claw.get_lift())
	assert_false(_claw.is_armed())
	assert_false(_track.follow_camera, "the cabinet is seen whole")


func test_reseed_arms_the_claw_over_the_chute_and_shows_the_tally() -> void:
	watch_signals(_claw)
	_claw.reseed(1)
	assert_true(_claw.is_armed())
	assert_eq(_claw.claw_x, _claw.chute_x)
	assert_eq(_claw.state, ClawMachine.State.IDLE)
	assert_signal_emitted_with_parameters(_claw, "tally_changed", [_claw.tally_text()])


func test_stopping_puts_everything_back_and_hides_the_tally() -> void:
	_claw.reseed(1)
	_claw.tick(20.0)
	assert_gt(_claw.lift_fraction(), 0.0)
	watch_signals(_claw)
	_track.stop_gimmicks()
	assert_false(_claw.is_armed())
	assert_eq(_claw.lift_fraction(), 0.0)
	assert_eq(_claw.claw_x, _claw.chute_x)
	assert_signal_emitted_with_parameters(_claw, "tally_changed", [""])


func test_nothing_reacts_before_the_race() -> void:
	assert_false(_claw.steer(1, "a"))
	assert_false(_claw.grab("a"))
	assert_eq(_claw.presses(0) + _claw.presses(1) + _claw.presses(2), 0)


func test_left_and_right_move_the_claw_a_step_and_count() -> void:
	_claw.reseed(1)
	var from: float = _claw.target_x
	assert_true(_claw.steer(1, "a"))
	assert_true(_claw.steer(1, "b"))
	assert_almost_eq(_claw.target_x, from + 2.0 * ClawMachine.STEP, 0.01)
	assert_true(_claw.steer(-1, "c"))
	assert_almost_eq(_claw.target_x, from + ClawMachine.STEP, 0.01)
	assert_eq(_claw.presses(0), 1)
	assert_eq(_claw.presses(1), 2)
	assert_string_contains(_claw.tally_text(), "#left 1")
	assert_string_contains(_claw.tally_text(), "#right 2")
	assert_string_contains(_claw.tally_text(), "a, b, c")


func test_the_claw_stays_inside_the_cabinet() -> void:
	_claw.reseed(1)
	for i: int in 40:
		_claw.steer(1)
	assert_lte(_claw.target_x, _claw.pit_right)
	for i: int in 40:
		_claw.steer(-1)
	assert_eq(_claw.target_x, _claw.chute_x)


func test_grab_over_the_chute_does_nothing_but_counts() -> void:
	_claw.reseed(1)
	assert_false(_claw.grab("a"))
	assert_eq(_claw.state, ClawMachine.State.IDLE)
	assert_eq(_claw.presses(2), 1)


func test_grab_drops_the_claw_and_it_closes_on_the_fish_under_it() -> void:
	_claw.reseed(1)
	var fish: Marble = _fish_on_shelf(1000.0)
	await wait_physics_frames(20)
	_park(fish.global_position.x)
	assert_true(_claw.grab("a"))
	assert_eq(_claw.state, ClawMachine.State.DROP)
	var lifted: bool = await _wait_until(
		func() -> bool: return _claw.state == ClawMachine.State.LIFT, 3.0
	)
	assert_true(lifted, "the claw comes back up")
	assert_eq(_claw.get_held(), fish)


func test_a_grab_with_no_fish_under_it_comes_up_empty() -> void:
	_claw.reseed(1)
	_fish_on_shelf(1600.0)
	await wait_physics_frames(20)
	_park(700.0)
	_claw.grab("a")
	var lifted: bool = await _wait_until(
		func() -> bool: return _claw.state == ClawMachine.State.LIFT, 3.0
	)
	assert_true(lifted)
	assert_null(_claw.get_held())


func test_a_held_fish_is_carried_into_the_prize_chute() -> void:
	_claw.reseed(1)
	var fish: Marble = _fish_on_shelf(1000.0)
	await wait_physics_frames(20)
	_park(fish.global_position.x)
	_claw.grab("a")
	await _wait_until(func() -> bool: return _claw.get_held() != null, 3.0)
	# This test is about the carry, not the slip.
	_claw._slip_at = 2.0
	var delivered: bool = await _wait_until(func() -> bool: return _claw.prizes == 1, 6.0)
	assert_true(delivered, "the claw lets go over the chute")
	await wait_physics_frames(30)
	assert_lt(fish.global_position.x, _claw.pit_left, "the fish falls into the chute")
	assert_eq(_claw.slips, 0)


func test_a_fish_can_slip_out_on_the_way() -> void:
	_claw.reseed(1)
	var fish: Marble = _fish_on_shelf(1400.0)
	await wait_physics_frames(20)
	_park(fish.global_position.x)
	_claw.grab("a")
	await _wait_until(func() -> bool: return _claw.get_held() != null, 3.0)
	_claw._slip_at = 0.3
	watch_signals(_claw)
	var slipped: bool = await _wait_until(func() -> bool: return _claw.slips == 1, 4.0)
	assert_true(slipped)
	assert_signal_emitted_with_parameters(_claw, "fish_slipped", [fish])
	assert_null(_claw.get_held())
	await wait_physics_frames(90)
	assert_gt(fish.global_position.x, _claw.pit_left, "the fish falls back into the pit")
	assert_eq(_claw.prizes, 0)


func test_about_a_third_of_the_grabs_slip() -> void:
	_claw.reseed(5)
	var slips: int = 0
	for i: int in 400:
		_claw._close_on(Marble.new())
		if _claw._slip_at <= 1.0:
			slips += 1
			assert_between(_claw._slip_at, ClawMachine.SLIP_FROM, ClawMachine.SLIP_TO)
		_claw._held.free()
		_claw._held = null
	assert_between(slips, 100, 180)


func test_with_chat_quiet_the_claw_goes_for_a_fish_by_itself() -> void:
	_claw.reseed(1)
	# Right by the chute wall, where the tilt of the shelf piles the fish up.
	var fish: Marble = _fish_on_shelf(_claw.pit_left + 40.0)
	var grabbed: bool = await _wait_until(func() -> bool: return _claw.get_held() == fish, 8.0)
	assert_true(grabbed)


func test_a_claw_nobody_drops_goes_down_by_itself() -> void:
	_claw.reseed(1)
	_fish_on_shelf(1200.0)
	_claw.steer(1, "a")
	_claw.steer(1, "a")
	# Chat keeps steering but never types #grab.
	var dropped: bool = false
	for i: int in int((ClawMachine.MAX_HOVER + 1.0) / STEP):
		if i % 60 == 0:
			_claw.steer(1 if i % 120 == 0 else -1, "a")
		await wait_physics_frames(1)
		if _claw.state != ClawMachine.State.IDLE:
			dropped = true
			break
	assert_true(dropped)


func test_the_shelf_rises_until_every_fish_rolls_into_the_chute() -> void:
	_claw.reseed(1)
	var start: float = _claw.shelf_y(_claw.pit_left)
	_claw.tick(_claw.lift_delay)
	assert_almost_eq(_claw.shelf_y(_claw.pit_left), start, 0.01, "the shelf waits at first")
	_claw.tick(_claw.lift_seconds)
	assert_eq(_claw.lift_fraction(), 1.0)
	assert_lt(_claw.shelf_y(_claw.pit_left), _claw.wall_top - Marble.RADIUS)
	assert_gt(
		_claw.shelf_y(_claw.pit_left), _claw.shelf_y(_claw.pit_right), "it tilts down to the chute"
	)


func test_progress_ranks_the_held_fish_between_the_pile_and_the_chute() -> void:
	_claw.reseed(1)
	var fish: Marble = _fish_on_shelf(1000.0)
	var other: Marble = _fish_on_shelf(500.0)
	await wait_physics_frames(20)
	_park(fish.global_position.x)
	_claw.grab("a")
	await _wait_until(func() -> bool: return _claw.state == ClawMachine.State.CARRY, 4.0)
	assert_eq(_claw.get_held(), fish)
	var held: float = _track.get_progress(fish.global_position)
	var pile: float = _track.get_progress(other.global_position)
	var chute: float = _track.get_progress(Vector2(_claw.chute_x, _claw.wall_top))
	assert_gt(held, pile)
	assert_lt(held, chute)
	assert_gt(_track.get_progress(_track.get_finish_position()), 0.9)


func test_the_replay_puts_the_claw_and_the_shelf_back() -> void:
	_claw.reseed(1)
	_claw.tick(15.0)
	var recorded: PackedFloat32Array = _claw.replay_state()
	_claw.stop_gimmick()
	_claw.replay_apply(recorded, recorded, 0.0)
	assert_eq(_claw.replay_state(), recorded)
	assert_true(Replayable.find_in(_track).has(_claw))
