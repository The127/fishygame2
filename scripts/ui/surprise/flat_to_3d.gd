class_name FlatTo3D
extends RefCounted
## Helpers that turn the flat 2D race into 3D for the fake "Fishy Marble Run 3": track pixels
## become world units (x right, y up, z towards the viewer), polygons become extruded slabs.

## World units per 2D pixel.
const UNIT: float = 0.01
## Thickness of the extruded track pieces, in world units.
const SLAB_DEPTH: float = 0.7
const FOG_COLOR: Color = Color(0.02, 0.09, 0.16)


## A 2D track point as a 3D world point at depth [param z].
static func point(p: Vector2, z: float = 0.0) -> Vector3:
	return Vector3(p.x * UNIT, -p.y * UNIT, z)


## A 2D transform (pixels, y down) as the matching 3D transform (units, y up, turning about z).
static func transform(t: Transform2D) -> Transform3D:
	var scale := Basis.from_scale(Vector3(t.get_scale().x, t.get_scale().y, 1.0))
	var basis: Basis = Basis(Vector3.BACK, -t.get_rotation()) * scale
	return Transform3D(basis, point(t.origin))


## Transform of [param node] relative to [param root], without needing the scene tree.
static func local_to(node: Node, root: Node) -> Transform2D:
	var result := Transform2D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		var item: Node2D = current as Node2D
		if item != null:
			result = item.transform * result
		current = current.get_parent()
	return result


## [param polygon] (pixels, in its own space) extruded [param depth] units along z, centered
## on z = 0, with front, back and side faces. Empty when the polygon cannot be triangulated.
static func extrude(polygon: PackedVector2Array, depth: float) -> ArrayMesh:
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	var mesh := ArrayMesh.new()
	if triangles.is_empty():
		return mesh
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = depth * 0.5
	# Godot's front faces wind clockwise seen from the viewer. The 2D polygon flips y, so the
	# triangulator's order flips too: the front cap keeps it, the back cap reverses it.
	for i: int in range(0, triangles.size(), 3):
		for k: int in [0, 1, 2]:
			tool.set_normal(Vector3.BACK)
			tool.add_vertex(point(polygon[triangles[i + k]], half))
		for k: int in [2, 1, 0]:
			tool.set_normal(Vector3.FORWARD)
			tool.add_vertex(point(polygon[triangles[i + k]], -half))
	var clockwise: bool = Geometry2D.is_polygon_clockwise(polygon)
	for i: int in polygon.size():
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		if clockwise:
			var swap: Vector2 = a
			a = b
			b = swap
		var a_front: Vector3 = point(a, half)
		var b_front: Vector3 = point(b, half)
		var a_back: Vector3 = point(a, -half)
		var b_back: Vector3 = point(b, -half)
		var normal: Vector3 = (b_front - a_front).cross(Vector3.BACK).normalized()
		for v: Vector3 in [a_front, a_back, b_back, a_front, b_back, b_front]:
			tool.set_normal(normal)
			tool.add_vertex(v)
	return tool.commit(mesh)


## Underwater look shared by the race view and the home flyover: the home sky, fog, soft light.
static func make_environment() -> WorldEnvironment:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://assets/shaders/home3d/water_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.5, 0.65)
	env.ambient_light_energy = 1.2
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	var holder := WorldEnvironment.new()
	holder.environment = env
	return holder


static func make_light() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, 25.0, 0.0)
	light.light_color = Color(0.75, 0.92, 1.0)
	light.light_energy = 1.4
	return light
