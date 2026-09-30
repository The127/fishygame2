shader_type canvas_item;
// Premium fish looks. One shader for every layer of a fish: the drawn shading (dark rim,
// back to belly gradient) is kept as a brightness, the look replaces the hue. `mode` is a
// FishSkin.Kind. Everything is math on the fish-local position, so it costs no textures.

uniform int mode = 0;

varying vec2 lp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 hsv(float h, float s, float v) {
	vec3 k = clamp(abs(fract(vec3(h) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), k, s);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float lum = max(COLOR.r, max(COLOR.g, COLOR.b));
	// 0 on the dark outline, 1 on the body, so the rim stays dark.
	float body = smoothstep(0.04, 0.2, lum);
	float shade = 0.65 + 0.7 * clamp(lum, 0.0, 1.0);
	vec3 fx = vec3(1.0);
	float alpha = 1.0;
	float t = TIME;

	if (mode == 1) { // neon: hot pink and cyan tubes pulsing in turn
		float k = 0.5 + 0.5 * sin(t * 3.0 + lp.x * 0.12);
		fx = mix(vec3(1.0, 0.1, 0.75), vec3(0.1, 1.0, 1.0), k);
		fx = mix(fx, vec3(1.0), 0.25 * (0.5 + 0.5 * sin(t * 9.0)));
		shade = 1.15;
	} else if (mode == 2) { // atomic: radioactive green with rings pulsing out of the core
		float ring = 0.5 + 0.5 * sin(length(lp) * 0.7 - t * 5.0);
		fx = mix(vec3(0.15, 0.8, 0.05), vec3(0.85, 1.0, 0.2), ring);
		shade = 1.05 + 0.25 * sin(t * 4.0);
	} else if (mode == 3) { // rainbow: hue slides along the body
		fx = hsv(fract(lp.x * 0.025 + lp.y * 0.01 - t * 0.35), 0.85, 1.0);
	} else if (mode == 4) { // ghost: pale, see-through and wavering
		fx = vec3(0.78, 0.9, 1.0);
		alpha = 0.3 + 0.12 * sin(t * 2.0 + lp.x * 0.2);
		shade = 1.0;
	} else if (mode == 5) { // missing texture: the magenta and black checkerboard
		vec2 c = floor(lp / 4.0);
		fx = mod(c.x + c.y, 2.0) < 1.0 ? vec3(1.0, 0.0, 1.0) : vec3(0.02, 0.0, 0.02);
		shade = 1.0;
	} else if (mode == 6) { // matrix: columns of green code falling
		vec2 cell = floor(lp / vec2(2.5, 3.0));
		float speed = 1.5 + 2.5 * hash(vec2(cell.x, 3.0));
		float fall = fract(hash(vec2(cell.x, 7.0)) - t * speed * 0.35 + cell.y * 0.17);
		float glyph = step(0.35, hash(cell + floor(t * 6.0 * hash(cell))));
		float v = fall * fall * glyph;
		fx = mix(vec3(0.0, 0.22, 0.07), vec3(0.3, 1.0, 0.45), v);
		fx = mix(fx, vec3(0.85, 1.0, 0.9), step(0.93, fall) * glyph);
		shade = 1.0;
	} else if (mode == 7) { // gold: polished metal with a band of light sweeping across
		float band = smoothstep(0.75, 1.0, sin((lp.x + lp.y * 0.5) * 0.22 - t * 2.2));
		fx = mix(vec3(1.0, 0.72, 0.15), vec3(1.0, 0.97, 0.75), band);
	} else if (mode == 8) { // lava: molten flow, bright cracks over dark crust
		float f = sin(lp.x * 0.35 + t * 1.3) + sin(lp.y * 0.6 - t * 1.7) + sin((lp.x + lp.y) * 0.3 + t);
		float m = smoothstep(-1.0, 1.6, f);
		fx = mix(vec3(0.25, 0.02, 0.0), vec3(1.0, 0.75, 0.1), m);
		fx = mix(fx, vec3(1.0, 0.25, 0.0), 0.35);
		shade = 1.1;
	} else if (mode == 9) { // galaxy: deep violet with twinkling stars
		vec2 cell = floor(lp * 0.6);
		float star = step(0.93, hash(cell)) * (0.5 + 0.5 * sin(t * 4.0 + hash(cell + 3.0) * 20.0));
		float haze = 0.5 + 0.5 * sin(lp.x * 0.2 + lp.y * 0.3 + t * 0.6);
		fx = mix(vec3(0.08, 0.04, 0.3), vec3(0.45, 0.12, 0.6), haze);
		fx = mix(fx, vec3(1.0), star);
		shade = 1.0;
	} else if (mode == 10) { // glitch: slices that jump and flip between cyan, magenta and white
		float slice = floor(lp.y / 2.0);
		float tick = floor(t * 8.0);
		float r = hash(vec2(slice, tick));
		fx = r < 0.4 ? vec3(0.0, 1.0, 0.9) : (r < 0.8 ? vec3(1.0, 0.0, 0.6) : vec3(1.0));
		fx = mix(fx, vec3(0.05, 0.05, 0.1), step(0.92, hash(vec2(slice + 5.0, tick))));
		shade = 1.0;
	}

	vec3 rgb = mix(COLOR.rgb, clamp(fx * shade, 0.0, 1.0), body);
	COLOR = vec4(rgb, COLOR.a * mix(1.0, alpha, body));
}
