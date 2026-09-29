shader_type spatial;
// Sandy seabed: gentle dunes plus animated caustics from the surface. The dune height
// must match HomeScene3D.seabed_height().
render_mode cull_back;

varying vec3 world_pos;

float height(vec2 p) {
	return sin(p.x * 0.35) * cos(p.y * 0.28) * 0.5 + sin(p.x * 1.1 + p.y * 0.7) * 0.08;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_pos = w;
	VERTEX.y += height(w.xz);
	float dx = cos(w.x * 0.35) * 0.35 * cos(w.z * 0.28) * 0.5 + cos(w.x * 1.1 + w.z * 0.7) * 1.1 * 0.08;
	float dz = -sin(w.x * 0.35) * sin(w.z * 0.28) * 0.28 * 0.5 + cos(w.x * 1.1 + w.z * 0.7) * 0.7 * 0.08;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	float t = TIME * 0.5;
	float c1 = sin(world_pos.x * 1.3 + t + sin(world_pos.z * 0.9 + t));
	float c2 = sin(world_pos.z * 1.1 - t * 1.2 + sin(world_pos.x * 0.8 - t));
	float caustic = pow(clamp(1.0 - abs(c1 + c2) * 0.5, 0.0, 1.0), 4.0);
	ALBEDO = vec3(0.03, 0.09, 0.11);
	ROUGHNESS = 1.0;
	EMISSION = vec3(0.05, 0.5, 0.75) * caustic * 0.35;
}
