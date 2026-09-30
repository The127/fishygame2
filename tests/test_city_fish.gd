extends GutTest
## Sunken City with real fish: the trigger zones that set ruins off, the tower that throws a fish
## in its way, and the gaps the collapses open and seal.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0
## Ruins whose floor patch crumbles (their gap starts shut), then the ones that seal a gap.
const OPENING: Array[int] = [0, 1]
const SEALING: Array[int] = [2, 3]

var _track: Track
var _hazard: RuinHazard


func before_each() -> void:
	_track = TrackCatalog.instantiate("city")
	add_child_autofree(_track)
	_hazard = _track.get_hazards()[0] as RuinHazard


func _arm(seed_value: int = 3, frequency: int = 5) -> void:
	_hazard.arm(seed_value, frequency)


func _bring_down(index: int) -> bool:
	_hazard.trigger(index)
	var spent: float = 0.0
	while _hazard.stage_of(index) != RuinHazard.Stage.FALLEN and spent < 20.0:
		_hazard.tick(STEP)
		spent += STEP
	return _hazard.stage_of(index) == RuinHazard.Stage.FALLEN


func _bring_down_all() -> void:
	for i: int in _hazard.ruin_count():
		_bring_down(i)


func _marble_at(pos: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


## World position of the middle of the trigger zone or sweep area of ruin `index`.


func _zone_center(index: int, zone_name: String) -> Vector2:
	var ruin: Node2D = _hazard.get_ruins()[index]
	return (ruin.get_node(zone_name) as Area2D).global_position


## Drops a fish `height` above the gap of ruin `index` and returns how far below the lane it got.


func _drop_fish_over(index: int, height: float = 60.0) -> float:
	# Let the slabs take their poses in the physics server first.
	for i: int in 2:
		await get_tree().physics_frame
	var ruin: Node2D = _hazard.get_ruins()[index]
	var marble: Marble = _marble_at(ruin.global_position + Vector2(0.0, -height))
	for i: int in 100:
		await get_tree().physics_frame
	return marble.global_position.y - ruin.global_position.y


func test_a_fish_entering_the_trigger_zone_sets_the_ruin_off() -> void:
	_arm()
	for i: int in 2:
		await get_tree().physics_frame
	_marble_at(_zone_center(4, "Trigger"))
	for i: int in 6:
		await get_tree().physics_frame
	assert_ne(_hazard.stage_of(4), RuinHazard.Stage.STANDING, "the zone's ruin is going down")
	assert_eq(_hazard.stage_of(5), RuinHazard.Stage.STANDING, "the ruins elsewhere are not")
	assert_eq(_hazard.stage_of(0), RuinHazard.Stage.STANDING)


func test_a_ruin_that_is_not_live_ignores_the_fish() -> void:
	_arm(1, 1)
	var dead: int = _live_set().find(false)
	assert_gte(dead, 0, "seed 1 at level 1 leaves a ruin out")
	for i: int in 2:
		await get_tree().physics_frame
	_marble_at(_zone_center(dead, "Trigger"))
	for i: int in 10:
		await get_tree().physics_frame
	assert_eq(_hazard.stage_of(dead), RuinHazard.Stage.STANDING)


func test_a_falling_tower_throws_the_fish_in_its_way() -> void:
	_arm()
	for i: int in 2:
		await get_tree().physics_frame
	var marble: Marble = _marble_at(_zone_center(4, "Sweep"))
	_hazard.trigger(4)
	var best_lift: float = 0.0
	for i: int in 300:
		await get_tree().physics_frame
		best_lift = maxf(best_lift, -marble.linear_velocity.y)
	assert_gt(best_lift, 100.0, "the fish is thrown up by the falling tower")


func test_fish_stay_on_a_floor_patch_and_fall_through_an_open_gap() -> void:
	# Before any collapse: the first gaps are covered, the last ones are open.
	var on_patch: float = await _drop_fish_over(0)
	assert_lt(on_patch, 45.0, "a fish stays on the floor patch")
	# The slab hangs 175 px above the gap, so the fish starts under it.
	var through: float = await _drop_fish_over(2, 100.0)
	assert_gt(through, 100.0, "a fish falls through an open gap")


func test_after_the_collapses_the_shortcuts_work_and_the_sealed_gaps_hold() -> void:
	_arm()
	_bring_down_all()
	# Let the deferred collider changes and the moved slabs reach the physics server.
	for i: int in 3:
		await get_tree().physics_frame
	var shortcut: float = await _drop_fish_over(0)
	assert_gt(shortcut, 100.0, "a fish falls through the gap the floor patch left")
	var sealed: float = await _drop_fish_over(2)
	assert_lt(sealed, 45.0, "a fish stays on the slab that sealed the gap")


func test_a_cut_short_event_leaves_every_floor_patch_solid() -> void:
	_arm()
	_hazard.trigger(0)
	_hazard.trigger(1)
	for i: int in 30:
		_hazard.tick(STEP)
	# Cut the event short and start over, all in one frame, like the next race starting.
	_hazard.disarm()
	_arm()
	for i: int in 3:
		await get_tree().physics_frame
	for index: int in OPENING + SEALING:
		var ruin: Node2D = _hazard.get_ruins()[index]
		var collider: CollisionPolygon2D = ruin.get_node("Slab/Collider") as CollisionPolygon2D
		assert_false(collider.disabled, "every slab collides again")
