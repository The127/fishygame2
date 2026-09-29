shader_type spatial;
render_mode unshaded, fog_disabled;
// Far wall of the tank: depth gradient with slow caustic light on top.

uniform vec3 top_color : source_color = vec3(0.06, 0.42, 0.58);
uniform vec3 bottom_color : source_color = vec3(0.01, 0.05, 0.14);
uniform float caustic_strength = 0.35;

float caustic(vec2 p, float t) {
	vec2 q = p;
	float v = 0.0;
	for (int i = 0; i < 3; i++) {
		q += vec2(sin(q.y * 1.7 + t), cos(q.x * 1.3 - t * 0.8)) * 0.6;
		v += abs(sin(q.x * 2.0) + sin(q.y * 2.0));
	}
	return pow(1.0 - clamp(v / 6.0, 0.0, 1.0), 3.0);
}

void fragment() {
	float depth = UV.y;
	vec3 c = mix(top_color, bottom_color, pow(depth, 0.75));
	float light = caustic(UV * vec2(14.0, 8.0), TIME * 0.35);
	c += vec3(0.5, 0.9, 1.0) * light * caustic_strength * (1.0 - depth);
	ALBEDO = c;
}
