class_name TrackStyle
extends Node2D
## Dresses a track in a moody 2D underwater look: parallax silhouette layers, light
## shafts, mist, drifting motes, stone-textured walls and glowing pegs. Purely visual:
## colliders and physics are untouched. The colors of the pegs come from the track scene.

## Foreground sits over the fish (z 5) and their trails, under bursts (z 8) and names (z 10).
const FOREGROUND_Z: int = 7
const FOREGROUND_ALPHA: float = 0.82
## Keeps the foreground out of the spawn column and the finish zone, in world pixels.
const FOREGROUND_MARGIN: float = 170.0
## Bottom shapes are rooted this far below the frame (EnvLayer's floor line).
const FLOOR_BELOW_FRAME: float = 60.0

## Group of stone bodies that are not direct children of the track but are dressed like them.
const STONE_GROUP: StringName = &"track_stone"
const STONE_SHADER: Shader = preload("res://assets/shaders/env/stone.gdshader")
const FOG_SHADER: Shader = preload("res://assets/shaders/env/fog.gdshader")
const VIEW: Vector2 = Vector2(1920.0, 1080.0)
## Height of the scenery a parallax layer paints (ceiling shapes to floor line). A map taller
## than the base frame repeats it vertically so the layers never run out.
const LAYER_PERIOD: float = 1360.0
## Background shapes of a repeated (tall map) layer fade out over this many pixels at their base.
const SEAM_FADE: float = 140.0
const FOG_RECT: Rect2 = Rect2(-160.0, -260.0, 2240.0, 1500.0)
const PEG_GLOW_SIZE: float = 128.0
const FINISH_COLOR: Color = Color(1.0, 0.86, 0.3)

static var _glow_texture: GradientTexture2D

var _palette: Dictionary = {}
## World y of the bottom of the map's camera bounds (1080 on a one-screen map).
var _floor_y: float = EnvLayer.FLOOR_Y
var _time: float = 0.0
var _pegs: Array[Dictionary] = []
var _finish_glows: Array[Node2D] = []
var _rays: Array[Polygon2D] = []
var _fogs: Array[ColorRect] = []
var _motes: CPUParticles2D
## How far the map reaches below the base frame (0 for a one-screen map).
var _extra_height: float = 0.0


func dress(track: Track, style_id: String) -> void:
	_palette = TrackPalettes.PALETTES.get(
		style_id, TrackPalettes.PALETTES[TrackPalettes.DEFAULT_STYLE]
	)
	_floor_y = maxf(track.view_bounds.end.y, EnvLayer.FLOOR_Y)
	_extra_height = maxf(track.view_bounds.end.y - VIEW.y, 0.0)
	_hide_flat_artwork(track)
	_add_background()
	_add_rays()
	_add_layers()
	_add_fog()
	_add_motes()
	_dress_finish(track)
	_add_foreground(track, style_id)
	for child: Node in track.get_children():
		if child is StaticBody2D:
			_dress_body(child as StaticBody2D)
	# Parts nested under a map's own node (the floor plugs of a fault) opt in with this group.
	for node: Node in track.find_children("*", "StaticBody2D", true, false):
		if node.is_in_group(STONE_GROUP):
			_dress_body(node as StaticBody2D)


func _process(delta: float) -> void:
	_time += delta
	for peg: Dictionary in _pegs:
		var pulse: float = 0.72 + 0.28 * sin(_time * 1.6 + float(peg["phase"]))
		(peg["glow"] as Sprite2D).modulate.a = pulse
	for glow: Node2D in _finish_glows:
		glow.modulate.a = 0.75 + 0.25 * sin(_time * 2.2)
	for i: int in _rays.size():
		_rays[i].modulate.a = 0.7 + 0.3 * sin(_time * 0.5 + float(i) * 1.9)
	_follow_view()


## Mist, vignette and motes belong to the screen, not the map: keep them covering whatever
## part of the world the camera currently shows.
func _follow_view() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var view: Rect2 = get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	for fog: ColorRect in _fogs:
		fog.global_position = view.position
		fog.size = view.size
	if _motes != null:
		_motes.global_position = Vector2(view.get_center().x, view.end.y + 30.0)
		_motes.emission_rect_extents = Vector2(view.size.x * 0.5 + 40.0, 10.0)


func _hide_flat_artwork(track: Track) -> void:
	var backdrop: Node2D = track.get_node_or_null("Backdrop") as Node2D
	if backdrop != null:
		backdrop.visible = false
	var line: Node2D = track.get_node_or_null("Centerline/Line") as Node2D
	if line != null:
		line.visible = false
	# A map with several starts has a StartArea, StartArea2 and so on.
	for child: Node in track.get_children():
		if child is Polygon2D and child.name.begins_with("StartArea"):
			(child as Polygon2D).color = Color(_palette["rim"], 0.1)


func _parallax(scroll_scale: float, z: int) -> Parallax2D:
	var layer: Parallax2D = Parallax2D.new()
	layer.scroll_scale = Vector2(scroll_scale, scroll_scale)
	layer.z_index = z
	if _extra_height > 0.0:
		layer.repeat_size = Vector2(0.0, LAYER_PERIOD)
		layer.repeat_times = 3
	add_child(layer)
	return layer


func _add_background() -> void:
	var sky: Polygon2D = Polygon2D.new()
	sky.polygon = PackedVector2Array(
		[
			Vector2(-500, -500),
			Vector2(2420, -500),
			Vector2(2420, _floor_y + 500.0),
			Vector2(-500, _floor_y + 500.0)
		]
	)
	var top: Color = _palette["sky_top"]
	var bottom: Color = _palette["sky_bottom"]
	sky.vertex_colors = PackedColorArray([top, top, bottom, bottom])
	sky.z_index = -60
	add_child(sky)


func _add_rays() -> void:
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ray_color: Color = _palette["ray"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var layer: Parallax2D = _parallax(0.15, -55)
	for i: int in 6:
		var x: float = lerpf(-100.0, 1900.0, (float(i) + rng.randf()) / 6.0)
		var width: float = rng.randf_range(60.0, 160.0)
		var slant: float = rng.randf_range(160.0, 320.0)
		var ray: Polygon2D = Polygon2D.new()
		ray.polygon = PackedVector2Array(
			[
				Vector2(x, -100),
				Vector2(x + width, -100),
				Vector2(x + width * 2.6 - slant, 1100),
				Vector2(x - width * 1.4 - slant, 1100)
			]
		)
		var strong: Color = Color(ray_color, rng.randf_range(0.07, 0.14))
		var faint: Color = Color(ray_color, 0.0)
		ray.vertex_colors = PackedColorArray([strong, strong, faint, faint])
		ray.material = material
		layer.add_child(ray)
		_rays.append(ray)


func _add_layers() -> void:
	var kind: EnvLayer.Kind = _palette["layer_kind"]
	var far_kind: EnvLayer.Kind = _palette["far_kind"]
	# Far: big soft shapes, barely moving. Ceiling shapes hang from the top.
	_add_layer(_parallax(0.25, -50), far_kind, _palette["far"], 3, 9, 260.0, 520.0, false, 0.0)
	_add_layer(_parallax(0.25, -50), far_kind, _palette["far"], 4, 7, 160.0, 340.0, true, 0.0)
	# Mid: vegetation or shards closer to the action.
	_add_layer(_parallax(0.5, -40), kind, _palette["plant"], 5, 14, 200.0, 460.0, false, 30.0)
	_add_layer(_parallax(0.5, -40), far_kind, _palette["mid"], 6, 8, 120.0, 280.0, true, 0.0)


func _add_layer(
	parent: Node,
	kind: EnvLayer.Kind,
	color: Color,
	seed_value: int,
	count: int,
	min_height: float,
	max_height: float,
	from_top: bool,
	sway: float
) -> void:
	var layer: EnvLayer = EnvLayer.new()
	layer.kind = kind
	layer.color = color
	layer.highlight = Color(_palette["rim"], 0.18)
	layer.seed_value = seed_value
	layer.count = count
	layer.min_height = min_height
	layer.max_height = max_height
	layer.from_top = from_top
	layer.sway = sway * float(_palette["sway_scale"])
	if _extra_height > 0.0:
		layer.fade_base = SEAM_FADE
	parent.add_child(layer)


## Silhouettes drawn in front of the fish, so they vanish briefly behind them. Translucent
## as a whole (one group, so overlapping shapes do not darken each other) and never placed
## over the spawn column or the finish zone.
func _add_foreground(track: Track, style_id: String) -> void:
	var kinds: Array = TrackPalettes.FOREGROUND.get(
		style_id, TrackPalettes.FOREGROUND[TrackPalettes.DEFAULT_STYLE]
	)
	var blocked: Array[Vector2] = _foreground_blocked_ranges(track)
	var group: CanvasGroup = CanvasGroup.new()
	group.name = "Foreground"
	# Room for the sway shader to push shapes sideways without clipping them.
	group.fit_margin = 48.0
	group.z_index = FOREGROUND_Z
	group.modulate = Color(1.0, 1.0, 1.0, FOREGROUND_ALPHA)
	add_child(group)
	# Top shapes hang from above the frame (h includes the gap to the top of the frame),
	# bottom shapes rise from just below it.
	# Shapes hanging from the top would cover the starts up there, so they avoid every start.
	var blocked_top: Array[Vector2] = blocked + _extra_start_ranges(track)
	# A map whose fish race along the edges of the frame keeps the shapes low.
	var scale: float = float(_palette.get("foreground_height", 1.0))
	_add_foreground_layer(group, kinds[0], 21, 6, 290.0 * scale, 450.0 * scale, true, blocked_top)
	_add_foreground_layer(group, kinds[1], 22, 5, 130.0 * scale, 300.0 * scale, false, blocked)


func _add_foreground_layer(
	group: CanvasGroup,
	kind: EnvLayer.Kind,
	seed_value: int,
	slots: int,
	min_height: float,
	max_height: float,
	from_top: bool,
	blocked: Array[Vector2]
) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var placements: Array[Vector2] = []
	for i: int in slots:
		var x: float = lerpf(60.0, 1860.0, (float(i) + rng.randf_range(0.2, 0.8)) / float(slots))
		var height: float = rng.randf_range(min_height, max_height)
		var free: bool = true
		for span: Vector2 in blocked:
			if x > span.x and x < span.y:
				free = false
		if free:
			placements.append(Vector2(x, height if from_top else height + FLOOR_BELOW_FRAME))
	if placements.is_empty():
		return
	var layer: EnvLayer = EnvLayer.new()
	layer.kind = kind
	layer.color = _palette["near"]
	layer.highlight = Color(_palette["rim"], 0.22)
	layer.seed_value = seed_value
	layer.min_height = min_height
	layer.max_height = max_height + (0.0 if from_top else FLOOR_BELOW_FRAME)
	layer.from_top = from_top
	layer.floor_y = _floor_y
	layer.sway = 16.0 * float(_palette["sway_scale"])
	layer.placements = placements
	group.add_child(layer)


## X ranges the foreground keeps clear: the spawn column and the finish zone.
func _foreground_blocked_ranges(track: Track) -> Array[Vector2]:
	var ranges: Array[Vector2] = []
	var spawn: Marker2D = track.get_node_or_null("SpawnOrigin") as Marker2D
	if spawn != null:
		ranges.append(_start_range(track, spawn))
	var finish: Area2D = track.get_node_or_null("Finish") as Area2D
	var zone: CollisionShape2D = null
	if finish != null:
		zone = finish.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if zone != null and zone.shape is RectangleShape2D:
		var half: float = (zone.shape as RectangleShape2D).size.x * 0.5
		var center: float = zone.global_position.x
		ranges.append(Vector2(center - half - FOREGROUND_MARGIN, center + half + FOREGROUND_MARGIN))
	return ranges


## X ranges of the starts after the first, on a map with several.
func _extra_start_ranges(track: Track) -> Array[Vector2]:
	var ranges: Array[Vector2] = []
	var starts: Node = track.get_node_or_null("Starts")
	if starts == null:
		return ranges
	for child: Node in starts.get_children():
		if child is Marker2D:
			ranges.append(_start_range(track, child as Marker2D))
	return ranges


func _start_range(track: Track, start: Marker2D) -> Vector2:
	var width: float = float(track.spawn_columns) * track.spawn_spacing
	return Vector2(
		start.global_position.x - FOREGROUND_MARGIN,
		start.global_position.x + width + FOREGROUND_MARGIN
	)


func _add_fog() -> void:
	for spec: Array in [[-30, 0.14, 0.0], [3, 0.07, 0.6]]:
		var fog: ColorRect = ColorRect.new()
		# Covers the overview frame of every map, which reaches above and beside the base view.
		fog.position = FOG_RECT.position
		fog.size = FOG_RECT.size
		fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fog.z_index = int(spec[0])
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = FOG_SHADER
		material.set_shader_parameter("fog_color", _palette["fog"])
		material.set_shader_parameter("density", float(spec[1]))
		material.set_shader_parameter("vignette", float(spec[2]))
		fog.material = material
		add_child(fog)
		_fogs.append(fog)


func _add_motes() -> void:
	var motes: CPUParticles2D = CPUParticles2D.new()
	motes.amount = 70
	motes.lifetime = 14.0
	motes.preprocess = 14.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(VIEW.x * 0.5 + 40.0, 10.0)
	motes.position = Vector2(VIEW.x * 0.5, VIEW.y + 30.0)
	motes.direction = Vector2(0.15, -1.0)
	motes.spread = 25.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 30.0
	motes.initial_velocity_max = 80.0
	motes.scale_amount_min = 0.03
	motes.scale_amount_max = 0.09
	motes.texture = _get_glow_texture()
	motes.color = Color(_palette["mote"], 0.5)
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	motes.material = material
	motes.z_index = 3
	add_child(motes)
	_motes = motes


func _dress_body(body: StaticBody2D) -> void:
	var visual: Polygon2D = body.get_node_or_null("Visual") as Polygon2D
	if visual == null or visual.polygon.size() < 3:
		return
	if body.get_node_or_null("Collider") is CollisionShape2D:
		_dress_peg(visual)
	elif body is AnimatableBody2D:
		_dress_mover(visual)
	else:
		_dress_wall(visual)


func _dress_wall(visual: Polygon2D) -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = STONE_SHADER
	material.set_shader_parameter("dark_color", _palette["stone_dark"])
	material.set_shader_parameter("light_color", _palette["stone_light"])
	visual.material = material
	visual.color = Color.WHITE
	var ring: PackedVector2Array = visual.polygon + PackedVector2Array([visual.polygon[0]])
	var rim: Color = _palette["rim"]
	# A soft additive halo under a thin bright ink line reads as a lit edge.
	var halo: Line2D = _outline(ring, 9.0, Color(rim, 0.13))
	var halo_material: CanvasItemMaterial = CanvasItemMaterial.new()
	halo_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = halo_material
	visual.add_child(halo)
	visual.add_child(_outline(ring, 2.0, Color(rim, 0.7)))


## The stone texture is anchored to the world, so on a moving body it would slide across
## the shape. Movers keep their flat color and get a lit edge instead.
func _dress_mover(visual: Polygon2D) -> void:
	var ring: PackedVector2Array = visual.polygon + PackedVector2Array([visual.polygon[0]])
	var rim: Color = _palette["rim"]
	visual.add_child(_outline(ring, 2.0, Color(rim, 0.7)))


## Replaces the flat finish patch with a glowing gate that fills the whole finish zone.
func _dress_finish(track: Track) -> void:
	var finish: Area2D = track.get_node_or_null("Finish") as Area2D
	if finish == null:
		return
	var zone: CollisionShape2D = finish.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if zone == null or not zone.shape is RectangleShape2D:
		return
	var flat: Node2D = finish.get_node_or_null("Visual") as Node2D
	if flat != null:
		flat.visible = false
	var size: Vector2 = (zone.shape as RectangleShape2D).size
	var rect: Rect2 = Rect2(zone.position - size * 0.5, size)
	var gate: Node2D = Node2D.new()
	gate.name = "Gate"
	gate.z_index = 2
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	gate.material = material
	var fill: Polygon2D = Polygon2D.new()
	fill.polygon = PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	var faint: Color = Color(FINISH_COLOR, 0.0)
	var strong: Color = Color(FINISH_COLOR, 0.4)
	fill.vertex_colors = PackedColorArray([faint, faint, strong, strong])
	gate.add_child(fill)
	var ring: PackedVector2Array = fill.polygon + PackedVector2Array([fill.polygon[0]])
	gate.add_child(_outline(ring, 14.0, Color(FINISH_COLOR, 0.14)))
	gate.add_child(_outline(ring, 3.0, Color(FINISH_COLOR, 0.85)))
	finish.add_child(gate)
	_finish_glows.append(gate)


func _dress_peg(visual: Polygon2D) -> void:
	var glow_color: Color = visual.color
	visual.color = glow_color.lightened(0.25)
	var ring: PackedVector2Array = visual.polygon + PackedVector2Array([visual.polygon[0]])
	visual.add_child(_outline(ring, 2.5, glow_color.darkened(0.6)))
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in visual.polygon:
		center += point
	center /= float(visual.polygon.size())
	var radius: float = visual.polygon[0].distance_to(center)
	var glow: Sprite2D = Sprite2D.new()
	glow.texture = _get_glow_texture()
	glow.position = center
	glow.scale = Vector2.ONE * (radius * 5.0 / PEG_GLOW_SIZE)
	glow.modulate = Color(glow_color, 0.8)
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	glow.show_behind_parent = true
	visual.add_child(glow)
	_pegs.append({"glow": glow, "phase": center.x * 0.013 + center.y * 0.021})


func _outline(ring: PackedVector2Array, width: float, color: Color) -> Line2D:
	var line: Line2D = Line2D.new()
	line.points = ring
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	return line


static func _get_glow_texture() -> GradientTexture2D:
	if _glow_texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = gradient
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(1.0, 0.5)
		_glow_texture.width = int(PEG_GLOW_SIZE)
		_glow_texture.height = int(PEG_GLOW_SIZE)
	return _glow_texture
