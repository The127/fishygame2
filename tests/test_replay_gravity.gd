extends GutTest
## The Gravity Flip flipper in the finish replay.


func _flipper() -> GravityFlipper:
	var track: Track = TrackCatalog.instantiate("gravity")
	add_child_autofree(track)
	return track.get_node("Flipper") as GravityFlipper


func test_the_flipper_takes_part_in_the_finish_replay() -> void:
	var flipper: GravityFlipper = _flipper()
	assert_true(flipper.is_in_group(Replayable.GROUP))


func test_replay_state_round_trips() -> void:
	var flipper: GravityFlipper = _flipper()
	flipper.reseed(5)
	flipper.tick(flipper.get_schedule()[0] + 0.3)
	var state: PackedFloat32Array = flipper.replay_state()
	var pull: GravityFlipper.Pull = flipper.pull
	var clock: float = flipper.clock
	flipper.disarm()
	flipper.replay_apply(state, state, 0.0)
	assert_eq(flipper.pull, pull)
	assert_almost_eq(flipper.clock, clock, 0.001)
	assert_true(flipper.is_armed())
	assert_eq(flipper.replay_state(), state)


func test_replay_state_has_the_same_length_every_time() -> void:
	var flipper: GravityFlipper = _flipper()
	var empty_size: int = flipper.replay_state().size()
	flipper.reseed(5)
	flipper.tick(4.0)
	assert_eq(flipper.replay_state().size(), empty_size)
