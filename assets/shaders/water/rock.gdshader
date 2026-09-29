shader_type spatial;
// Procedural rock: value-noise variation in world space, moss on upward faces.

uniform vec3 base_color : source_color = vec3(0.4, 0.35, 0.3);
uniform vec3 moss_color : source_color = vec3(0.16, 0.42, 0.28);
uniform float noise_scale = 6.0;

varying vec3 wpos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = vnoise(wpos * noise_scale) * 0.55 + vnoise(wpos * noise_scale * 2.7) * 0.3 + vnoise(wpos * noise_scale * 7.0) * 0.15;
	vec3 c = base_color * (0.55 + 0.9 * n);
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float up = smoothstep(0.35, 0.9, world_normal.y);
	c = mix(c, moss_color * (0.7 + 0.6 * n), up * 0.85);
	ALBEDO = c;
	ROUGHNESS = 0.92;
	RIM = 0.15;
	RIM_TINT = 0.6;
}
