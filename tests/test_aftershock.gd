extends GutTest
## Earthquake Fault's random event: an aftershock hops the fish and shakes the view.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _hazard: AftershockHazard


func before_each() -> void:
	_track = TrackCatalog.instantiate("fault")
	add_child_autofree(_track)
	_hazard = _track.get_node("Aftershock") as AftershockHazard
	await wait_physics_frames(3)


func _run_until(phase: Hazard.Phase, limit: float = 100.0) -> bool:
	var spent: float = 0.0
	while _hazard.phase != phase and spent < limit:
		_hazard.tick(STEP)
		spent += STEP
	return _hazard.phase == phase


func test_the_map_has_an_aftershock_hazard() -> void:
	assert_true(_track.get_hazards().has(_hazard))
	assert_eq(_hazard.kind, "aftershock")


func test_the_view_shakes_through_the_whole_event() -> void:
	watch_signals(_track)
	_hazard.arm(4, 3)
	assert_true(_run_until(Hazard.Phase.ACTIVE))
	var warning_shakes: int = get_signal_emit_count(_track, "quake_shaken")
	assert_gt(warning_shakes, 3, "the warning rumbles")
	assert_true(_run_until(Hazard.Phase.IDLE))
	assert_gt(get_signal_emit_count(_track, "quake_shaken"), warning_shakes)


func test_fish_are_hopped_while_it_lasts() -> void:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = Vector2(900, 500)
	await wait_physics_frames(2)
	_hazard.arm(4, 3)
	assert_true(_run_until(Hazard.Phase.ACTIVE))
	for i: int in 30:
		_hazard.tick(STEP)
	await wait_physics_frames(2)
	assert_lt(marble.linear_velocity.y, -20.0, "hopped upward")


func test_no_hops_before_the_floor_shudders() -> void:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = Vector2(900, 500)
	await wait_physics_frames(2)
	_hazard.arm(4, 3)
	assert_true(_run_until(Hazard.Phase.TELEGRAPH))
	for i: int in 30:
		_hazard.tick(STEP)
	await wait_physics_frames(2)
	assert_almost_eq(marble.linear_velocity.y, 0.0, 1.0)


func test_it_never_opens_a_crack() -> void:
	var fault: QuakeFault = _track.get_node("Fault") as QuakeFault
	fault.reseed(1)
	_hazard.arm(4, 5)
	assert_true(_run_until(Hazard.Phase.ACTIVE))
	assert_true(_run_until(Hazard.Phase.IDLE))
	for crack: FaultCrack in fault.get_cracks():
		assert_false(crack.is_open())
