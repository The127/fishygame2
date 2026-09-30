extends GutTest
## Environment silhouettes are tessellated once into a single mesh.


func _layer(kind: EnvLayer.Kind, seed_value: int = 3) -> EnvLayer:
	var layer: EnvLayer = EnvLayer.new()
	layer.kind = kind
	layer.color = Color(0.2, 0.1, 0.3)
	layer.highlight = Color(1, 1, 1, 0.2)
	layer.seed_value = seed_value
	layer.count = 6
	add_child_autofree(layer)
	return layer


func _vertex_count(layer: EnvLayer) -> int:
	var mesh: ArrayMesh = layer.get("_mesh")
	if mesh == null:
		return 0
	var arrays: Array = mesh.surface_get_arrays(0)
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array).size()


func test_every_kind_builds_a_mesh() -> void:
	for kind: int in EnvLayer.Kind.values():
		var layer: EnvLayer = _layer(kind as EnvLayer.Kind)
		assert_gt(_vertex_count(layer), 0, "kind %d has geometry" % kind)


func _vertices(layer: EnvLayer) -> PackedVector2Array:
	var arrays: Array = (layer.get("_mesh") as ArrayMesh).surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX]


func test_same_seed_gives_the_same_shapes() -> void:
	var a: EnvLayer = _layer(EnvLayer.Kind.CORAL, 5)
	var b: EnvLayer = _layer(EnvLayer.Kind.CORAL, 5)
	var c: EnvLayer = _layer(EnvLayer.Kind.CORAL, 6)
	assert_eq(_vertices(a), _vertices(b))
	assert_ne(_vertices(a), _vertices(c))


func test_indices_stay_inside_the_vertex_array() -> void:
	for kind: int in EnvLayer.Kind.values():
		var layer: EnvLayer = _layer(kind as EnvLayer.Kind)
		var arrays: Array = (layer.get("_mesh") as ArrayMesh).surface_get_arrays(0)
		var vertices: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array).size()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert_eq(indices.size() % 3, 0)
		for index: int in indices:
			assert_true(index >= 0 and index < vertices)
