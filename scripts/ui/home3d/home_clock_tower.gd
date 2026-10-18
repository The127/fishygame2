class_name HomeClockTower
extends Node3D
## A sunken Big Ben in the home screen backdrop. It shows the player's local time and is closed
## on Sundays: the faces go dark, the hands stop and a CLOSED sign hangs on the front.
## Built from a few merged primitive meshes; the faces are one shader quad each.

## Seconds between reads of the system clock. The hands tick, they do not sweep.
const TICK_INTERVAL: float = 0.25
## Where the hands stop when the tower is closed: drooping at half past six.
const CLOSED_HOUR_ANGLE: float = PI * 13.0 / 12.0
const CLOSED_MINUTE_ANGLE: float = PI
const SHAFT_WIDTH: float = 2.0
const STAGE_WIDTH: float = 2.5
const STAGE_Y: float = 8.0
const FACE_SIZE: float = 2.0
const STONE_COLOR: Color = Color(0.36, 0.38, 0.33)
const COPPER_COLOR: Color = Color(0.22, 0.52, 0.45)
const CORAL_COLOR: Color = Color(1.0, 0.45, 0.45)
const WINDOW_LIT: Color = Color(1.0, 0.85, 0.5)
const WINDOW_DARK: Color = Color(0.04, 0.07, 0.09)

## True while the tower is closed (it is Sunday).
var closed: bool = false
## Current hand angles in radians, clockwise from twelve: x hour, y minute, z second.
var hand_angles: Vector3 = Vector3.ZERO

var _faces: Array[ShaderMaterial] = []
var _windows: StandardMaterial3D
var _sign: Node3D
var _bubbles: CPUParticles3D
var _tick: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_child(_make_body())
	add_child(_make_windows())
	for side: int in 4:
		add_child(_make_face(side))
	_sign = _make_sign()
	add_child(_sign)
	_bubbles = _make_bubbles()
	add_child(_bubbles)
	set_clock(Time.get_datetime_dict_from_system())


func _process(delta: float) -> void:
	_time += delta
	_tick += delta
	if _tick >= TICK_INTERVAL:
		_tick = 0.0
		set_clock(Time.get_datetime_dict_from_system())
	if _sign.visible:
		_sign.rotation.x = sin(_time * 0.8) * 0.06


## Shows the time in [param datetime] (a dictionary with weekday, hour, minute and second, as
## from [method Time.get_datetime_dict_from_system]), or the closed tower on a Sunday.
func set_clock(datetime: Dictionary) -> void:
	closed = is_closed_on(int(datetime.get("weekday", Time.WEEKDAY_MONDAY)))
	if closed:
		hand_angles = Vector3(CLOSED_HOUR_ANGLE, CLOSED_MINUTE_ANGLE, 0.0)
	else:
		hand_angles = angles_for(
			int(datetime.get("hour", 0)),
			int(datetime.get("minute", 0)),
			int(datetime.get("second", 0))
		)
	for face: ShaderMaterial in _faces:
		face.set_shader_parameter("hour_angle", hand_angles.x)
		face.set_shader_parameter("minute_angle", hand_angles.y)
		face.set_shader_parameter("second_angle", hand_angles.z)
		face.set_shader_parameter("lit", 0.0 if closed else 1.0)
	_windows.emission_enabled = not closed
	_windows.albedo_color = WINDOW_DARK if closed else WINDOW_LIT
	_sign.visible = closed
	_bubbles.emitting = not closed


## True on the days the tower is closed.
static func is_closed_on(weekday: int) -> bool:
	return weekday == Time.WEEKDAY_SUNDAY


## Hand angles in radians, clockwise from twelve, for a time of day: x hour, y minute, z second.
static func angles_for(hour: int, minute: int, second: int) -> Vector3:
	var seconds: float = float(second)
	var minutes: float = float(minute) + seconds / 60.0
	var hours: float = float(hour % 12) + minutes / 60.0
	return Vector3(hours / 12.0 * TAU, minutes / 60.0 * TAU, seconds / 60.0 * TAU)


func _make_body() -> MeshInstance3D:
	var stone: SurfaceTool = SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(stone, Vector3(2.8, 0.8, 2.8), Vector3(0.0, 0.4, 0.0))
	_add_box(stone, Vector3(SHAFT_WIDTH, 6.2, SHAFT_WIDTH), Vector3(0.0, 3.9, 0.0))
	# Corner buttresses running up the shaft.
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var at: Vector2 = corner * (SHAFT_WIDTH * 0.5)
		_add_box(stone, Vector3(0.3, 6.6, 0.3), Vector3(at.x, 4.1, at.y))
	_add_box(stone, Vector3(STAGE_WIDTH, 2.6, STAGE_WIDTH), Vector3(0.0, STAGE_Y, 0.0))
	_add_box(stone, Vector3(2.8, 0.25, 2.8), Vector3(0.0, STAGE_Y + 1.4, 0.0))
	_add_box(stone, Vector3(2.0, 1.3, 2.0), Vector3(0.0, STAGE_Y + 2.15, 0.0))
	_add_box(stone, Vector3(2.4, 0.2, 2.4), Vector3(0.0, STAGE_Y + 2.9, 0.0))
	var body: ArrayMesh = stone.commit()
	body.surface_set_material(0, _flat_material(STONE_COLOR, 1.0))

	var copper: SurfaceTool = SurfaceTool.new()
	copper.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spire: CylinderMesh = CylinderMesh.new()
	spire.top_radius = 0.0
	spire.bottom_radius = 1.45
	spire.height = 3.6
	spire.radial_segments = 4
	spire.rings = 1
	copper.append_from(
		spire, 0, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0.0, STAGE_Y + 4.8, 0.0))
	)
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var pinnacle: CylinderMesh = CylinderMesh.new()
		pinnacle.top_radius = 0.0
		pinnacle.bottom_radius = 0.16
		pinnacle.height = 0.9
		pinnacle.radial_segments = 4
		pinnacle.rings = 1
		var at: Vector2 = corner * (STAGE_WIDTH * 0.5)
		copper.append_from(
			pinnacle, 0, Transform3D(Basis.IDENTITY, Vector3(at.x, STAGE_Y + 1.9, at.y))
		)
	body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, copper.commit_to_arrays())
	body.surface_set_material(1, _flat_material(COPPER_COLOR, 0.6))

	# Coral and barnacles creeping up the plinth and the shaft.
	var coral: SurfaceTool = SurfaceTool.new()
	coral.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1859  # Big Ben's first chime; any fixed seed keeps the growth the same each visit.
	for i: int in 14:
		var blob: SphereMesh = SphereMesh.new()
		blob.radial_segments = 6
		blob.rings = 4
		var size: float = rng.randf_range(0.12, 0.32)
		blob.radius = size
		blob.height = size * 1.4
		var side: float = rng.randf_range(-1.0, 1.0) * SHAFT_WIDTH * 0.5
		var y: float = rng.randf_range(0.6, 3.5) * (1.0 if i % 3 != 0 else 0.4)
		var pos: Vector3 = Vector3(side, y, SHAFT_WIDTH * 0.5)
		pos = Basis(Vector3.UP, float(i % 4) * PI * 0.5) * pos
		coral.append_from(blob, 0, Transform3D(Basis.IDENTITY, pos))
	body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, coral.commit_to_arrays())
	body.surface_set_material(2, _flat_material(CORAL_COLOR, 0.9))

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "Body"
	instance.mesh = body
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _make_windows() -> MeshInstance3D:
	var panes: SurfaceTool = SurfaceTool.new()
	panes.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in 4:
		var turn: Basis = Basis(Vector3.UP, float(side) * PI * 0.5)
		for row: int in 3:
			for column: int in 2:
				var x: float = (float(column) - 0.5) * 0.7
				var y: float = 2.4 + float(row) * 1.6
				var pos: Vector3 = turn * Vector3(x, y, SHAFT_WIDTH * 0.5 + 0.01)
				_add_box(panes, Vector3(0.22, 0.9, 0.04), pos, turn)
		# Belfry arches above the clock.
		_add_box(panes, Vector3(1.1, 0.7, 0.04), turn * Vector3(0.0, STAGE_Y + 2.1, 1.01), turn)
	_windows = StandardMaterial3D.new()
	_windows.albedo_color = WINDOW_LIT
	_windows.emission = WINDOW_LIT
	_windows.emission_energy_multiplier = 1.4
	_windows.emission_enabled = true
	var mesh: ArrayMesh = panes.commit()
	mesh.surface_set_material(0, _windows)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "Windows"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _make_face(side: int) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE * FACE_SIZE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/home3d/clock_face.gdshader")
	quad.material = material
	_faces.append(material)
	var face: MeshInstance3D = MeshInstance3D.new()
	face.name = "Face%d" % side
	face.mesh = quad
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var turn: Basis = Basis(Vector3.UP, float(side) * PI * 0.5)
	face.transform = Transform3D(turn, turn * Vector3(0.0, STAGE_Y, STAGE_WIDTH * 0.5 + 0.02))
	return face


func _make_sign() -> Node3D:
	# Pivot at the top so the sign swings in the current from its two chains.
	var pivot: Node3D = Node3D.new()
	pivot.name = "ClosedSign"
	pivot.position = Vector3(0.0, STAGE_Y - 1.5, SHAFT_WIDTH * 0.5 + 0.45)
	var chains: SurfaceTool = SurfaceTool.new()
	chains.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(chains, Vector3(0.04, 0.55, 0.04), Vector3(-0.6, -0.27, 0.0))
	_add_box(chains, Vector3(0.04, 0.55, 0.04), Vector3(0.6, -0.27, 0.0))
	_add_box(chains, Vector3(2.1, 0.75, 0.08), Vector3(0.0, -0.9, 0.0))
	var mesh: ArrayMesh = chains.commit()
	mesh.surface_set_material(0, _flat_material(Color(0.3, 0.2, 0.13), 1.0))
	var board: MeshInstance3D = MeshInstance3D.new()
	board.mesh = mesh
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(board)
	var label: Label3D = Label3D.new()
	label.name = "Label"
	label.text = "CLOSED"
	label.font = load("res://assets/fonts/Exo2.ttf")
	label.font_size = 96
	label.pixel_size = 0.005
	label.modulate = Color(1.0, 0.5, 0.42)
	label.outline_size = 0
	label.shaded = false
	label.position = Vector3(0.0, -0.9, 0.05)
	pivot.add_child(label)
	return pivot


func _make_bubbles() -> CPUParticles3D:
	var bubble: SphereMesh = SphereMesh.new()
	bubble.radius = 0.05
	bubble.height = 0.1
	bubble.radial_segments = 6
	bubble.rings = 3
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.7, 0.95, 1.0, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble.material = material
	var bubbles: CPUParticles3D = CPUParticles3D.new()
	bubbles.name = "Bubbles"
	bubbles.mesh = bubble
	bubbles.amount = 10
	bubbles.lifetime = 5.0
	bubbles.position = Vector3(0.0, STAGE_Y + 2.2, 0.0)
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(0.7, 0.2, 0.7)
	bubbles.direction = Vector3.UP
	bubbles.spread = 12.0
	bubbles.gravity = Vector3(0.0, 0.25, 0.0)
	bubbles.initial_velocity_min = 0.3
	bubbles.initial_velocity_max = 0.6
	bubbles.scale_amount_min = 0.6
	bubbles.scale_amount_max = 1.5
	bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return bubbles


static func _add_box(
	tool: SurfaceTool, size: Vector3, pos: Vector3, basis: Basis = Basis.IDENTITY
) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	tool.append_from(box, 0, Transform3D(basis, pos))


static func _flat_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
