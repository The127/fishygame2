shader_type spatial;
render_mode unshaded, cull_disabled;
// A swaying blade. Use on a tall subdivided quad, one instance per blade.

uniform vec3 root_color : source_color = vec3(0.02, 0.12, 0.13);
uniform vec3 tip_color : source_color = vec3(0.12, 0.42, 0.34);
uniform float sway = 0.35;

varying float height_t;

void vertex() {
	// UV.y is 0 at the top of a quad, so flip it: 0 at the root, 1 at the tip.
	height_t = 1.0 - UV.y;
	float phase = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 3.1;
	VERTEX.x += sin(TIME * 1.1 + phase + height_t * 2.5) * sway * height_t * height_t;
}

void fragment() {
	float half_width = mix(0.9, 0.12, height_t);
	if (abs(UV.x - 0.5) * 2.0 > half_width) {
		discard;
	}
	ALBEDO = mix(root_color, tip_color, height_t);
}
