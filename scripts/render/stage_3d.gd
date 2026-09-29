class_name Stage3D
extends CanvasLayer
## Underwater 3D view of the race, drawn behind the 2D layer. Physics stays in 2D:
## the stage only mirrors track colliders and marble positions. The camera looks
## straight at the physics plane so 3D and 2D coordinates line up 1:1, which keeps
## the 2D name labels aligned.

const SCALE: float = TrackMeshBuilder.SCALE
const VIEW_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const FOV: float = 30.0
const SEAWEED_COUNT: int = 26
const RAY_COUNT: int = 6

var enabled: bool = false:
	set(value):
		enabled = value
		_apply_enabled()

var _viewport: SubViewport
var _container: SubViewportContainer
var _world: Node3D
var _scenery: Node3D
var _fish_root: Node3D
var _fish: Dictionary[Marble, Fish3D] = {}


func _ready() -> void:
	layer = -1
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEW_SIZE)
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	_container.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_build_environment()
	_build_camera()
	_build_backdrop()
	_fish_root = Node3D.new()
	_world.add_child(_fish_root)
	_apply_enabled()


## Replaces the scenery with a mirror of `track`.
func set_track(track: Track) -> void:
	if _scenery != null:
		_world.remove_child(_scenery)
		_scenery.queue_free()
	_scenery = TrackMeshBuilder.build(track)
	_world.add_child(_scenery)


## Gives each marble a 3D fish that follows it until the marble leaves the scene.
func attach_marbles(marbles: Array[Marble]) -> void:
	clear_fish()
	for marble: Marble in marbles:
		var fish: Fish3D = Fish3D.new()
		fish.color = marble.color
		_fish_root.add_child(fish)
		_fish[marble] = fish
	_sync_fish(0.0)


func clear_fish() -> void:
	for fish: Fish3D in _fish.values():
		fish.queue_free()
	_fish.clear()


func _process(delta: float) -> void:
	if enabled:
		_sync_fish(delta)


func _sync_fish(delta: float) -> void:
	for marble: Marble in _fish.keys():
		var fish: Fish3D = _fish[marble]
		if not is_instance_valid(marble) or not marble.is_inside_tree():
			fish.queue_free()
			_fish.erase(marble)
			continue
		fish.position = TrackMeshBuilder.to_3d(marble.global_position)
		fish.swim(marble.linear_velocity, delta)
		fish.color = marble.display_color()


func _apply_enabled() -> void:
	if _container == null:
		return
	_container.visible = enabled
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	)


func _build_environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.1, 0.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.72, 0.85)
	environment.ambient_light_energy = 0.75
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.04, 0.28, 0.4)
	environment.fog_density = 0.012
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color(0.85, 0.97, 1.0)
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-50.0, -25.0, 0.0)
	_world.add_child(sun)


func _build_camera() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.fov = FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.far = 200.0
	# Distance at which the z=0 plane shows exactly VIEW_SIZE pixels tall.
	var half_height: float = VIEW_SIZE.y * 0.5 * SCALE
	var distance: float = half_height / tan(deg_to_rad(FOV * 0.5))
	camera.position = Vector3(VIEW_SIZE.x * 0.5 * SCALE, -half_height, distance)
	camera.current = true
	_world.add_child(camera)


func _build_backdrop() -> void:
	var center: Vector3 = Vector3(VIEW_SIZE.x * 0.5 * SCALE, -VIEW_SIZE.y * 0.5 * SCALE, 0.0)
	# Far wall of the tank.
	var wall: MeshInstance3D = MeshInstance3D.new()
	var wall_mesh: QuadMesh = QuadMesh.new()
	wall_mesh.size = Vector2(46.0, 26.0)
	wall.mesh = wall_mesh
	var wall_material: ShaderMaterial = ShaderMaterial.new()
	wall_material.shader = preload("res://assets/shaders/water/backdrop.gdshader")
	wall.material_override = wall_material
	wall.position = center + Vector3(0.0, 0.0, -9.0)
	_world.add_child(wall)
	# Shafts of light.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var ray_mesh: QuadMesh = QuadMesh.new()
	ray_mesh.size = Vector2(3.2, 20.0)
	for i: int in RAY_COUNT:
		var ray: MeshInstance3D = MeshInstance3D.new()
		ray.mesh = ray_mesh
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/water/light_rays.gdshader")
		material.set_shader_parameter("phase", rng.randf() * TAU)
		material.set_shader_parameter("strength", rng.randf_range(0.12, 0.26))
		ray.material_override = material
		ray.position = Vector3(
			lerpf(-2.0, 21.0, (float(i) + rng.randf()) / float(RAY_COUNT)),
			-3.0,
			rng.randf_range(-4.0, -1.5)
		)
		ray.rotation_degrees = Vector3(0.0, 0.0, -18.0 + rng.randf_range(-5.0, 5.0))
		_world.add_child(ray)
	_build_seaweed(rng)
	_build_bubbles(center)


func _build_seaweed(rng: RandomNumberGenerator) -> void:
	var blade: QuadMesh = QuadMesh.new()
	blade.size = Vector2(0.45, 2.2)
	blade.subdivide_depth = 8
	blade.center_offset = Vector3(0.0, 1.1, 0.0)
	var multi_mesh: MultiMesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = blade
	multi_mesh.instance_count = SEAWEED_COUNT
	for i: int in SEAWEED_COUNT:
		var height: float = rng.randf_range(0.6, 1.3)
		var t: Transform3D = Transform3D(Basis.from_scale(Vector3(1.0, height, 1.0)), Vector3.ZERO)
		t.origin = Vector3(
			rng.randf_range(-1.0, 21.0),
			-11.4 + rng.randf_range(0.0, 1.2),
			rng.randf_range(-7.0, -3.0)
		)
		multi_mesh.set_instance_transform(i, t)
	var weed: MultiMeshInstance3D = MultiMeshInstance3D.new()
	weed.multimesh = multi_mesh
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/water/seaweed.gdshader")
	weed.material_override = material
	_world.add_child(weed)


func _build_bubbles(center: Vector3) -> void:
	var bubbles: CPUParticles3D = CPUParticles3D.new()
	bubbles.amount = 70
	bubbles.lifetime = 12.0
	bubbles.preprocess = 12.0
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(10.5, 0.1, 2.0)
	bubbles.direction = Vector3.UP
	bubbles.spread = 6.0
	bubbles.gravity = Vector3.ZERO
	bubbles.initial_velocity_min = 0.7
	bubbles.initial_velocity_max = 1.3
	bubbles.scale_amount_min = 0.4
	bubbles.scale_amount_max = 1.4
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	mesh.radial_segments = 8
	mesh.rings = 4
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.8, 0.95, 1.0, 0.35)
	mesh.material = material
	bubbles.mesh = mesh
	bubbles.position = Vector3(center.x, -12.0, -0.6)
	_world.add_child(bubbles)
