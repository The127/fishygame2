extends GutTest
## Fish under the pulls of the Gravity Flip map.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"


func _track() -> Track:
	var track: Track = TrackCatalog.instantiate("gravity")
	add_child_autofree(track)
	return track


func _flipper(track: Track) -> GravityFlipper:
	return track.get_node("Flipper") as GravityFlipper


func test_a_fish_falls_up_after_the_flip() -> void:
	var track: Track = _track()
	var flipper: GravityFlipper = _flipper(track)
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = Vector2(300.0, 400.0)
	await wait_physics_frames(20)
	assert_gt(marble.linear_velocity.y, 0.0, "falls down at first")
	flipper.turn_to(GravityFlipper.Pull.UP)
	await wait_physics_frames(60)
	assert_lt(marble.linear_velocity.y, 0.0, "falls up after the flip")


func test_a_fish_falls_toward_the_finish_when_the_right_wall_is_the_floor() -> void:
	var track: Track = _track()
	var flipper: GravityFlipper = _flipper(track)
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = Vector2(300.0, 400.0)
	flipper.turn_to(GravityFlipper.Pull.RIGHT)
	await wait_physics_frames(60)
	assert_gt(marble.linear_velocity.x, 50.0)


func test_a_sleeping_fish_wakes_when_gravity_turns() -> void:
	var track: Track = _track()
	var flipper: GravityFlipper = _flipper(track)
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = Vector2(300.0, 400.0)
	await wait_physics_frames(2)
	marble.sleeping = true
	flipper.turn_to(GravityFlipper.Pull.UP)
	assert_false(marble.sleeping)
