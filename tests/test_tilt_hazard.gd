extends GutTest
## Pinball Reef's hazard: the cabinet gets bumped and everything is shoved sideways.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _tilt: TiltHazard


func before_each() -> void:
	_track = TrackCatalog.instantiate("pinball")
	add_child_autofree(_track)
	_tilt = _track.get_hazards()[0] as TiltHazard
	await wait_physics_frames(3)


func _marble_at(pos: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


func _run_until(phase: Hazard.Phase) -> void:
	var spent: float = 0.0
	while _tilt.phase != phase and spent < 100.0:
		_tilt.tick(STEP)
		spent += STEP


func test_pinball_reef_has_a_tilt_hazard() -> void:
	assert_not_null(_tilt)
	assert_eq(_tilt.kind, "tilt")


func test_no_shove_while_idle_or_warning() -> void:
	_tilt.arm(5, 3)
	assert_eq(_tilt.get_shove(), 0.0)
	_run_until(Hazard.Phase.TELEGRAPH)
	assert_eq(_tilt.get_shove(), 0.0)


func test_the_shove_swings_back_and_forth() -> void:
	_tilt.arm(5, 3)
	_run_until(Hazard.Phase.ACTIVE)
	var seen: Dictionary = {}
	while _tilt.phase == Hazard.Phase.ACTIVE:
		_tilt.tick(STEP)
		var shove: float = _tilt.get_shove()
		if absf(shove) > 0.99:
			seen[signf(shove)] = true
	assert_true(seen.has(1.0) and seen.has(-1.0), "it pushes both ways")


func test_fish_are_thrown_sideways_during_the_event() -> void:
	_tilt.arm(5, 3)
	var marble: Marble = _marble_at(Vector2(1200.0, 250.0))
	await wait_physics_frames(2)
	_run_until(Hazard.Phase.ACTIVE)
	var widest: float = 0.0
	for i: int in 50:
		_tilt.tick(STEP)
		await wait_physics_frames(1)
		widest = maxf(widest, absf(marble.linear_velocity.x))
	assert_gt(widest, 40.0, "the fish is shoved")
	assert_lt(absf(marble.linear_velocity.y), 1.0, "and only sideways")


func test_same_seed_same_events() -> void:
	_tilt.arm(9, 3)
	var plan: Array[float] = _tilt.get_schedule()
	_tilt.arm(9, 3)
	assert_eq(_tilt.get_schedule(), plan)
	assert_false(plan.is_empty())
