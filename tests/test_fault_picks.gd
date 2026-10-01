extends GutTest
## Earthquake Fault: which crack a quake opens, and what happens when the race ends.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _fault: QuakeFault


func before_each() -> void:
	_track = TrackCatalog.instantiate("fault")
	add_child_autofree(_track)
	_fault = _track.get_node("Fault") as QuakeFault
	# A body only takes its transform inside physics frames.
	await wait_physics_frames(3)


func _marble_at(pos: Vector2, gravity: float = 0.0) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = gravity
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


func _tick(seconds: float) -> void:
	for i: int in int(seconds / STEP):
		_fault.tick(STEP)


func _crack(node_name: String) -> FaultCrack:
	return _fault.get_node(node_name) as FaultCrack


## Presses as `count` different viewers.
func _spam(count: int, viewers: int = 0) -> void:
	for i: int in count:
		_fault.shake("viewer%d" % i, viewers)


func test_the_quake_skips_cracks_the_pack_has_passed() -> void:
	# A fish lower down than the first two cracks of the seeded order has passed them.
	_fault.reseed(3)
	var cracks: Array[FaultCrack] = _fault.get_cracks()
	var order: Array[FaultCrack] = []
	for index: int in _fault._order:
		order.append(cracks[index])
	var lead_y: float = (order[0].center().y + order[1].center().y) * 0.5 + 1.0
	var passed: Array[FaultCrack] = []
	for crack: FaultCrack in order:
		if crack.center().y < lead_y:
			passed.append(crack)
	_marble_at(Vector2(900, lead_y))
	_spam(QuakeFault.NEED_MIN)
	_tick(QuakeFault.RUMBLE_SECONDS + 0.1)
	var opened: Array[FaultCrack] = []
	for crack: FaultCrack in cracks:
		if crack.is_open():
			opened.append(crack)
	assert_eq(opened.size(), 1)
	if opened.size() == 1 and passed.size() < order.size():
		assert_false(passed.has(opened[0]), "the opened crack is below the fish")


func test_with_every_crack_passed_the_first_in_order_opens() -> void:
	_fault.reseed(3)
	_marble_at(Vector2(900, 2000.0))
	_spam(QuakeFault.NEED_MIN)
	_tick(QuakeFault.RUMBLE_SECONDS + 0.1)
	assert_true(_fault.get_cracks()[_fault._order[0]].is_open())


func test_freezing_ends_the_quakes_and_hides_the_meter() -> void:
	watch_signals(_fault)
	_fault.reseed(1)
	_fault.freeze()
	_tick(30.0)
	assert_eq(_fault.quake_count(), 0, "no quake after the race ended")
	assert_false(_fault.shake("late", 0))
	assert_signal_emitted_with_parameters(_fault, "meter_changed", [""])


func test_the_track_freezes_the_fault_when_hazards_stop() -> void:
	_fault.reseed(1)
	_track.stop_hazards()
	assert_false(_fault.is_armed())
