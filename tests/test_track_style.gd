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


func test_mist_follows_the_view() -> void:
	var track: Track = TrackCatalog.instantiate("wreck")
	add_child_autofree(track)
	var style: TrackStyle = track.find_children("*", "TrackStyle", false, false)[0]
	var fog: ColorRect = style.find_children("*", "ColorRect", false, false)[0]
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(-300.0, -100.0))
	style._process(0.016)
	assert_eq(fog.global_position, Vector2(300.0, 100.0))
	get_viewport().canvas_transform = Transform2D.IDENTITY


func test_finish_zone_is_visible_and_inside_the_camera_view() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = TrackCatalog.instantiate(id)
		add_child_autofree(track)
		var finish: Area2D = track.get_node("Finish")
		assert_not_null(finish.get_node_or_null("Gate"), "%s finish gate" % id)
		var shape: RectangleShape2D = finish.get_node("CollisionShape2D").shape
		var zone: Rect2 = Rect2(finish.position - shape.size * 0.5, shape.size)
		assert_true(track.view_bounds.encloses(zone), "%s finish inside view_bounds" % id)


func test_moving_bodies_do_not_get_the_world_anchored_stone_texture() -> void:
	var track: Track = TrackCatalog.instantiate("wreck")
	add_child_autofree(track)
	var blades: Polygon2D = track.get_node("Propeller/Visual")
	assert_null(blades.material)
	var deck: Polygon2D = track.get_node("DeckA/Visual")
	assert_true(deck.material is ShaderMaterial)
