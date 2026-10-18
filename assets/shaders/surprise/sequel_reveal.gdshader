shader_type canvas_item;
// Reveals the fake "Fishy Marble Run 3" backdrop: a ring of red light ripples out from the
// squished title number with a ragged edge, uncovering the 3D flyover behind it.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Center of the ring, in UV space.
uniform vec2 origin = vec2(0.5, 0.15);
// Width over height of the screen, so the ring stays round.
uniform float aspect = 1.7778;
uniform vec3 rim_color : source_color = vec3(1.0, 0.25, 0.3);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x);
	float b = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

void fragment() {
	vec2 d = (UV - origin) * vec2(aspect, 1.0);
	float r = length(d) + noise(UV * 14.0) * 0.12;
	float edge = progress * 2.4;
	float ripple = sin(r * 38.0 - TIME * 14.0) * 0.008 * (1.0 - progress);
	vec4 c = texture(TEXTURE, UV + normalize(d + vec2(0.0001)) * ripple);
	float shown = 1.0 - smoothstep(edge - 0.07, edge, r);
	float rim = (1.0 - smoothstep(0.0, 0.05, abs(r - edge))) * (1.0 - progress * 0.7);
	COLOR = vec4(mix(c.rgb, rim_color, rim * 0.8), max(c.a * shown, rim));
}
