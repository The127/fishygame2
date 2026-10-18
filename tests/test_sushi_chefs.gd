extends GutTest
## Sushi Bar has several chefs. One "#chop" swings every ready knife, and the share of the field a
## race can lose counts all of them together.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _belts: SushiBelts


func before_each() -> void:
	_track = TrackCatalog.instantiate("sushi")
	add_child_autofree(_track)
	_belts = _track.get_node("Centerline") as SushiBelts
	_belts.set_physics_process(false)
	for chef: SushiChef in _belts.get_chefs():
		chef.set_physics_process(false)
	_belts.set_field_size(10)
	_belts.reseed(1)


## A fish floating under `chef`'s blade, with gravity off.
func _fish(chef: SushiChef) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = chef.global_position + Vector2(0.0, -Marble.RADIUS)
	return marble


func _run(seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		for chef: SushiChef in _belts.get_chefs():
			chef.tick(STEP)


func _chop(who: String) -> void:
	get_tree().call_group(SushiChef.CHAT_GROUP, "chop", who)


func test_the_chefs_stand_over_different_belts() -> void:
	var belts: Dictionary = {}
	for chef: SushiChef in _belts.get_chefs():
		belts[_belts.nearest_belt(chef.position.y)] = true
		for x: float in _belts.hump_xs(_belts.nearest_belt(chef.position.y)):
			assert_gt(absf(x - chef.position.x), SushiChef.BLADE_HALF + Marble.RADIUS * 2.0)
	assert_eq(_belts.get_chefs().size(), 3)
	assert_eq(belts.size(), 3, "one chef per belt")


func test_one_chop_swings_every_ready_knife() -> void:
	_chop("Ann")
	for chef: SushiChef in _belts.get_chefs():
		assert_eq(chef.get_phase(), SushiChef.Phase.WINDUP)
	assert_eq(_belts.meter_text(), "CHOP!")


func test_the_field_share_counts_every_chef() -> void:
	for chef: SushiChef in _belts.get_chefs():
		for i: int in 3:
			_fish(chef)
	for i: int in 40:
		_chop("viewer%d" % i)
		_run(0.25)
	var total: int = 0
	for chef: SushiChef in _belts.get_chefs():
		total += chef.chopped_count()
		assert_false(chef.can_swing())
	assert_eq(total, SushiChef.chop_limit(10))
	assert_eq(_belts.meter_text(), "THE CHEFS ARE FULL")


func test_one_meter_for_all_chefs() -> void:
	watch_signals(_belts)
	assert_eq(_belts.meter_text(), "SUSHI CHEFS   #chop")
	_chop("Ann")
	assert_signal_emitted_with_parameters(_belts, "meter_changed", ["CHOP!"])
	_run(SushiChef.WINDUP + SushiChef.STRIKE + 0.1)
	assert_eq(_belts.meter_text(), "SHARPENING THE KNIVES")
	_belts.stop_gimmick()
	assert_eq(_belts.meter_text(), "")
