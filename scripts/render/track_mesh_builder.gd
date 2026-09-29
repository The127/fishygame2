class_name TrackMeshBuilder
extends RefCounted
## Turns a 2D track's colliders into 3D scenery: polygon colliders become extruded
## rock slabs, circle colliders (pegs) become coral bulbs and the finish area
## becomes a glowing gate. The 3D scene is a mirror: physics stays in 2D.

## World units per 2D pixel.
const SCALE: float = 0.01
## The slab's front face is almost on the physics plane (z=0) so marbles visibly touch it.
const Z_FRONT: float = 0.12
const Z_BACK: float = -0.6
const PEG_DEPTH: float = 1.7

const ROCK_SHADER: Shader = preload("res://assets/shaders/water/rock.gdshader")
const DEFAULT_ROCK: Color = Color(0.4, 0.35, 0.3)
const DEFAULT_PEG: Color = Color(0.95, 0.6, 0.35)


## 2D pixel position (y down) to 3D world position (y up) on the physics plane.
static func to_3d(point: Vector2, z: float = 0.0) -> Vector3:
	return Vector3(point.x * SCALE, -point.y * SCALE, z)


static func build(track: Track) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "TrackScenery"
	for child: Node in track.get_children():
		if child is StaticBody2D:
			_add_body(root, track, child as StaticBody2D)
		elif child is Area2D and child.name == "Finish":
			_add_finish(root, track, child as Area2D)
	return root


static func _add_body(root: Node3D, track: Track, body: StaticBody2D) -> void:
	var tint: Color = _visual_color(body)
	for child: Node in body.get_children():
		if child is CollisionPolygon2D:
			var poly: CollisionPolygon2D = child as CollisionPolygon2D
			var points: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in poly.polygon:
				points.append(track.to_local(poly.to_global(point)))
			var slab: MeshInstance3D = MeshInstance3D.new()
			slab.mesh = extrude(points)
			slab.material_override = _rock_material(tint if tint.a > 0.0 else DEFAULT_ROCK)
			root.add_child(slab)
		elif child is CollisionShape2D:
			var shape_node: CollisionShape2D = child as CollisionShape2D
			var circle: CircleShape2D = shape_node.shape as CircleShape2D
			if circle != null:
				var center: Vector2 = track.to_local(shape_node.global_position)
				root.add_child(_make_peg(center, circle.radius, tint))


## Extrudes a 2D polygon (pixels, y down) between Z_BACK and Z_FRONT. Returns null for
## degenerate polygons.
static func extrude(points_2d: PackedVector2Array) -> ArrayMesh:
	if points_2d.size() < 3:
		return null
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(points_2d)
	if indices.is_empty():
		return null
	var pts: PackedVector3Array = PackedVector3Array()
	for point: Vector2 in points_2d:
		pts.append(to_3d(point))
	# Flipping y reverses the winding, so orient explicitly: counter-clockwise seen from +Z.
	var area: float = 0.0
	for i: int in pts.size():
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	var ccw: bool = area > 0.0
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t: int in range(0, indices.size(), 3):
		var a: Vector3 = pts[indices[t]]
		var b: Vector3 = pts[indices[t + 1]]
		var c: Vector3 = pts[indices[t + 2]]
		# Triangulation runs on the y-down points, so its winding is opposite of ccw-in-3D.
		if (b - a).cross(c - a).z < 0.0:
			var swap: Vector3 = b
			b = c
			c = swap
		_add_tri(
			tool,
			Vector3(a.x, a.y, Z_FRONT),
			Vector3(b.x, b.y, Z_FRONT),
			Vector3(c.x, c.y, Z_FRONT),
			Vector3.BACK
		)
		_add_tri(
			tool,
			Vector3(a.x, a.y, Z_BACK),
			Vector3(c.x, c.y, Z_BACK),
			Vector3(b.x, b.y, Z_BACK),
			Vector3.FORWARD
		)
	for i: int in pts.size():
		var p: Vector3 = pts[i]
		var q: Vector3 = pts[(i + 1) % pts.size()]
		if not ccw:
			var swap: Vector3 = p
			p = q
			q = swap
		var edge: Vector3 = q - p
		if edge.length_squared() < 0.000001:
			continue
		# Outward is to the right of a counter-clockwise edge.
		var normal: Vector3 = Vector3(edge.y, -edge.x, 0.0).normalized()
		var pf: Vector3 = Vector3(p.x, p.y, Z_FRONT)
		var qf: Vector3 = Vector3(q.x, q.y, Z_FRONT)
		var pb: Vector3 = Vector3(p.x, p.y, Z_BACK)
		var qb: Vector3 = Vector3(q.x, q.y, Z_BACK)
		_add_tri(tool, pf, qb, qf, normal)
		_add_tri(tool, pf, pb, qb, normal)
	return tool.commit()


static func _add_tri(
	tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3
) -> void:
	for v: Vector3 in [a, b, c]:
		tool.set_normal(normal)
		tool.add_vertex(v)


static func _make_peg(center: Vector2, radius: float, tint: Color) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius * SCALE
	mesh.height = radius * SCALE * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var peg: MeshInstance3D = MeshInstance3D.new()
	peg.mesh = mesh
	# Stretch toward the camera so it reads as a bulb, not a flat disc.
	peg.scale = Vector3(1.0, 1.0, PEG_DEPTH)
	peg.position = to_3d(center, -0.05)
	var color: Color = tint if tint.a > 0.0 else DEFAULT_PEG
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.35
	material.rim_enabled = true
	material.rim = 0.6
	peg.material_override = material
	return peg


static func _add_finish(root: Node3D, track: Track, finish: Area2D) -> void:
	for child: Node in finish.get_children():
		var shape_node: CollisionShape2D = child as CollisionShape2D
		if shape_node == null:
			continue
		var rect: RectangleShape2D = shape_node.shape as RectangleShape2D
		if rect == null:
			continue
		var quad: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(rect.size.x * SCALE, rect.size.y * SCALE, 0.9)
		quad.mesh = mesh
		quad.position = to_3d(track.to_local(shape_node.global_position), -0.1)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.albedo_color = Color(1.0, 0.78, 0.15, 0.22)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material_override = material
		root.add_child(quad)


## The color of the body's 2D `Visual` polygon, or a transparent color if it has none.
static func _visual_color(body: Node) -> Color:
	var visual: Polygon2D = body.get_node_or_null("Visual") as Polygon2D
	if visual == null:
		return Color(0, 0, 0, 0)
	return visual.color


static func _rock_material(tint: Color) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = ROCK_SHADER
	material.set_shader_parameter("base_color", tint.darkened(0.15))
	return material
