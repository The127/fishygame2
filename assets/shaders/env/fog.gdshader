shader_type canvas_item;
// Slow drifting mist, thicker toward the bottom, with a soft dark vignette.

uniform vec4 fog_color : source_color = vec4(0.1, 0.3, 0.35, 1.0);
uniform float density = 0.16;
uniform float vignette = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * vec2(4.0, 2.2);
	float n = vnoise(p + vec2(TIME * 0.03, 0.0)) * 0.6 + vnoise(p * 2.3 - vec2(TIME * 0.05, TIME * 0.01)) * 0.4;
	float mist = smoothstep(0.35, 0.85, n) * density * (0.4 + UV.y * 0.9);
	float edge = distance(UV, vec2(0.5)) * 1.45;
	float dark = smoothstep(0.55, 1.15, edge) * vignette;
	vec3 c = mix(fog_color.rgb, vec3(0.0), clamp(dark / max(mist + dark, 0.001), 0.0, 1.0));
	COLOR = vec4(c, clamp(mist + dark, 0.0, 0.85));
}
