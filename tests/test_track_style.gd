extends GutTest
## The environment dressing is visual only: every map gets it and colliders stay as they were.


func test_every_map_is_dressed_with_a_known_style() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = TrackCatalog.instantiate(id)
		add_child_autofree(track)
		assert_true(TrackPalettes.PALETTES.has(track.style_id), "%s style exists" % id)
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


func test_tall_map_repeats_its_layers_and_extends_the_sky() -> void:
	var track: Track = TrackCatalog.instantiate("jelly")
	add_child_autofree(track)
	var style: TrackStyle = track.find_children("*", "TrackStyle", false, false)[0]
	var layers: Array[Node] = style.find_children("*", "Parallax2D", false, false)
	assert_false(layers.is_empty())
	for layer: Node in layers:
		assert_gt((layer as Parallax2D).repeat_size.y, 0.0, "layers repeat down a tall map")
	var short: Track = TrackCatalog.instantiate("wreck")
	add_child_autofree(short)
	var short_style: TrackStyle = short.find_children("*", "TrackStyle", false, false)[0]
	for layer: Node in short_style.find_children("*", "Parallax2D", false, false):
		assert_eq((layer as Parallax2D).repeat_size.y, 0.0, "one-screen maps are unchanged")


func test_moving_bodies_do_not_get_the_world_anchored_stone_texture() -> void:
	var track: Track = TrackCatalog.instantiate("wreck")
	add_child_autofree(track)
	var blades: Polygon2D = track.get_node("Propeller/Visual")
	assert_null(blades.material)
	var deck: Polygon2D = track.get_node("DeckA/Visual")
	assert_true(deck.material is ShaderMaterial)


func test_every_map_has_a_translucent_foreground_over_the_fish() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = TrackCatalog.instantiate(id)
		add_child_autofree(track)
		var group: CanvasGroup = track.find_child("Foreground", true, false)
		assert_not_null(group, "%s foreground" % id)
		assert_gt(group.z_index, 5, "%s foreground is in front of the fish" % id)
		assert_lt(group.z_index, 10, "%s foreground stays under the names" % id)
		assert_lt(group.modulate.a, 1.0, "%s foreground is translucent" % id)
		assert_gt(group.get_child_count(), 0, "%s has foreground shapes" % id)


func test_foreground_keeps_spawn_and_finish_clear() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = TrackCatalog.instantiate(id)
		add_child_autofree(track)
		var group: CanvasGroup = track.find_child("Foreground", true, false)
		var spawn_x: float = track.get_node("SpawnOrigin").global_position.x
		var finish_x: float = track.get_node("Finish").global_position.x
		for layer: EnvLayer in group.get_children():
			for at: Vector2 in layer.placements:
				var from_spawn: float = at.x - spawn_x
				assert_false(
					(
						from_spawn > -TrackStyle.FOREGROUND_MARGIN
						and from_spawn < 170.0 + TrackStyle.FOREGROUND_MARGIN
					),
					"%s spawn column" % id
				)
				assert_gt(
					absf(at.x - finish_x), TrackStyle.FOREGROUND_MARGIN, "%s finish zone" % id
				)


func test_foreground_leaves_colliders_alone() -> void:
	var track: Track = TrackCatalog.instantiate("wreck")
	add_child_autofree(track)
	var group: CanvasGroup = track.find_child("Foreground", true, false)
	assert_eq(group.find_children("*", "CollisionObject2D", true, false).size(), 0)


func test_every_style_has_a_palette_and_foreground() -> void:
	assert_true(TrackPalettes.PALETTES.has(TrackPalettes.DEFAULT_STYLE))
	for id: String in TrackPalettes.PALETTES:
		assert_true(TrackPalettes.FOREGROUND.has(id), "%s has a foreground" % id)
	for id: String in TrackPalettes.FOREGROUND:
		assert_true(TrackPalettes.PALETTES.has(id), "%s has a palette" % id)


func test_layers_repeat_sideways_on_every_map() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = TrackCatalog.instantiate(id)
		add_child_autofree(track)
		var style: TrackStyle = track.find_children("*", "TrackStyle", false, false)[0]
		for layer: Node in style.find_children("*", "Parallax2D", false, false):
			assert_eq((layer as Parallax2D).repeat_size.x, EnvLayer.WIDTH, "%s repeats" % id)


func test_sky_covers_a_view_far_wider_than_the_frame() -> void:
	var track: Track = TrackCatalog.instantiate("pachinko")
	add_child_autofree(track)
	var style: TrackStyle = track.find_children("*", "TrackStyle", false, false)[0]
	var sky: Polygon2D = null
	for node: Node in style.find_children("*", "Polygon2D", false, false):
		if (node as Polygon2D).z_index == -60:
			sky = node as Polygon2D
	assert_not_null(sky)
	var bounds: Rect2 = Rect2(sky.polygon[0], Vector2.ZERO)
	for point: Vector2 in sky.polygon:
		bounds = bounds.expand(point)
	var view: Rect2 = Rect2(-6000.0, -3000.0, 12000.0, 9000.0)
	assert_true(bounds.encloses(view), "sky reaches past a wide, zoomed out view")


func test_wide_view_adds_layer_repeats() -> void:
	var narrow: int = TrackStyle.repeat_times_for(Vector2(1920.0, 1080.0), Vector2(2400.0, 0.0))
	var wide: int = TrackStyle.repeat_times_for(Vector2(12000.0, 1080.0), Vector2(2400.0, 0.0))
	assert_eq(narrow, TrackStyle.MIN_REPEAT_TIMES)
	assert_gt(wide, narrow)
	assert_gte(wide, ceili(12000.0 / 2400.0) + 2, "copies to span the view plus slack")


func test_wide_view_raises_the_repeats_of_the_layers() -> void:
	var track: Track = TrackCatalog.instantiate("wreck")
	add_child_autofree(track)
	var style: TrackStyle = track.find_children("*", "TrackStyle", false, false)[0]
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(2000.0, 0.0)).scaled_local(
		Vector2(0.1, 0.1)
	)
	style._process(0.016)
	for layer: Node in style.find_children("*", "Parallax2D", false, false):
		assert_gt((layer as Parallax2D).repeat_times, TrackStyle.MIN_REPEAT_TIMES)
	get_viewport().canvas_transform = Transform2D.IDENTITY
