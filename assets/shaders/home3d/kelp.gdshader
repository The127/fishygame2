shader_type spatial;
// Kelp blades swaying in the current: the tip moves most, the root stays put.
render_mode unshaded, cull_disabled;

const vec3 ROOT = vec3(0.01, 0.07, 0.09);
const vec3 TIP = vec3(0.05, 0.6, 0.45);

uniform float blade_height = 4.0;

varying float grow;

void vertex() {
	grow = clamp(VERTEX.y / blade_height, 0.0, 1.0);
	float phase = INSTANCE_CUSTOM.x;
	float sway = sin(TIME * 0.9 + phase + VERTEX.y * 0.7) + 0.5 * sin(TIME * 1.7 + phase * 2.0);
	VERTEX.x += sway * grow * grow * 0.45;
}

void fragment() {
	ALBEDO = mix(ROOT, TIP, grow * grow) * COLOR.rgb;
}
