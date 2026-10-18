extends GutTest
## Chat steering of the Gravity Flip map: the votes, the pace of the turns and the autopilot.


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _track() -> Track:
	var track: Track = TrackCatalog.instantiate("gravity")
	add_child_autofree(track)
	return track


func _flipper(track: Track) -> GravityFlipper:
	return track.get_node("Flipper") as GravityFlipper


func _seeded() -> GravityFlipper:
	var flipper: GravityFlipper = _flipper(_track())
	flipper.reseed(5)
	return flipper


## Ticks `seconds` of race time in small steps.
func _run(flipper: GravityFlipper, seconds: float) -> void:
	for i: int in int(seconds * 60.0):
		flipper.tick(1.0 / 60.0)


func test_votes_are_ignored_until_the_flipper_is_armed() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	assert_false(flipper.vote(GravityFlipper.Pull.UP, "ann"))
	assert_false(flipper.is_chat_live())


func test_a_viewer_has_one_vote_and_the_newest_counts() -> void:
	var flipper: GravityFlipper = _seeded()
	flipper.vote(GravityFlipper.Pull.UP, "ann")
	flipper.vote(GravityFlipper.Pull.LEFT, "ann")
	var counts: PackedInt32Array = flipper.vote_counts()
	assert_eq(counts[GravityFlipper.Pull.UP], 0)
	assert_eq(counts[GravityFlipper.Pull.LEFT], 1)


func test_the_side_with_most_votes_leads() -> void:
	var flipper: GravityFlipper = _seeded()
	flipper.vote(GravityFlipper.Pull.UP, "ann")
	flipper.vote(GravityFlipper.Pull.RIGHT, "bob")
	flipper.vote(GravityFlipper.Pull.RIGHT, "cy")
	assert_eq(flipper.leading_side(), GravityFlipper.Pull.RIGHT)


func test_a_tie_keeps_the_current_floor_else_the_newest_vote_wins() -> void:
	var flipper: GravityFlipper = _seeded()
	flipper.vote(GravityFlipper.Pull.UP, "ann")
	flipper.vote(GravityFlipper.Pull.DOWN, "bob")
	assert_eq(flipper.leading_side(), GravityFlipper.Pull.DOWN, "down is the floor and tied")
	flipper.vote(GravityFlipper.Pull.RIGHT, "cy")
	flipper.vote(GravityFlipper.Pull.UP, "dee")
	flipper.vote(GravityFlipper.Pull.RIGHT, "eli")
	flipper.vote(GravityFlipper.Pull.DOWN, "fay")
	# Up 2, right 2, down 2: down is the floor and tied, so it stays.
	assert_eq(flipper.leading_side(), GravityFlipper.Pull.DOWN)
	flipper.vote(GravityFlipper.Pull.LEFT, "gus")
	flipper.vote(GravityFlipper.Pull.LEFT, "hal")
	flipper.vote(GravityFlipper.Pull.LEFT, "ivy")
	assert_eq(flipper.leading_side(), GravityFlipper.Pull.LEFT)


func test_no_votes_no_leader() -> void:
	assert_eq(_seeded().leading_side(), -1)


func test_votes_expire() -> void:
	var flipper: GravityFlipper = _seeded()
	flipper.vote(GravityFlipper.Pull.UP, "ann")
	_run(flipper, GravityFlipper.VOTE_WINDOW + 0.2)
	assert_eq(flipper.vote_counts()[GravityFlipper.Pull.UP], 0)
	assert_false(flipper.is_chat_live())


func test_chat_turns_gravity_after_a_short_build_up() -> void:
	var flipper: GravityFlipper = _seeded()
	flipper.vote(GravityFlipper.Pull.RIGHT, "ann")
	flipper.tick(0.1)
	flipper.tick(0.1)
	assert_eq(flipper.pull, GravityFlipper.Pull.DOWN, "still charging")
	assert_eq(flipper.next_pull(), GravityFlipper.Pull.RIGHT)
	assert_gt(flipper.warning(), 0.0)
	_run(flipper, GravityFlipper.CHAT_BUILD + 0.1)
	assert_eq(flipper.pull, GravityFlipper.Pull.RIGHT)


func test_chat_waits_for_the_room_to_settle_between_turns() -> void:
	var flipper: GravityFlipper = _seeded()
	flipper.turn_to(GravityFlipper.Pull.UP)
	flipper.vote(GravityFlipper.Pull.LEFT, "ann")
	_run(flipper, GravityFlipper.MIN_DWELL - 0.3)
	assert_eq(flipper.pull, GravityFlipper.Pull.UP)
	assert_eq(flipper.warning(), 0.0, "no build-up yet")
	_run(flipper, 0.3 + GravityFlipper.CHAT_BUILD + 0.1)
	assert_eq(flipper.pull, GravityFlipper.Pull.LEFT)


func test_the_charge_follows_the_leader_and_gives_up_when_the_vote_goes_back() -> void:
	var flipper: GravityFlipper = _seeded()
	flipper.vote(GravityFlipper.Pull.UP, "ann")
	flipper.tick(0.1)
	assert_eq(flipper.next_pull(), GravityFlipper.Pull.UP)
	flipper.vote(GravityFlipper.Pull.LEFT, "bob")
	flipper.vote(GravityFlipper.Pull.LEFT, "cy")
	flipper.tick(0.1)
	assert_eq(flipper.next_pull(), GravityFlipper.Pull.LEFT)
	flipper.vote(GravityFlipper.Pull.DOWN, "bob")
	flipper.vote(GravityFlipper.Pull.DOWN, "cy")
	flipper.vote(GravityFlipper.Pull.DOWN, "dee")
	flipper.tick(0.1)
	assert_eq(flipper.warning(), 0.0, "down is already the floor")
	_run(flipper, 1.0)
	assert_eq(flipper.pull, GravityFlipper.Pull.DOWN)


func test_the_autopilot_stays_out_of_the_way_while_chat_votes() -> void:
	var flipper: GravityFlipper = _seeded()
	var first: float = flipper.get_schedule()[0]
	flipper.vote(GravityFlipper.Pull.DOWN, "ann")
	_run(flipper, first + 0.5)
	assert_eq(flipper.pull, GravityFlipper.Pull.DOWN, "the planned flip passed unused")
	assert_eq(flipper.warning(), 0.0)


func test_the_autopilot_takes_over_again_when_chat_is_quiet() -> void:
	var flipper: GravityFlipper = _seeded()
	flipper.vote(GravityFlipper.Pull.DOWN, "ann")
	_run(flipper, GravityFlipper.VOTE_WINDOW + 0.2)
	watch_signals(flipper)
	_run(flipper, 30.0)
	assert_signal_emitted(flipper, "flipped", "flips resumed after the votes ran out")


func test_the_tally_shows_the_votes_and_hides_when_disarmed() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	watch_signals(flipper)
	flipper.reseed(5)
	assert_string_contains(flipper.tally_text(), "#up")
	flipper.vote(GravityFlipper.Pull.UP, "ann")
	flipper.vote(GravityFlipper.Pull.UP, "bob")
	assert_string_contains(flipper.tally_text(), "[#up 2]")
	assert_signal_emitted(flipper, "tally_changed")
	flipper.disarm()
	assert_signal_emitted_with_parameters(flipper, "tally_changed", [""])
	assert_eq(flipper.tally_text(), "")


func test_disarm_forgets_the_votes_and_a_charge() -> void:
	var flipper: GravityFlipper = _seeded()
	flipper.vote(GravityFlipper.Pull.UP, "ann")
	flipper.tick(0.1)
	flipper.disarm()
	assert_false(flipper.is_chat_live())
	assert_eq(flipper.warning(), 0.0)


func test_the_track_forwards_the_tally() -> void:
	var track: Track = _track()
	watch_signals(track)
	track.seed_gimmicks(_rng(3))
	assert_signal_emitted(track, "flipper_tally_changed")


func test_the_flipper_is_in_the_chat_group() -> void:
	assert_true(_flipper(_track()).is_in_group(GravityFlipper.CHAT_GROUP))


func test_every_door_has_a_beacon() -> void:
	var track: Track = _track()
	var doors: int = 0
	for child: Node in track.get_children():
		if child.name.begins_with("Valve"):
			doors += 1
	assert_eq(doors, 5, "two doors in the first two partitions, one in the last")
	assert_eq(track.find_children("*", "DoorBeacon", true, false).size(), doors)
