shader_type canvas_item;
// The fake "Fishy Marble Run 4D" breaking down: bands of the screen slip sideways, the
// colour channels split, blocks flicker and scanlines roll. Strength follows [code]amount[/code].

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen : hint_screen_texture, filter_nearest;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tick = floor(TIME * 18.0);
	float band = floor(uv.y * mix(6.0, 40.0, hash(vec2(tick, 3.0))));
	float slip = hash(vec2(band, tick)) - 0.5;
	// Only some bands slip, more of them the stronger the glitch.
	slip *= step(1.0 - amount * 0.8, hash(vec2(band, tick + 7.0)));
	uv.x += slip * 0.18 * amount;
	float split = 0.012 * amount * (0.5 + hash(vec2(tick, 1.0)));
	vec3 c = vec3(
		texture(screen, uv + vec2(split, 0.0)).r,
		texture(screen, uv).g,
		texture(screen, uv - vec2(split, 0.0)).b
	);
	vec2 block = floor(uv * vec2(16.0, 9.0));
	float flicker = step(1.0 - amount * 0.25, hash(block + tick));
	c = mix(c, vec3(1.0) - c.gbr, flicker);
	c *= 1.0 - 0.25 * amount * step(0.5, fract(SCREEN_UV.y * 180.0 + TIME * 6.0));
	COLOR = vec4(c, texture(screen, uv).a);
}
