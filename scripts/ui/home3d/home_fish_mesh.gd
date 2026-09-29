class_name HomeFishMesh
extends RefCounted
## One low-poly fish mesh shared by the whole school. The nose points along +X, the tail
## fin lies in the XY plane. UV.x tags the part for the shader: 0 body, 1 fin, 2 eye.

const RINGS: int = 14
const SIDES: int = 10
const BODY_START: float = -0.6
const BODY_END: float = 1.0
const BODY_HEIGHT: float = 1.3
const BODY_WIDTH: float = 0.75
const PART_BODY: float = 0.0
const PART_FIN: float = 1.0
const PART_EYE: float = 2.0


static func build() -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_body(tool)
	_add_fins(tool)
	_add_eye(tool, 1)
	_add_eye(tool, -1)
	tool.generate_normals()
	return tool.commit()


static func body_radius(t: float) -> float:
	return 0.3 * sin(PI * pow(t, 0.75)) + 0.06 * (1.0 - t)


static func _add_body(tool: SurfaceTool) -> void:
	var rings: Array[PackedVector3Array] = []
	for r: int in RINGS + 1:
		var t: float = float(r) / RINGS
		var x: float = lerpf(BODY_START, BODY_END, t)
		var radius: float = body_radius(t)
		var ring: PackedVector3Array = PackedVector3Array()
		for s: int in SIDES:
			var a: float = float(s) / SIDES * TAU
			ring.append(Vector3(x, cos(a) * radius * BODY_HEIGHT, sin(a) * radius * BODY_WIDTH))
		rings.append(ring)
	for r: int in RINGS:
		for s: int in SIDES:
			var n: int = (s + 1) % SIDES
			var quad: Array[Vector3] = [rings[r][s], rings[r + 1][s], rings[r + 1][n], rings[r][n]]
			_add_smooth_quad(tool, quad)


static func _add_smooth_quad(tool: SurfaceTool, quad: Array[Vector3]) -> void:
	tool.set_smooth_group(0)
	tool.set_uv(Vector2(PART_BODY, 0.0))
	for i: int in [0, 1, 2, 0, 2, 3]:
		tool.add_vertex(quad[i])


static func _add_fins(tool: SurfaceTool) -> void:
	tool.set_smooth_group(-1)
	tool.set_uv(Vector2(PART_FIN, 0.0))
	var tail: Array[Vector3] = [
		Vector3(-0.5, 0.0, 0.0),
		Vector3(-1.05, 0.45, 0.0),
		Vector3(-0.85, 0.0, 0.0),
		Vector3(-1.05, -0.45, 0.0),
	]
	for i: int in [0, 1, 2, 0, 2, 3]:
		tool.add_vertex(tail[i])
	for v: Vector3 in [
		Vector3(0.35, 0.36, 0.0), Vector3(-0.2, 0.34, 0.0), Vector3(-0.15, 0.68, 0.0)
	]:
		tool.add_vertex(v)
	for v: Vector3 in [
		Vector3(0.3, -0.3, 0.0), Vector3(0.05, -0.3, 0.0), Vector3(-0.05, -0.55, 0.0)
	]:
		tool.add_vertex(v)


static func _add_eye(tool: SurfaceTool, side: int) -> void:
	var center: Vector3 = Vector3(0.72, 0.1, 0.17 * side)
	tool.set_smooth_group(0)
	tool.set_uv(Vector2(PART_EYE, 0.0))
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	sphere.radial_segments = 6
	sphere.rings = 3
	var arrays: Array = sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index: int in indices:
		tool.set_uv(Vector2(PART_EYE, 0.0))
		tool.add_vertex(verts[index] + center)
