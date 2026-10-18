shader_type canvas_item;
render_mode blend_disabled;
// "RTX ON": a deliberately overdone post effect over the whole race. One pass over the
// screen copy: bloom and a blue anamorphic streak from its blurred mip levels, light shafts
// from above, a shine sweeping across bright surfaces, chromatic aberration, more contrast
// and saturation, and a vignette. Overwrites the screen with its own alpha unchanged (no
// blending), so transparent parts of the OBS source stay transparent.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float bloom_strength = 1.6;
uniform float streak_strength = 0.9;
uniform float shaft_strength = 0.22;
uniform float shine_strength = 0.55;
uniform float aberration = 0.004;
uniform float saturation = 1.35;
uniform float contrast = 1.15;
uniform float vignette = 0.55;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// The bright part of a blurred sample: dark water adds nothing, lit things glow.
vec3 bright(vec3 c) {
	return c * smoothstep(0.32, 0.75, luma(c));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - 0.5;
	float edge = dot(from_center, from_center) * 4.0;

	vec2 split = from_center * aberration * edge;
	vec4 base = textureLod(screen_tex, uv, 0.0);
	vec3 col = vec3(
		textureLod(screen_tex, uv + split, 0.0).r, base.g, textureLod(screen_tex, uv - split, 0.0).b
	);

	vec3 bloom = bright(textureLod(screen_tex, uv, 2.0).rgb) * 0.5;
	bloom += bright(textureLod(screen_tex, uv, 3.0).rgb) * 0.7;
	bloom += bright(textureLod(screen_tex, uv, 4.0).rgb) * 0.8;
	bloom += bright(textureLod(screen_tex, uv, 5.0).rgb) * 0.9;

	vec3 streak = vec3(0.0);
	for (int i = 1; i <= 5; i++) {
		float step_x = float(i) * 0.025;
		float fade = 1.0 - float(i) / 6.0;
		streak += bright(textureLod(screen_tex, uv + vec2(step_x, 0.0), 5.0).rgb) * fade;
		streak += bright(textureLod(screen_tex, uv - vec2(step_x, 0.0), 5.0).rgb) * fade;
	}
	streak = vec3(0.35, 0.65, 1.0) * luma(streak) * 0.45;

	// Light shafts fanning down from a point above the top edge, slowly swaying.
	vec2 source = vec2(0.5 + 0.15 * sin(TIME * 0.13), -0.35);
	vec2 to_pixel = uv - source;
	float angle = atan(to_pixel.x, to_pixel.y);
	float rays = sin(angle * 23.0 + TIME * 0.35) * sin(angle * 37.0 - TIME * 0.21);
	rays = smoothstep(0.15, 0.95, rays) * (1.0 - smoothstep(0.0, 1.05, uv.y));

	// A diagonal shine sweeping across the screen every few seconds, only on lit surfaces.
	float sweep = fract(TIME * 0.18) * 2.6 - 0.8;
	float band = 1.0 - smoothstep(0.0, 0.05, abs(uv.x + uv.y * 0.45 - sweep));
	float shine = band * smoothstep(0.18, 0.5, luma(base.rgb));

	col += bloom * bloom_strength + streak * streak_strength;
	col += vec3(0.55, 0.9, 1.0) * rays * shaft_strength;
	col += vec3(1.0) * shine * shine_strength;

	col = mix(vec3(luma(col)), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col *= 1.0 - vignette * smoothstep(0.35, 1.4, edge);

	COLOR = vec4(clamp(col, 0.0, 1.0), base.a);
}
