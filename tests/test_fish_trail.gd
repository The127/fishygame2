extends GutTest


func test_every_kind_makes_a_modest_emitter() -> void:
	for kind: int in FishTrail.Kind.size():
		var trail: CPUParticles2D = FishTrail.make(kind)
		assert_not_null(trail.texture, "kind %d has a texture" % kind)
		assert_false(trail.local_coords, "kind %d stays in world space" % kind)
		assert_lte(trail.amount, 24, "kind %d keeps the particle count low" % kind)
		trail.free()


func test_marble_swaps_its_trail_when_the_kind_changes() -> void:
	var marble: Marble = Marble.new()
	add_child_autofree(marble)
	var before: int = marble.get_child_count()
	marble.trail = FishTrail.Kind.STARS
	await wait_frames(2)
	assert_eq(marble.get_child_count(), before, "the old emitter is replaced, not stacked")
