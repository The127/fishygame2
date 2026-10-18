class_name FourDView
extends SubViewportContainer
## Backdrop of the fake "Fishy Marble Run 4D": the track is a tesseract turning through the
## fourth dimension, and fish swim along its edges, smeared into ghosts of where they are
## in the other directions. Only a glimpse; the game glitches back before it gets playable.

## World units per tesseract unit.
const SIZE: float = 1.7
const FISH_COUNT: int = 8
const FISH_SCALE: float = 0.26
## Ghost copies trailing each fish, and how far behind in the 4D spin each one is.
const GHOSTS: int = 4
const GHOST_LAG: float = 0.22
const GHOST_ALPHA: float = 0.45
## Fish speed along an edge, in edges per second.
const FISH_MIN_SPEED: float = 0.35
const FISH_MAX_SPEED: float = 0.6
const BEAM_WIDTH: float = 0.3
const BEAM_THICKNESS: float = 0.06
## Edge colors: the near end of w and the far end.
const NEAR_COLOR: Color = Color(0.25, 0.95, 1.0)
const FAR_COLOR: Color = Color(1.0, 0.25, 0.85)
const BACKGROUND: Color = Color(0.05, 0.01, 0.1)
const CAMERA_DISTANCE: float = 8.5
const CAMERA_HEIGHT: float = 2.4
const CAMERA_SPEED: float = 0.25

var camera: Camera3D
var viewport: SubViewport

var _time: float = 0.0
var _corners: Array[Vector4] = Tesseract.vertices()
var _edges: Array[Vector2i] = Tesseract.edges()
var _beams: MultiMeshInstance3D
var _fish: MultiMeshInstance3D
var _ghosts: MultiMeshInstance3D
## Per fish: the corners it swims from and to, and how far along (0 to 1) it is.
var _fish_from: PackedInt32Array = []
var _fish_to: PackedInt32Array = []
var _fish_along: PackedFloat32Array = []
var _fish_speed: PackedFloat32Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.handle_input_locally = false
	add_child(viewport)
	viewport.add_child(_make_environment())
	camera = Camera3D.new()
	camera.fov = 50.0
	viewport.add_child(camera)
	_rng.randomize()
	_beams = _make_beams()
	viewport.add_child(_beams)
	_fish = _make_fish()
	viewport.add_child(_fish)
	_ghosts = _make_ghosts()
	viewport.add_child(_ghosts)
	for i: int in FISH_COUNT:
		_fish_from.append(_rng.randi_range(0, _corners.size() - 1))
		_fish_to.append(_fish_from[i] ^ (1 << _rng.randi_range(0, 3)))
		_fish_along.append(_rng.randf())
		_fish_speed.append(_rng.randf_range(FISH_MIN_SPEED, FISH_MAX_SPEED))
	_update(0.0)


func _process(delta: float) -> void:
	_update(delta)


## Where tesseract point [param p] shows in the 3D world, [param lag] seconds back in the spin.
func world_point(p: Vector4, lag: float = 0.0) -> Vector3:
	return Tesseract.project(Tesseract.spin(p, _time - lag)) * SIZE


## Number of fish ghosts drawn (for tests).
func ghost_count() -> int:
	return _ghosts.multimesh.instance_count


func _update(delta: float) -> void:
	_time += delta
	var angle: float = _time * CAMERA_SPEED
	camera.look_at_from_position(
		Vector3(sin(angle) * CAMERA_DISTANCE, CAMERA_HEIGHT, cos(angle) * CAMERA_DISTANCE),
		Vector3.ZERO
	)
	var beams: MultiMesh = _beams.multimesh
	for i: int in _edges.size():
		var a: Vector4 = Tesseract.spin(_corners[_edges[i].x], _time)
		var b: Vector4 = Tesseract.spin(_corners[_edges[i].y], _time)
		beams.set_instance_transform(
			i, _beam(Tesseract.project(a) * SIZE, Tesseract.project(b) * SIZE)
		)
		var w: float = clampf((a.w + b.w) * 0.25 + 0.5, 0.0, 1.0)
		beams.set_instance_color(i, FAR_COLOR.lerp(NEAR_COLOR, w))
	var fish: MultiMesh = _fish.multimesh
	var ghosts: MultiMesh = _ghosts.multimesh
	for i: int in FISH_COUNT:
		_swim(i, delta)
		var from: Vector4 = _corners[_fish_from[i]]
		var to: Vector4 = _corners[_fish_to[i]]
		var here: Vector4 = from.lerp(to, _fish_along[i])
		var ahead: Vector4 = from.lerp(to, _fish_along[i] + 0.05)
		var color: Color = HomeScene3D.fish_color(i)
		fish.set_instance_transform(i, _fish_transform(here, ahead, 0.0))
		for g: int in GHOSTS:
			var lag: float = float(g + 1) * GHOST_LAG
			var index: int = i * GHOSTS + g
			ghosts.set_instance_transform(index, _fish_transform(here, ahead, lag))
			var faded: Color = color.lerp(FAR_COLOR, float(g + 1) / float(GHOSTS))
			faded.a = GHOST_ALPHA * (1.0 - float(g) / float(GHOSTS))
			ghosts.set_instance_color(index, faded)


## Moves fish [param i] along its edge; at a corner it turns onto a random edge from there
## (every corner has one edge per axis: flip one of the four coordinates).
func _swim(i: int, delta: float) -> void:
	_fish_along[i] += _fish_speed[i] * delta
	if _fish_along[i] < 1.0:
		return
	_fish_from[i] = _fish_to[i]
	_fish_to[i] = _fish_from[i] ^ (1 << _rng.randi_range(0, 3))
	_fish_along[i] = 0.0


func _fish_transform(here: Vector4, ahead: Vector4, lag: float) -> Transform3D:
	var at: Vector3 = world_point(here, lag)
	var heading: Vector3 = (world_point(ahead, lag) - at).normalized()
	if heading.length() < 0.5:
		heading = Vector3.RIGHT
	var up: Vector3 = Vector3.UP if absf(heading.y) < 0.95 else Vector3.BACK
	var side: Vector3 = heading.cross(up).normalized()
	var basis := Basis(heading, side.cross(heading), side)
	return Transform3D(basis.scaled_local(Vector3.ONE * FISH_SCALE), at)


## A unit beam stretched from [param a] to [param b].
func _beam(a: Vector3, b: Vector3) -> Transform3D:
	var along: Vector3 = b - a
	var length: float = maxf(along.length(), 0.001)
	var up: Vector3 = Vector3.UP if absf(along.normalized().y) < 0.95 else Vector3.BACK
	var basis: Basis = Basis.looking_at(along / length, up)
	return Transform3D(basis.scaled_local(Vector3(1.0, 1.0, length)), (a + b) * 0.5)


func _make_beams() -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(BEAM_WIDTH, BEAM_THICKNESS, 1.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = _edges.size()
	return _instance(multimesh, "Beams")


func _make_fish() -> MultiMeshInstance3D:
	var mesh: ArrayMesh = HomeFishMesh.build()
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/home3d/fish.gdshader")
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = FISH_COUNT
	for i: int in FISH_COUNT:
		multimesh.set_instance_color(i, HomeScene3D.fish_color(i))
		multimesh.set_instance_custom_data(i, Color(_rng.randf() * TAU, 0.0, 0.0, 0.0))
	return _instance(multimesh, "Fish")


func _make_ghosts() -> MultiMeshInstance3D:
	var mesh: ArrayMesh = HomeFishMesh.build()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = FISH_COUNT * GHOSTS
	return _instance(multimesh, "Ghosts")


func _instance(multimesh: MultiMesh, node_name: String) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-20.0, -20.0, -20.0), Vector3(40.0, 40.0, 40.0))
	return instance


func _make_environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.5, 0.8)
	var holder := WorldEnvironment.new()
	holder.environment = env
	return holder
