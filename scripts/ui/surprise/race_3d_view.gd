class_name Race3DView
extends CanvasLayer
## The fake "Fishy Marble Run 3" race view: the normal 2D race, drawn in 3D. The track is
## extruded into slabs, the fish are 3D fish, and a tilted perspective camera follows the
## 2D race camera, so every race rule, chat command and payout keeps working untouched.
## Sits under the overlay and control panel; the owner hides the 2D track and fish.

## Below the default canvas layer, so the overlay (layer 1) and panel draw on top.
const VIEW_LAYER: int = -1
const FOV: float = 40.0
## Fish mesh scale; the mesh is about 1.6 units long, the 2D fish about 30 pixels.
const FISH_SCALE: float = 0.21
const MAX_FISH: int = 64
## Below this speed (pixels per second) a fish keeps its last heading.
const TURN_MIN_SPEED: float = 25.0
const TURN_RATE: float = 8.0
## Camera tilt: how far above the track it looks down, and its slow side to side sway.
const PITCH: float = deg_to_rad(9.0)
const YAW: float = deg_to_rad(12.0)
const YAW_SWAY: float = deg_to_rad(10.0)
const YAW_SWAY_SPEED: float = 0.13
## Name tags sit this far above a fish, in world units.
const LABEL_LIFT: float = 0.32
const LABEL_SIZE: int = 18

var camera: Camera3D
var track_3d: Track3D
var viewport: SubViewport

var _container: SubViewportContainer
var _labels: Control
var _fish: MultiMeshInstance3D
var _headings: Dictionary[int, Vector3] = {}
var _tags: Dictionary[int, Label] = {}
var _time: float = 0.0


func _ready() -> void:
	layer = VIEW_LAYER
	_container = SubViewportContainer.new()
	_container.name = "View"
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.handle_input_locally = false
	_container.add_child(viewport)
	viewport.add_child(FlatTo3D.make_environment())
	viewport.add_child(FlatTo3D.make_light())
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.1
	camera.far = 250.0
	viewport.add_child(camera)
	track_3d = Track3D.new()
	viewport.add_child(track_3d)
	_fish = _make_fish()
	viewport.add_child(_fish)
	_labels = Control.new()
	_labels.name = "Names"
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_labels)


## Rebuilds the 3D track from [param track] (a new map was loaded).
func show_track(track: Track) -> void:
	track_3d.build(track)


## Moves the 3D fish, name tags and camera to match the 2D race this frame.
func update(marbles: Array[Marble], view: Camera2D, delta: float) -> void:
	_time += delta
	track_3d.sync()
	_place_camera(view)
	var multimesh: MultiMesh = _fish.multimesh
	var shown: int = 0
	var seen: Dictionary[int, bool] = {}
	for marble: Marble in marbles:
		if not marble.visible or shown >= MAX_FISH:
			continue
		var at: Vector3 = FlatTo3D.point(marble.global_position)
		multimesh.set_instance_transform(shown, Transform3D(_basis_for(marble, delta), at))
		multimesh.set_instance_color(shown, marble.color)
		multimesh.set_instance_custom_data(shown, Color(float(marble.id) * 1.7, 0.0, 0.0, 0.0))
		_tag(marble, at + Vector3.UP * LABEL_LIFT)
		seen[marble.id] = true
		shown += 1
	multimesh.visible_instance_count = shown
	for id: int in _tags.keys():
		if not seen.has(id):
			_tags[id].queue_free()
			_tags.erase(id)
			_headings.erase(id)


## Number of fish drawn right now (for tests).
func fish_count() -> int:
	return _fish.multimesh.visible_instance_count


func _place_camera(view: Camera2D) -> void:
	var zoom: float = maxf(view.zoom.x, 0.01)
	var height: float = view.get_viewport_rect().size.y / zoom * FlatTo3D.UNIT
	var distance: float = height * 0.5 / tan(deg_to_rad(FOV) * 0.5)
	var target: Vector3 = FlatTo3D.point(view.get_screen_center_position())
	var yaw: float = YAW + sin(_time * YAW_SWAY_SPEED) * YAW_SWAY
	var offset: Vector3 = Vector3(0.0, 0.0, distance).rotated(Vector3.RIGHT, -PITCH).rotated(
		Vector3.UP, yaw
	)
	camera.look_at_from_position(target + offset, target)


## The fish faces where it swims; its back stays up whichever way it goes.
func _basis_for(marble: Marble, delta: float) -> Basis:
	var velocity: Vector2 = marble.replay_velocity if marble.replaying else marble.linear_velocity
	var heading: Vector3 = _headings.get(marble.id, Vector3.RIGHT)
	if velocity.length() > TURN_MIN_SPEED:
		var wanted: Vector3 = Vector3(velocity.x, -velocity.y, 0.0).normalized()
		heading = heading.lerp(wanted, clampf(TURN_RATE * delta, 0.0, 1.0)).normalized()
		if heading.length() < 0.5:
			heading = wanted
	_headings[marble.id] = heading
	var side: Vector3 = Vector3.BACK if heading.x >= 0.0 else Vector3.FORWARD
	return Basis(heading, side.cross(heading), side).scaled_local(Vector3.ONE * FISH_SCALE)


func _tag(marble: Marble, at: Vector3) -> void:
	if not _tags.has(marble.id):
		var tag := Label.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiStyle.style_label(tag, LABEL_SIZE, 700, Color.WHITE)
		tag.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		tag.add_theme_constant_override("outline_size", 6)
		_labels.add_child(tag)
		_tags[marble.id] = tag
	var tag: Label = _tags[marble.id]
	tag.text = marble.label_text
	tag.visible = not camera.is_position_behind(at) and marble.label_text != ""
	if tag.visible:
		var to_screen: Vector2 = _container.size / Vector2(viewport.size).max(Vector2.ONE)
		var screen: Vector2 = camera.unproject_position(at) * to_screen
		tag.size = tag.get_minimum_size()
		tag.position = screen - Vector2(tag.size.x * 0.5, tag.size.y)


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
	multimesh.instance_count = MAX_FISH
	multimesh.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.name = "Fish"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The fish roam the whole map and the camera moves; skip per-frame culling maths.
	instance.custom_aabb = AABB(Vector3(-200.0, -200.0, -10.0), Vector3(400.0, 400.0, 20.0))
	return instance
