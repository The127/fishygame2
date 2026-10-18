class_name Track3D
extends Node3D
## A 2D [Track] rebuilt in 3D: every collider becomes an extruded slab, the finish a glowing
## block. Moving parts follow their 2D bodies on [method sync]. Purely visual; the race
## still runs on the 2D physics. Reads the track without needing it in the scene tree.

## Fresh "new game" colors instead of the 2D map's: sandstone slabs and coral bumpers.
const SLAB_COLORS: Array[Color] = [
	Color(0.86, 0.66, 0.42), Color(0.8, 0.58, 0.36), Color(0.9, 0.72, 0.5)
]
const BUMPER_COLOR: Color = Color(1.0, 0.42, 0.5)
const FINISH_COLOR: Color = Color(0.85, 1.0, 0.45, 0.45)

var track: Track

## Each 2D body paired with the 3D node that shows it.
var _bodies: Array[CollisionObject2D] = []
var _holders: Array[Node3D] = []
var _materials: Dictionary[Color, StandardMaterial3D] = {}


## Builds the 3D pieces of [param source]. Call once, before or after adding this node.
func build(source: Track) -> void:
	track = source
	for child: Node in get_children():
		child.queue_free()
	_bodies.clear()
	_holders.clear()
	_collect(source)
	sync()


## Moves the 3D pieces to where their 2D bodies are now.
func sync() -> void:
	for i: int in _bodies.size():
		if is_instance_valid(_bodies[i]):
			_holders[i].transform = FlatTo3D.transform(FlatTo3D.local_to(_bodies[i], track))


## Number of 3D pieces built (for tests).
func piece_count() -> int:
	var count: int = 0
	for holder: Node3D in _holders:
		count += holder.get_child_count()
	return count


func _collect(node: Node) -> void:
	for child: Node in node.get_children():
		var body: CollisionObject2D = child as CollisionObject2D
		if body != null and _wanted(body):
			_add_body(body)
		_collect(child)


func _wanted(body: CollisionObject2D) -> bool:
	if body is Area2D:
		return body.name == "Finish"
	return true


func _add_body(body: CollisionObject2D) -> void:
	var holder := Node3D.new()
	holder.name = body.name
	add_child(holder)
	_bodies.append(body)
	_holders.append(holder)
	var finish: bool = body is Area2D
	var slab: Color = SLAB_COLORS[_bodies.size() % SLAB_COLORS.size()]
	for child: Node in body.get_children():
		var piece: MeshInstance3D = _piece_for(child)
		if piece == null:
			continue
		if finish:
			piece.material_override = _finish_material()
		else:
			var round_shape: bool = piece.mesh is SphereMesh or piece.mesh is CapsuleMesh
			piece.material_override = _material(BUMPER_COLOR if round_shape else slab)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(piece)


func _piece_for(child: Node) -> MeshInstance3D:
	var polygon: CollisionPolygon2D = child as CollisionPolygon2D
	if polygon != null and not polygon.disabled:
		var piece := MeshInstance3D.new()
		piece.mesh = FlatTo3D.extrude(polygon.polygon, FlatTo3D.SLAB_DEPTH)
		piece.transform = FlatTo3D.transform(polygon.transform)
		return piece
	var shape_node: CollisionShape2D = child as CollisionShape2D
	if shape_node == null or shape_node.disabled or shape_node.shape == null:
		return null
	var mesh: Mesh = _shape_mesh(shape_node.shape)
	if mesh == null:
		return null
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.transform = FlatTo3D.transform(shape_node.transform)
	return piece


func _shape_mesh(shape: Shape2D) -> Mesh:
	var circle: CircleShape2D = shape as CircleShape2D
	if circle != null:
		# A ball reads better than a disc for round bumpers and pegs.
		var ball := SphereMesh.new()
		ball.radius = circle.radius * FlatTo3D.UNIT
		ball.height = ball.radius * 2.0
		ball.radial_segments = 16
		ball.rings = 8
		return ball
	var rect: RectangleShape2D = shape as RectangleShape2D
	if rect != null:
		var box := BoxMesh.new()
		box.size = Vector3(
			rect.size.x * FlatTo3D.UNIT, rect.size.y * FlatTo3D.UNIT, FlatTo3D.SLAB_DEPTH
		)
		return box
	var capsule: CapsuleShape2D = shape as CapsuleShape2D
	if capsule != null:
		var pill := CapsuleMesh.new()
		pill.radius = capsule.radius * FlatTo3D.UNIT
		pill.height = capsule.height * FlatTo3D.UNIT
		return pill
	return null


func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.6
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[color] = material
	return _materials[color]


func _finish_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = FINISH_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
