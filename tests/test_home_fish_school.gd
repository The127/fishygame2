extends GutTest
## Home screen fish simulation and mesh.


func test_fish_stay_inside_the_water_box() -> void:
	var school: HomeFishSchool = HomeFishSchool.new(12, 7)
	var pad: AABB = HomeFishSchool.BOUNDS.grow(3.0)
	for i: int in 3000:
		school.step(1.0 / 30.0)
	for i: int in school.count:
		assert_true(pad.has_point(school.positions[i]), "fish %d stays near the bounds" % i)


func test_same_seed_replays_the_same_school() -> void:
	var a: HomeFishSchool = HomeFishSchool.new(6, 42)
	var b: HomeFishSchool = HomeFishSchool.new(6, 42)
	for i: int in 200:
		a.step(0.02)
		b.step(0.02)
	assert_eq(a.positions, b.positions)


func test_fish_keep_moving() -> void:
	var school: HomeFishSchool = HomeFishSchool.new(8, 3)
	for i: int in 500:
		school.step(0.02)
	for v: Vector3 in school.velocities:
		assert_gt(v.length(), 0.2, "no fish stalls")


func test_fish_transform_is_upright_and_faces_travel() -> void:
	var school: HomeFishSchool = HomeFishSchool.new(4, 5)
	for i: int in 100:
		school.step(0.02)
	for i: int in school.count:
		var xform: Transform3D = school.fish_transform(i)
		var forward: Vector3 = xform.basis.x.normalized()
		assert_gt(forward.dot(school.velocities[i].normalized()), 0.0, "nose leads")
		assert_gte(xform.basis.y.normalized().y, 0.0, "belly stays down")
		assert_gt(xform.basis.determinant(), 0.0, "no mirrored fish")


func test_scare_pushes_fish_away_from_the_ray() -> void:
	var school: HomeFishSchool = HomeFishSchool.new(1, 9)
	school.positions[0] = Vector3(0.0, 0.0, 0.0)
	school.velocities[0] = Vector3.ZERO
	school.scare(Vector3(-1.0, 0.0, 10.0), Vector3(0.0, 0.0, -1.0), 3.0)
	assert_gt(school.velocities[0].x, 0.0, "pushed away from the ray, to +x")
	var far: HomeFishSchool = HomeFishSchool.new(1, 9)
	far.positions[0] = Vector3(20.0, 0.0, 0.0)
	var before: Vector3 = far.velocities[0]
	far.scare(Vector3(-1.0, 0.0, 10.0), Vector3(0.0, 0.0, -1.0), 3.0)
	assert_eq(far.velocities[0], before, "distant fish are not scared")


func test_fish_mesh_has_parts_and_normals() -> void:
	var mesh: ArrayMesh = HomeFishMesh.build()
	assert_eq(mesh.get_surface_count(), 1, "one surface, one draw call")
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_gt(verts.size(), 100)
	assert_eq(normals.size(), verts.size())
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var parts: Dictionary = {}
	for uv: Vector2 in uvs:
		parts[uv.x] = true
	assert_eq(parts.size(), 3, "body, fin and eye are tagged")
	var aabb: AABB = mesh.get_aabb()
	assert_gt(aabb.size.x, aabb.size.y, "longer than tall")
