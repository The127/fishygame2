extends GutTest
## Fish that doze off against a wall of the Gravity Flip map wake up when gravity turns.


func test_a_sleeping_fish_is_woken_until_gravity_is_back_to_full() -> void:
	var track: Track = TrackCatalog.instantiate("gravity")
	add_child_autofree(track)
	var flipper: GravityFlipper = track.get_node("Flipper") as GravityFlipper
	var marble: Marble = (load("res://scenes/marble.tscn") as PackedScene).instantiate() as Marble
	track.add_child(marble)
	marble.global_position = Vector2(466.0, 84.0)
	await wait_physics_frames(3)
	flipper.reseed(1)
	flipper.turn_to(GravityFlipper.Pull.DOWN)
	# Gravity is thin right after a flip, so a fish that dozes off again keeps hanging there.
	for i: int in 10:
		marble.sleeping = true
		flipper.tick(1.0 / 60.0)
		assert_false(marble.sleeping, "frame %d" % i)
	flipper.tick(GravityFlipper.RETURN_SECONDS)
	marble.sleeping = true
	flipper.tick(1.0 / 60.0)
	assert_true(marble.sleeping)
