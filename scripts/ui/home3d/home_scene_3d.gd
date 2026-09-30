class_name HomeScene3D
extends SubViewportContainer
## The 3D underwater backdrop of the home screen. Everything is built in code and drawn in its
## own viewport, behind the menu. Kept cheap for the web export: one instanced draw call each
## for the fish, kelp, rocks and glows, a handful of additive light shafts, no shadows.

const FISH_COUNT: int = 18
const KELP_COUNT: int = 46
const KELP_HEIGHT: float = 4.0
const ROCK_COUNT: int = 24
const GLOW_COUNT: int = 28
const SHAFT_COUNT: int = 7
const SEABED_Y: float = -3.2
const GOLDEN_RATIO_CONJUGATE: float = 0.618034
## Screen radius of a click (in world units at the fish) that frightens fish.
const SCARE_RADIUS: float = 2.6
## Clicks that land on a fish, in one visit, before one of the fish grows cat ears.
const EARS_CLICKS: int = 10
const FOG_COLOR: Color = Color(0.02, 0.09, 0.16)

var school: HomeFishSchool
var camera: Camera3D
var viewport: SubViewport

## Index of the fish wearing cat ears, or -1. Easter egg: nothing announces it.
var ears_fish: int = -1
## Clicks that landed on a fish so far.
var fish_clicks: int = 0

var _fish: MultiMeshInstance3D
var _ears: MeshInstance3D
var _fish_material: ShaderMaterial
var _world: Node3D
var _time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	viewport = SubViewport.new()
	viewport.transparent_bg = false
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.handle_input_locally = false
	add_child(viewport)
	var world: Node3D = Node3D.new()
	viewport.add_child(world)
	_world = world
	world.add_child(_make_environment())
	world.add_child(_make_light())
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.far = 90.0
	world.add_child(camera)
	_update_camera()
	world.add_child(_make_seabed())
	world.add_child(_make_rocks())
	world.add_child(_make_kelp())
	world.add_child(_make_glows())
	for shaft: MeshInstance3D in _make_shafts():
		world.add_child(shaft)
	world.add_child(_make_snow())
	school = HomeFishSchool.new(FISH_COUNT)
	_fish = _make_fish()
	world.add_child(_fish)
	_update_fish()


func _process(delta: float) -> void:
	_time += delta
	school.step(delta)
	_update_fish()
	_update_camera()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var hit: int = scare_at(click.position)
	if hit >= 0:
		fish_clicked(hit)
	accept_event()


## Frightens fish near the point [param screen_pos] (in this control's coordinates).
## Returns the fish that was clicked on, or -1.
func scare_at(screen_pos: Vector2) -> int:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var hit: int = school.fish_at(origin, direction)
	school.scare(origin, direction, SCARE_RADIUS)
	return hit


## Counts a click that landed on fish [param index]. On the tenth, that fish gets cat ears.
func fish_clicked(index: int) -> void:
	if ears_fish >= 0:
		return
	fish_clicks += 1
	if fish_clicks >= EARS_CLICKS:
		ears_fish = index
		_ears = MeshInstance3D.new()
		_ears.mesh = HomeFishMesh.build_ears(fish_color(index))
		_ears.material_override = _fish_material
		_ears.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(_ears)
		_update_fish()


## The body color of fish [param index].
static func fish_color(index: int) -> Color:
	return Color.from_hsv(fmod(float(index) * GOLDEN_RATIO_CONJUGATE, 1.0), 0.75, 0.95)


## Dune height of the seabed at world x/z. Mirrors seabed.gdshader.
static func seabed_height(x: float, z: float) -> float:
	return SEABED_Y + sin(x * 0.35) * cos(z * 0.28) * 0.5 + sin(x * 1.1 + z * 0.7) * 0.08


## Number of instanced fish (for tests).
func fish_count() -> int:
	return _fish.multimesh.instance_count


func _update_camera() -> void:
	var t: float = _time
	camera.position = Vector3(
		sin(t * 0.05) * 3.0, 1.3 + sin(t * 0.07) * 0.6, 11.0 + sin(t * 0.031) * 1.5
	)
	var target: Vector3 = Vector3(sin(t * 0.04) * 1.5, 0.8 + sin(t * 0.06) * 0.3, 0.0)
	camera.look_at_from_position(camera.position, target)


func _update_fish() -> void:
	var multimesh: MultiMesh = _fish.multimesh
	for i: int in school.count:
		multimesh.set_instance_transform(i, school.fish_transform(i))
	if _ears != null:
		_ears.transform = school.fish_transform(ears_fish)


func _make_environment() -> WorldEnvironment:
	var sky_material: ShaderMaterial = ShaderMaterial.new()
	sky_material.shader = load("res://assets/shaders/home3d/water_sky.gdshader")
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.3, 0.45)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_density = 0.04
	env.fog_sky_affect = 0.0
	var holder: WorldEnvironment = WorldEnvironment.new()
	holder.environment = env
	return holder


func _make_light() -> DirectionalLight3D:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-70.0, 20.0, 0.0)
	light.light_color = Color(0.35, 0.75, 0.95)
	light.light_energy = 1.0
	return light


func _make_seabed() -> MeshInstance3D:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80.0, 50.0)
	plane.subdivide_width = 60
	plane.subdivide_depth = 40
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/home3d/seabed.gdshader")
	plane.material = material
	var seabed: MeshInstance3D = MeshInstance3D.new()
	seabed.mesh = plane
	seabed.position = Vector3(0.0, SEABED_Y, -12.0)
	seabed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return seabed


func _make_rocks() -> MultiMeshInstance3D:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radial_segments = 9
	sphere.rings = 5
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	sphere.material = material
	var multimesh: MultiMesh = _new_multimesh(sphere, ROCK_COUNT, false)
	for i: int in ROCK_COUNT:
		var x: float = _rng.randf_range(-24.0, 24.0)
		var z: float = _rng.randf_range(-26.0, -2.0)
		var size: Vector3 = Vector3(
			_rng.randf_range(0.6, 2.4), _rng.randf_range(0.4, 1.3), _rng.randf_range(0.6, 2.0)
		)
		var basis: Basis = Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(size)
		# Sunk a third into the sand so they do not float on the dunes.
		var pos: Vector3 = Vector3(x, seabed_height(x, z) + size.y * 0.15, z)
		multimesh.set_instance_transform(i, Transform3D(basis, pos))
		multimesh.set_instance_color(i, Color(0.05, 0.09, 0.11) * _rng.randf_range(0.7, 1.4))
	return _multimesh_instance(multimesh)


func _make_kelp() -> MultiMeshInstance3D:
	var blade: QuadMesh = QuadMesh.new()
	blade.size = Vector2(0.35, KELP_HEIGHT)
	blade.center_offset = Vector3(0.0, KELP_HEIGHT * 0.5, 0.0)
	blade.subdivide_depth = 8
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/home3d/kelp.gdshader")
	material.set_shader_parameter("blade_height", KELP_HEIGHT)
	blade.material = material
	var multimesh: MultiMesh = _new_multimesh(blade, KELP_COUNT, true)
	for i: int in KELP_COUNT:
		var x: float = _rng.randf_range(-22.0, 22.0)
		var z: float = _rng.randf_range(-22.0, -1.0)
		var scale: float = _rng.randf_range(0.6, 1.5)
		var basis: Basis = Basis(Vector3.UP, _rng.randf() * PI).scaled_local(Vector3.ONE * scale)
		var pos: Vector3 = Vector3(x, seabed_height(x, z) - 0.1, z)
		multimesh.set_instance_transform(i, Transform3D(basis, pos))
		multimesh.set_instance_color(i, Color.from_hsv(_rng.randf_range(0.35, 0.5), 0.5, 1.0))
		multimesh.set_instance_custom_data(i, Color(_rng.randf() * TAU, 0.0, 0.0, 0.0))
	return _multimesh_instance(multimesh)


func _make_glows() -> MultiMeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/home3d/glow.gdshader")
	quad.material = material
	var multimesh: MultiMesh = _new_multimesh(quad, GLOW_COUNT, true)
	for i: int in GLOW_COUNT:
		var x: float = _rng.randf_range(-20.0, 20.0)
		var z: float = _rng.randf_range(-20.0, 3.0)
		var floating: bool = i % 3 == 0
		var y: float = _rng.randf_range(0.0, 6.0) if floating else seabed_height(x, z) + 0.4
		var size: float = _rng.randf_range(1.2, 3.2)
		multimesh.set_instance_transform(
			i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), Vector3(x, y, z))
		)
		var hue: float = 0.5 if i % 2 == 0 else 0.4
		multimesh.set_instance_color(i, Color.from_hsv(hue, _rng.randf_range(0.5, 0.9), 1.0, 0.7))
		multimesh.set_instance_custom_data(i, Color(_rng.randf() * TAU, 0.0, 0.0, 0.0))
	return _multimesh_instance(multimesh)


func _make_shafts() -> Array[MeshInstance3D]:
	var shafts: Array[MeshInstance3D] = []
	var shader: Shader = load("res://assets/shaders/home3d/shaft.gdshader")
	for i: int in SHAFT_COUNT:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(_rng.randf_range(2.5, 6.0), 24.0)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("phase", _rng.randf() * TAU)
		material.set_shader_parameter("shimmer_speed", _rng.randf_range(0.4, 0.9))
		quad.material = material
		var shaft: MeshInstance3D = MeshInstance3D.new()
		shaft.mesh = quad
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var x: float = lerpf(-18.0, 18.0, (float(i) + _rng.randf()) / SHAFT_COUNT)
		shaft.position = Vector3(x, 7.0, _rng.randf_range(-12.0, -2.0))
		shaft.rotation_degrees = Vector3(
			0.0, _rng.randf_range(-25.0, 25.0), _rng.randf_range(8.0, 22.0)
		)
		shafts.append(shaft)
	return shafts


func _make_snow() -> CPUParticles3D:
	var flake: SphereMesh = SphereMesh.new()
	flake.radius = 0.035
	flake.height = 0.07
	flake.radial_segments = 6
	flake.rings = 3
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.5, 0.9, 1.0, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake.material = material
	var snow: CPUParticles3D = CPUParticles3D.new()
	snow.mesh = flake
	snow.amount = 140
	snow.lifetime = 16.0
	snow.preprocess = 16.0
	snow.position = Vector3(0.0, 3.0, -3.0)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(18.0, 7.0, 10.0)
	snow.direction = Vector3.DOWN
	snow.spread = 25.0
	snow.gravity = Vector3.ZERO
	snow.initial_velocity_min = 0.08
	snow.initial_velocity_max = 0.3
	snow.scale_amount_min = 0.5
	snow.scale_amount_max = 1.6
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return snow


func _make_fish() -> MultiMeshInstance3D:
	var mesh: ArrayMesh = HomeFishMesh.build()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/home3d/fish.gdshader")
	_fish_material = material
	mesh.surface_set_material(0, material)
	var multimesh: MultiMesh = _new_multimesh(mesh, FISH_COUNT, true)
	for i: int in FISH_COUNT:
		multimesh.set_instance_color(i, fish_color(i))
		multimesh.set_instance_custom_data(i, Color(_rng.randf() * TAU, 0.0, 0.0, 0.0))
	return _multimesh_instance(multimesh)


func _new_multimesh(mesh: Mesh, count: int, custom_data: bool) -> MultiMesh:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = custom_data
	multimesh.mesh = mesh
	multimesh.instance_count = count
	return multimesh


func _multimesh_instance(multimesh: MultiMesh) -> MultiMeshInstance3D:
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Instances span the whole scene and the camera moves; skip per-frame culling maths.
	instance.custom_aabb = AABB(Vector3(-40.0, -10.0, -40.0), Vector3(80.0, 30.0, 60.0))
	return instance
