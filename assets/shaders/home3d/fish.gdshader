shader_type spatial;
// Instanced home-screen fish. Instance colour is the body colour, INSTANCE_CUSTOM.x a
// per-fish phase. The tail wag is done on the vertices, the lighting is faked (no lights).
render_mode unshaded, cull_disabled;

const vec3 LIGHT_DIR = vec3(0.25, 0.9, 0.35);
const vec3 FISH_GLOW = vec3(0.1, 0.8, 1.0);

uniform float wag_speed = 7.0;
uniform float wag_amount = 0.16;

varying vec4 tint;
varying float part;
varying float height;
varying float phase;

void vertex() {
	tint = COLOR;
	part = UV.x;
	height = VERTEX.y;
	phase = INSTANCE_CUSTOM.x;
	float tail = smoothstep(0.35, -1.05, VERTEX.x);
	VERTEX.z += sin(TIME * wag_speed + phase - VERTEX.x * 3.0) * wag_amount * tail;
	VERTEX.x *= 1.0 - 0.03 * abs(VERTEX.z) * tail;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	if (!FRONT_FACING) {
		n = -n;
	}
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float lit = 0.35 + 0.65 * max(dot(world_n, normalize(LIGHT_DIR)), 0.0);
	// Countershading: darker back, lighter belly.
	vec3 base = mix(tint.rgb * 1.35, tint.rgb * 0.6, smoothstep(-0.3, 0.35, height));
	if (part > 1.5) {
		ALBEDO = vec3(0.01, 0.02, 0.03) + FISH_GLOW * pow(1.0 - clamp(n.z, 0.0, 1.0), 2.0) * 0.5;
	} else {
		if (part > 0.5) {
			base = tint.rgb * 1.1;
		}
		float rim = pow(1.0 - clamp(dot(n, vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 3.0);
		ALBEDO = base * lit + FISH_GLOW * rim * 0.35;
	}
}
