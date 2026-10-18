class_name TrackFlyover
extends SubViewportContainer
## Backdrop of the fake "Fishy Marble Run 3" home screen: a camera sweeps down the 3D map
## like a race game's course preview, while a few fish race along it. Built from the same
## 2D track the fake round is played on.

const FISH_COUNT: int = 9
const FISH_SCALE: float = 0.21
## Camera speed along the route, in 2D pixels per second.
const FLY_SPEED: float = 230.0
## How far ahead of the camera it looks, in pixels along the route.
const LOOK_AHEAD: float = 420.0
## Camera offset from the route: towards the viewer and up, in world units.
const CAMERA_OUT: float = 5.5
const CAMERA_UP: float = 1.6
const ORBIT: float = deg_to_rad(30.0)
const ORBIT_SPEED: float = 0.21
## Fish speeds along the route, in pixels per second.
const FISH_MIN_SPEED: float = 240.0
const FISH_MAX_SPEED: float = 330.0

var camera: Camera3D
var track_3d: Track3D
var viewport: SubViewport

var _track: Track
var _route: Curve2D
var _route_transform: Transform2D
var _length: float = 1.0
var _distance: float = 0.0
var _time: float = 0.0
var _fish: MultiMeshInstance3D
var _fish_distance: PackedFloat32Array = []
var _fish_speed: PackedFloat32Array = []
var _fish_depth: PackedFloat32Array = []
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
	viewport.add_child(FlatTo3D.make_environment())
	viewport.add_child(FlatTo3D.make_light())
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.far = 250.0
	viewport.add_child(camera)
	_track = TrackCatalog.instantiate(ReleaseSurprise.MAP_ID)
	track_3d = Track3D.new()
	track_3d.build(_track)
	viewport.add_child(track_3d)
	var centerline: Path2D = _track.get_node("Centerline")
	_route = centerline.curve
	_route_transform = FlatTo3D.local_to(centerline, _track)
	_length = maxf(_route.get_baked_length(), 1.0)
	_rng.randomize()
	_fish = _make_fish()
	viewport.add_child(_fish)
	for i: int in FISH_COUNT:
		_fish_distance.append(-float(i) * 70.0 - _rng.randf() * 40.0)
		_fish_speed.append(_rng.randf_range(FISH_MIN_SPEED, FISH_MAX_SPEED))
		_fish_depth.append(_rng.randf_range(-0.2, 0.2))
	_update(0.0)


func _exit_tree() -> void:
	if _track != null:
		_track.free()
		_track = null


func _process(delta: float) -> void:
	_update(delta)


## Where the route is [param distance] pixels from its start, as a 3D point.
func route_point(distance: float, depth: float = 0.0) -> Vector3:
	var at: Vector2 = _route.sample_baked(clampf(distance, 0.0, _length))
	return FlatTo3D.point(_route_transform * at, depth)


func _update(delta: float) -> void:
	_time += delta
	_distance = fmod(_distance + FLY_SPEED * delta, _length)
	var target: Vector3 = route_point(_distance + LOOK_AHEAD)
	var offset: Vector3 = Vector3(0.0, CAMERA_UP, CAMERA_OUT).rotated(
		Vector3.UP, sin(_time * ORBIT_SPEED) * ORBIT
	)
	camera.look_at_from_position(route_point(_distance) + offset, target)
	var multimesh: MultiMesh = _fish.multimesh
	for i: int in FISH_COUNT:
		_fish_distance[i] += _fish_speed[i] * delta
		# A fish that reaches the finish starts over a little behind the camera.
		if _fish_distance[i] > _length:
			_fish_distance[i] = _distance - _rng.randf_range(80.0, 300.0)
		var along: float = maxf(_fish_distance[i], 0.0)
		var here: Vector3 = route_point(along, _fish_depth[i])
		var ahead: Vector3 = route_point(along + 20.0, _fish_depth[i])
		var heading: Vector3 = (ahead - here).normalized()
		if heading.length() < 0.5:
			heading = Vector3.RIGHT
		var side: Vector3 = Vector3.BACK if heading.x >= 0.0 else Vector3.FORWARD
		var basis := Basis(heading, side.cross(heading), side).scaled_local(
			Vector3.ONE * FISH_SCALE
		)
		# Ride on top of the slab, not inside it.
		multimesh.set_instance_transform(i, Transform3D(basis, here + Vector3.UP * 0.12))


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
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-200.0, -200.0, -10.0), Vector3(400.0, 400.0, 20.0))
	return instance
