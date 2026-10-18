extends GutTest
## The chef of Sushi Bar: "#chop" swings the knife, a fish under the blade when it lands is chopped
## and out of the race, and the cooldown and the limits keep chat from wiping out the field.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _chef: SushiChef


func before_each() -> void:
	_track = TrackCatalog.instantiate("sushi")
	add_child_autofree(_track)
	var belts: SushiBelts = _track.get_node("Centerline") as SushiBelts
	_chef = belts.get_chefs()[0]
	# The tests move the fish and the clock themselves.
	belts.set_physics_process(false)
	_chef.set_physics_process(false)
	_chef.set_field_size(10)
	_chef.reseed(1)


## A fish floating on the belt at `offset` along it from the blade, with gravity off.
func _fish(offset: float = 0.0) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = _chef.global_position + Vector2(offset, -Marble.RADIUS)
	return marble


func _run(seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		_chef.tick(STEP)


func test_the_sushi_bar_has_a_chef() -> void:
	assert_not_null(_chef)
	assert_true(_chef.is_in_group(SushiChef.CHAT_GROUP))


func test_a_fish_under_the_blade_is_chopped_when_it_lands() -> void:
	var fish: Marble = _fish()
	watch_signals(_chef)
	assert_true(_chef.chop("Ann"))
	_run(SushiChef.WINDUP * 0.5)
	assert_false(fish.chopped, "nothing is cut before the blade lands")
	_run(SushiChef.WINDUP)
	assert_true(fish.chopped)
	assert_true(fish.is_out())
	assert_eq(fish.fate(), "chopped", "the podium belt serves it as the chef's special")
	assert_true(SushiBelt.MENU.has(fish.fate()))
	assert_signal_emitted_with_parameters(_chef, "fish_chopped", [fish, "Ann"])


func test_a_fish_beside_the_blade_is_safe() -> void:
	var fish: Marble = _fish(SushiChef.BLADE_HALF + 40.0)
	_chef.chop("Ann")
	_run(SushiChef.WINDUP + 0.1)
	assert_false(fish.chopped)


func test_one_swing_takes_at_most_two_fish() -> void:
	var fish: Array[Marble] = [_fish(-20.0), _fish(0.0), _fish(20.0)]
	_chef.chop("Ann")
	_run(SushiChef.WINDUP + 0.1)
	assert_eq(_chef.chopped_count(), SushiChef.PER_SWING)
	assert_true(fish[1].chopped, "the fish nearest the middle of the blade goes first")


func test_the_knife_needs_its_cooldown_between_swings() -> void:
	assert_true(_chef.chop("Ann"))
	assert_false(_chef.chop("Bob"), "a swing is already on its way")
	_run(SushiChef.WINDUP + 0.1)
	assert_false(_chef.chop("Bob"), "the knife is cooling down")
	_run(SushiChef.COOLDOWN)
	assert_true(_chef.chop("Bob"))
	assert_eq(_chef.swing_count(), 2)


func test_spam_cannot_wipe_out_the_field() -> void:
	for i: int in 10:
		_fish()
	for i: int in 40:
		_chef.chop("viewer%d" % i)
		_run(0.25)
	assert_eq(_chef.chopped_count(), SushiChef.chop_limit(10))
	assert_false(_chef.can_swing(), "the chef is full")
	assert_eq(_chef.meter_text(), "THE CHEF IS FULL")


func test_the_limit_is_a_share_of_the_field_and_never_the_last_fish() -> void:
	assert_eq(SushiChef.chop_limit(1), 0)
	assert_eq(SushiChef.chop_limit(2), 1)
	assert_eq(SushiChef.chop_limit(3), 1)
	assert_eq(SushiChef.chop_limit(10), 3)
	assert_eq(SushiChef.chop_limit(20), 6)


func test_a_set_limit_counts_fish_and_still_spares_the_last() -> void:
	assert_eq(SushiChef.chop_limit(10, 5), 5)
	assert_eq(SushiChef.chop_limit(4, 5), 3)
	assert_eq(SushiChef.chop_limit(10, SushiChef.UNLIMITED), 9)
	assert_eq(SushiChef.chop_limit(2, SushiChef.UNLIMITED), 1)
	assert_eq(SushiChef.chop_limit(1, SushiChef.UNLIMITED), 0)
	assert_eq(SushiChef.chop_limit(10, SushiChef.SHARE_LIMIT), SushiChef.chop_limit(10))


func test_a_fixed_limit_stops_the_knife_after_that_many_fish() -> void:
	_chef.set_chop_limit(1)
	for i: int in 10:
		_fish()
	for i: int in 40:
		_chef.chop("viewer%d" % i)
		_run(0.25)
	assert_eq(_chef.chopped_count(), 1)
	assert_false(_chef.can_swing())
	assert_eq(_chef.meter_text(), "THE CHEF IS FULL")


func test_unlimited_chops_every_fish_but_the_last() -> void:
	_chef.set_chop_limit(SushiChef.UNLIMITED)
	var fish: Array[Marble] = []
	for i: int in 10:
		fish.append(_fish())
	for i: int in 60:
		_chef.chop("viewer%d" % i)
		_run(SushiChef.COOLDOWN * 0.5)
	assert_eq(_chef.chopped_count(), 9)
	assert_eq(fish.filter(func(m: Marble) -> bool: return not m.chopped).size(), 1)
	assert_ne(_chef.meter_text(), "THE CHEF IS FULL", "an unlimited chef is never full")
	_run(SushiChef.COOLDOWN)
	assert_true(_chef.can_swing(), "only the cooldown holds the knife back")


func test_without_chat_nothing_is_chopped() -> void:
	var fish: Marble = _fish()
	_run(30.0)
	assert_false(fish.chopped)
	assert_eq(_chef.swing_count(), 0)


func test_a_frozen_chef_ignores_chat() -> void:
	_chef.freeze()
	assert_false(_chef.chop("Ann"))
	assert_false(_chef.is_armed())


func test_the_replay_state_keeps_its_length() -> void:
	var before: int = _chef.replay_state().size()
	_fish()
	_chef.chop("Ann")
	_run(SushiChef.WINDUP + 0.1)
	assert_eq(_chef.replay_state().size(), before)


func test_a_chopped_fish_leaves_nigiri_that_replay() -> void:
	_fish()
	_chef.chop("Ann")
	_run(SushiChef.WINDUP + 0.1)
	var after: PackedFloat32Array = _chef.replay_state()
	_chef.stop_gimmick()
	var cleared: PackedFloat32Array = _chef.replay_state()
	assert_lt(cleared[3 + 2], 0.0, "no nigiri after a reset")
	_chef.replay_apply(after, after, 0.0)
	assert_eq(_chef.replay_state()[3 + 2], after[3 + 2], "the replay puts the nigiri back")


func _start_race(count: int) -> Race:
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(race)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	race.start(_track, count, rng, 0)
	_chef.set_physics_process(false)
	await wait_physics_frames(1)
	return race


func test_a_chopped_fish_is_a_dnf_and_the_race_still_ends() -> void:
	var race: Race = await _start_race(3)
	watch_signals(race)
	var marbles: Array[Marble] = race.get_marbles()
	for marble: Marble in marbles:
		marble.gravity_scale = 0.0
	PhysicsServer2D.body_set_state(
		marbles[1].get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(0.0, _chef.global_position + Vector2(0.0, -Marble.RADIUS))
	)
	await wait_physics_frames(2)
	_chef.chop("Ann")
	_run(SushiChef.WINDUP + 0.1)
	assert_true(race.is_chopped(1))
	assert_signal_emitted_with_parameters(race, "fish_chopped", [1, "Ann"])
	assert_true(race.running)
	_track.marble_reached_finish.emit(marbles[0])
	_track.marble_reached_finish.emit(marbles[2])
	assert_false(race.running, "the race ends once the last swimmer finished")
	var results: Array[Dictionary] = []
	results.assign(get_signal_parameters(race, "race_finished", 0)[0])
	assert_eq(int(results[2]["id"]), 1)
	assert_false(bool(results[2]["finished"]))


func test_the_track_passes_the_field_size_to_the_chef() -> void:
	_track.set_field_size(2)
	for offset: float in [-20.0, 0.0, 20.0]:
		_fish(offset)
	_chef.chop("Ann")
	_run(SushiChef.WINDUP + 0.1)
	assert_eq(_chef.chopped_count(), SushiChef.chop_limit(2))


func test_the_race_passes_the_chop_limit_to_the_chef() -> void:
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	race.chop_limit = 2
	add_child_autofree(race)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	race.start(_track, 10, rng, 0)
	assert_eq(_chef._limit(), 2)
