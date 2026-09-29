class_name Fish3D
extends Node3D
## A 3D fish that mirrors a 2D marble. It only swims in the XY plane: it faces its
## travel direction, turning by yawing around the vertical axis so it stays right
## side up when it swims left.

const BODY_SHADER: Shader = preload("res://assets/shaders/water/fish_body.gdshader")
const SPEED_FLOOR: float = 20.0

var color: Color = Color.WHITE:
	set(value):
		color = value
		_apply_color()

var _pitch: float = 0.0
var _yaw: float = 0.0
var _time: float = randf() * TAU
var _body_material: ShaderMaterial
var _fin_material: StandardMaterial3D
var _tail: Node3D


func _init() -> void:
	_body_material = ShaderMaterial.new()
	_body_material.shader = BODY_SHADER
	_fin_material = StandardMaterial3D.new()
	_fin_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fin_material.roughness = 0.6
	_build()
	_apply_color()


## Swims toward `velocity` (marble velocity, y down) and wags faster when moving fast.
func swim(velocity: Vector2, delta: float) -> void:
	var speed: float = velocity.length()
	if speed > SPEED_FLOOR:
		# The 2D y axis points down, 3D y points up.
		var target_pitch: float = atan2(-velocity.y, absf(velocity.x))
		_pitch = lerp_angle(_pitch, target_pitch, clampf(delta * 10.0, 0.0, 1.0))
		var target_yaw: float = 0.0 if velocity.x >= 0.0 else PI
		_yaw = lerp_angle(_yaw, target_yaw, clampf(delta * 12.0, 0.0, 1.0))
	_time += delta * (6.0 + minf(speed, 600.0) * 0.02)
	basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.BACK, _pitch)
	_tail.rotation = Vector3(0.0, sin(_time) * 0.5, sin(_time) * 0.15)


func _apply_color() -> void:
	if _body_material == null:
		return
	_body_material.set_shader_parameter("base_color", color)
	_fin_material.albedo_color = color.darkened(0.3)


func _build() -> void:
	var body: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	body.mesh = sphere
	body.scale = Vector3(0.155, 0.105, 0.085)
	body.material_override = _body_material
	add_child(body)

	# The tail pivots where it meets the body.
	_tail = Node3D.new()
	_tail.position = Vector3(-0.12, 0.0, 0.0)
	add_child(_tail)
	var tail: MeshInstance3D = MeshInstance3D.new()
	tail.mesh = _flat_mesh(
		[
			[Vector2(0.0, 0.0), Vector2(-0.1, 0.085), Vector2(-0.07, 0.0)],
			[Vector2(0.0, 0.0), Vector2(-0.07, 0.0), Vector2(-0.1, -0.085)],
		]
	)
	tail.material_override = _fin_material
	_tail.add_child(tail)

	var fins: MeshInstance3D = MeshInstance3D.new()
	fins.mesh = _flat_mesh(
		[
			[Vector2(-0.07, 0.09), Vector2(0.0, 0.17), Vector2(0.05, 0.085)],
			[Vector2(-0.02, -0.09), Vector2(0.03, -0.15), Vector2(0.06, -0.08)],
		]
	)
	fins.material_override = _fin_material
	add_child(fins)


## A flat, double-sided mesh (in the XY plane) from triangles given as arrays of three Vector2.
func _flat_mesh(triangles: Array) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle: Array in triangles:
		for point: Vector2 in triangle:
			tool.set_normal(Vector3.BACK)
			tool.add_vertex(Vector3(point.x, point.y, 0.0))
	return tool.commit()
