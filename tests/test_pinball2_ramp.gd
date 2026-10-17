extends GutTest
## Pinball Reef 2: the drop targets, and the ramp gate that opens when they are all down.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"

var _track: Track
var _gate: RampGate
var _targets: DropTargets


func before_each() -> void:
	_track = TrackCatalog.instantiate("pinball2")
	add_child_autofree(_track)
	_gate = _track.get_node("RampGate") as RampGate
	_targets = _gate.get_targets()
	# A body only takes its transform inside physics frames.
	await wait_physics_frames(3)


func _marble_at(pos: Vector2, gravity: float = 0.0) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = gravity
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


func _arm() -> void:
	_track.seed_gimmicks(RandomNumberGenerator.new())


func test_a_standing_target_falls_to_a_fish_and_the_last_one_clears_the_bank() -> void:
	_arm()
	var cleared: Array[bool] = [false]
	_targets.cleared.connect(func() -> void: cleared[0] = true)
	assert_eq(_targets.standing(), _targets.count())
	assert_gte(_targets.count(), 4)
	for i: int in _targets.count() - 1:
		assert_true(_targets.hit(i))
	assert_false(cleared[0], "one is still standing")
	assert_false(_targets.hit(0), "a flat target is not hit twice")
	assert_true(_targets.hit(_targets.count() - 1))
	assert_true(cleared[0])
	assert_eq(_targets.standing(), 0)


func test_a_fish_touching_a_target_knocks_it_down() -> void:
	_arm()
	var target: StaticBody2D = _targets.get_child(0) as StaticBody2D
	var marble: Marble = _marble_at(target.global_position + Vector2(0.0, -80.0))
	await wait_physics_frames(2)
	marble.linear_velocity = Vector2(0.0, 300.0)
	await wait_physics_frames(30)
	assert_true(_targets.is_down(0))
	assert_eq(_targets.standing(), _targets.count() - 1)


func test_targets_ignore_fish_until_the_race_arms_them() -> void:
	assert_false(_targets.hit(0))
	assert_eq(_targets.standing(), _targets.count())


func test_clearing_the_targets_opens_the_ramp_gate() -> void:
	_arm()
	assert_false(_gate.is_open())
	for i: int in _targets.count():
		_targets.hit(i)
	assert_true(_gate.is_open())
	await wait_physics_frames(60)
	var plate: AnimatableBody2D = _gate.get_node("Plate") as AnimatableBody2D
	assert_gt(plate.rotation, deg_to_rad(_gate.slope_degrees + _gate.open_degrees) - 0.05)


func test_the_first_fish_through_the_gate_shuts_it_and_stands_the_targets_up() -> void:
	_arm()
	for i: int in _targets.count():
		_targets.hit(i)
	var uses: Array[int] = [0]
	_gate.used.connect(func() -> void: uses[0] += 1)
	var mouth: Area2D = _gate.get_node("Mouth") as Area2D
	var first: Marble = _marble_at(mouth.global_position)
	var second: Marble = _marble_at(mouth.global_position + Vector2(10.0, 0.0))
	await wait_physics_frames(3)
	assert_eq(uses[0], 1, "only one fish takes the shortcut")
	assert_false(_gate.is_open())
	assert_eq(_targets.standing(), _targets.count())
	assert_eq(_gate.times_used, 1)
	assert_not_null(first)
	assert_not_null(second)


func test_a_closed_gate_does_not_count_a_fish_below_it() -> void:
	_arm()
	var mouth: Area2D = _gate.get_node("Mouth") as Area2D
	_marble_at(mouth.global_position)
	await wait_physics_frames(3)
	assert_eq(_gate.times_used, 0)


func test_the_gate_is_shut_with_the_targets_up_after_stop_gimmicks() -> void:
	_arm()
	for i: int in _targets.count():
		_targets.hit(i)
	_track.stop_gimmicks()
	assert_false(_gate.is_open())
	assert_eq(_targets.standing(), _targets.count())
	await wait_physics_frames(60)
	var plate: AnimatableBody2D = _gate.get_node("Plate") as AnimatableBody2D
	assert_almost_eq(plate.rotation, deg_to_rad(_gate.slope_degrees), 0.001)
