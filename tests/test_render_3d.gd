extends GutTest
## The 3D stage is a mirror of the 2D world; these checks cover the mirroring math and setup.


func after_each() -> void:
	RenderMode.set_3d(false)


func test_render_mode_can_be_toggled() -> void:
	RenderMode.set_3d(true)
	assert_true(RenderMode.is_3d())
	RenderMode.set_3d(false)
	assert_false(RenderMode.is_3d())


func test_to_3d_flips_y_and_scales() -> void:
	var p: Vector3 = TrackMeshBuilder.to_3d(Vector2(100.0, 200.0), 0.5)
	assert_almost_eq(p.x, 1.0, 0.0001)
	assert_almost_eq(p.y, -2.0, 0.0001)
	assert_almost_eq(p.z, 0.5, 0.0001)


func test_extrude_rejects_degenerate_polygons() -> void:
	assert_null(TrackMeshBuilder.extrude(PackedVector2Array([Vector2.ZERO, Vector2.RIGHT])))


func test_extrude_makes_a_closed_slab_with_outward_normals() -> void:
	var square: PackedVector2Array = PackedVector2Array(
		[Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)]
	)
	var mesh: ArrayMesh = TrackMeshBuilder.extrude(square)
	assert_not_null(mesh)
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# Two cap triangles per face and two side triangles per edge: 2 caps * 2 + 4 edges * 2.
	assert_eq(vertices.size(), (2 * 2 + 4 * 2) * 3)
	var center: Vector3 = Vector3(
		0.5, -0.5, (TrackMeshBuilder.Z_FRONT + TrackMeshBuilder.Z_BACK) * 0.5
	)
	for t: int in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[t]
		var b: Vector3 = vertices[t + 1]
		var c: Vector3 = vertices[t + 2]
		var face_normal: Vector3 = (b - a).cross(c - a).normalized()
		# The winding must agree with the stored normal, and both must point away from the slab.
		assert_gt(face_normal.dot(normals[t]), 0.9, "winding matches normal")
		var centroid: Vector3 = (a + b + c) / 3.0
		assert_gt(normals[t].dot(centroid - center), 0.0, "normal points outward")


func test_extrude_handles_clockwise_and_counter_clockwise_input() -> void:
	var points: Array[Vector2] = [Vector2(0, 0), Vector2(60, 0), Vector2(60, 30), Vector2(0, 30)]
	var forward: ArrayMesh = TrackMeshBuilder.extrude(PackedVector2Array(points))
	points.reverse()
	var backward: ArrayMesh = TrackMeshBuilder.extrude(PackedVector2Array(points))
	assert_eq(
		(forward.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
		(backward.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	)


func test_builds_scenery_for_every_map() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = TrackCatalog.instantiate(id)
		add_child_autofree(track)
		var scenery: Node3D = autofree(TrackMeshBuilder.build(track))
		assert_gt(scenery.get_child_count(), 5, "%s has rocks and pegs" % id)


func test_track_visuals_can_be_hidden_without_touching_colliders() -> void:
	var track: Track = TrackCatalog.instantiate("pachinko")
	add_child_autofree(track)
	track.set_visuals_visible(false)
	for node: Node in track.find_children("*", "Polygon2D", true, false):
		assert_false((node as Polygon2D).visible)
	for node: Node in track.find_children("*", "CollisionPolygon2D", true, false):
		assert_false((node as CollisionPolygon2D).disabled)
	track.set_visuals_visible(true)
	for node: Node in track.find_children("*", "Polygon2D", true, false):
		assert_true((node as Polygon2D).visible)


func test_stage_follows_marbles_and_drops_the_ones_that_leave() -> void:
	var stage: Stage3D = add_child_autofree(Stage3D.new())
	stage.enabled = true
	var marble: Marble = add_child_autofree(load("res://scenes/marble.tscn").instantiate())
	marble.global_position = Vector2(300.0, 400.0)
	stage.attach_marbles([marble])
	var fish: Fish3D = stage.find_children("*", "Fish3D", true, false)[0]
	assert_almost_eq(fish.position.x, 3.0, 0.0001)
	assert_almost_eq(fish.position.y, -4.0, 0.0001)
	remove_child(marble)
	stage._sync_fish(0.016)
	await get_tree().process_frame
	assert_eq(stage.find_children("*", "Fish3D", true, false).size(), 0)
	add_child(marble)


func test_fish_turns_to_face_its_travel_direction() -> void:
	var fish: Fish3D = add_child_autofree(Fish3D.new())
	for i: int in 60:
		fish.swim(Vector2(-200.0, 0.0), 0.05)
	# Swimming left the nose points at -x but the fish stays upright.
	var nose: Vector3 = fish.basis * Vector3.RIGHT
	var up: Vector3 = fish.basis * Vector3.UP
	assert_lt(nose.x, -0.9)
	assert_gt(up.y, 0.9)
