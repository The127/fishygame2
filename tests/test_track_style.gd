extends GutTest
## The environment dressing is visual only: every map gets it and colliders stay as they were.


func test_every_map_is_dressed_with_a_known_style() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = TrackCatalog.instantiate(id)
		add_child_autofree(track)
		assert_true(TrackStyle.PALETTES.has(track.style_id), "%s style exists" % id)
		assert_eq(track.find_children("*", "TrackStyle", false, false).size(), 1)


func test_dressing_leaves_colliders_alone() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = TrackCatalog.instantiate(id)
		add_child_autofree(track)
		for body: Node in track.find_children("*", "StaticBody2D", false, false):
			var collider: Node = body.get_node("Collider")
			assert_true(collider is CollisionPolygon2D or collider is CollisionShape2D)
			assert_false(collider.get("disabled"))


func test_walls_get_stone_material_and_pegs_get_glow() -> void:
	var track: Track = TrackCatalog.instantiate("pachinko")
	add_child_autofree(track)
	var wall: Polygon2D = track.get_node("BowlLeft/Visual")
	assert_true(wall.material is ShaderMaterial)
	var peg: Polygon2D = track.get_node("Peg39/Visual")
	assert_gt(peg.find_children("*", "Sprite2D", false, false).size(), 0)


func test_unknown_style_falls_back_to_default() -> void:
	var track: Track = TrackCatalog.instantiate("zigzag")
	track.style_id = "does_not_exist"
	add_child_autofree(track)
	assert_eq(track.find_children("*", "TrackStyle", false, false).size(), 1)
