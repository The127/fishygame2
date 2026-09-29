shader_type sky;
// Water column seen from inside: bright teal glow overhead fading to near black at depth.

const vec3 DEEP = vec3(0.008, 0.03, 0.07);
const vec3 HORIZON = vec3(0.015, 0.075, 0.13);
const vec3 SURFACE = vec3(0.0, 0.2, 0.34);

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(HORIZON, SURFACE, pow(up, 0.7));
	col = mix(col, DEEP, clamp(-d.y * 2.0, 0.0, 1.0));
	float sun = pow(max(dot(d, normalize(vec3(0.2, 1.0, -0.4))), 0.0), 24.0);
	COLOR = col + vec3(0.05, 0.3, 0.4) * sun;
}
