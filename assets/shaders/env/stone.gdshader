shader_type canvas_item;
// Hand-painted looking stone: layered value noise, ink cracks and diagonal hatching.

uniform vec4 dark_color : source_color = vec4(0.06, 0.09, 0.11, 1.0);
uniform vec4 light_color : source_color = vec4(0.16, 0.22, 0.25, 1.0);
uniform float noise_scale = 0.035;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float n = vnoise(world_pos * noise_scale) * 0.6 + vnoise(world_pos * noise_scale * 3.1) * 0.4;
	vec3 c = mix(dark_color.rgb, light_color.rgb, n);
	float crack = smoothstep(0.035, 0.0, abs(vnoise(world_pos * noise_scale * 1.7 + 9.0) - 0.5));
	c *= 1.0 - crack * 0.6;
	float hatch = step(0.86, fract((world_pos.x - world_pos.y) * 0.09)) * 0.05;
	c += hatch;
	COLOR = vec4(c, 1.0);
}
