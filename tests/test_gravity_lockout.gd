extends GutTest
## The sea taking the wheel from chat on the Gravity Flip map, when the race stalls or runs late.


func _track() -> Track:
	var track: Track = TrackCatalog.instantiate("gravity")
	add_child_autofree(track)
	return track


func _seeded() -> GravityFlipper:
	var flipper: GravityFlipper = (_track().get_node("Flipper")) as GravityFlipper
	flipper.reseed(5)
	return flipper


## Ticks `seconds` of race time in small steps.
func _run(flipper: GravityFlipper, seconds: float) -> void:
	for i: int in int(seconds * 60.0):
		flipper.tick(1.0 / 60.0)


func _fish_at(x: float) -> Marble:
	var marble: Marble = (load("res://scenes/marble.tscn") as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.freeze = true
	marble.global_position = Vector2(x, 300.0)
	return marble


func test_chat_loses_the_helm_when_the_rearmost_fish_goes_nowhere() -> void:
	var flipper: GravityFlipper = _seeded()
	_fish_at(300.0)
	_run(flipper, 1.0)
	flipper.vote(GravityFlipper.Pull.UP, "ann")
	_run(flipper, GravityFlipper.STALL_SECONDS + 1.0)
	assert_true(flipper.is_locked_out())
	assert_false(flipper.is_chat_live(), "the votes are dropped")
	assert_false(flipper.vote(GravityFlipper.Pull.UP, "bob"), "new votes do not count")
	assert_eq(flipper.tally_text(), "THE SEA TAKES THE WHEEL")


func test_chat_gets_the_helm_back_after_the_lockout() -> void:
	var flipper: GravityFlipper = _seeded()
	_fish_at(300.0)
	_run(flipper, GravityFlipper.STALL_SECONDS + 1.0)
	assert_true(flipper.is_locked_out())
	_run(flipper, GravityFlipper.LOCKOUT_SECONDS + 0.5)
	assert_false(flipper.is_locked_out())
	assert_true(flipper.vote(GravityFlipper.Pull.UP, "ann"))


func test_each_lockout_lasts_twice_as_long() -> void:
	var flipper: GravityFlipper = _seeded()
	_fish_at(300.0)
	_run(flipper, GravityFlipper.STALL_SECONDS + 1.0)
	_run(flipper, GravityFlipper.LOCKOUT_SECONDS + 0.5)
	_run(flipper, GravityFlipper.STALL_SECONDS + 1.0)
	assert_true(flipper.is_locked_out())
	_run(flipper, GravityFlipper.LOCKOUT_SECONDS + 0.5)
	assert_true(flipper.is_locked_out(), "the second lockout is longer")


func test_a_fish_that_keeps_moving_never_locks_chat_out() -> void:
	var flipper: GravityFlipper = _seeded()
	var fish: Marble = _fish_at(100.0)
	for i: int in 8:
		fish.global_position.x += GravityFlipper.STALL_PROGRESS * 2.0
		_run(flipper, GravityFlipper.STALL_SECONDS * 0.5)
	assert_false(flipper.is_locked_out())


func test_chat_loses_the_helm_for_good_late_in_the_race() -> void:
	var flipper: GravityFlipper = _seeded()
	_run(flipper, GravityFlipper.CHAT_CUTOFF + 0.5)
	assert_true(flipper.is_locked_out())
	_run(flipper, 200.0)
	assert_true(flipper.is_locked_out())
