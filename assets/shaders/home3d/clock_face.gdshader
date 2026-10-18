shader_type spatial;
// Procedural clock face for the home screen clock tower: rim, twelve ticks and three hands on one
// quad. Angles are in radians, clockwise from twelve. `lit` fades between the glowing face and
// the dark, closed one.
render_mode unshaded, cull_back;

uniform float hour_angle = 0.0;
uniform float minute_angle = 0.0;
uniform float second_angle = 0.0;
uniform float lit : hint_range(0.0, 1.0) = 1.0;
uniform vec3 face_lit : source_color = vec3(1.0, 0.93, 0.7);
uniform vec3 face_dark : source_color = vec3(0.05, 0.1, 0.13);
uniform vec3 ink : source_color = vec3(0.04, 0.07, 0.1);
uniform vec3 rim : source_color = vec3(0.75, 0.62, 0.3);
uniform vec3 second_ink : source_color = vec3(1.0, 0.42, 0.3);

float hand(vec2 p, float angle, float len, float width) {
	vec2 dir = vec2(sin(angle), cos(angle));
	float t = clamp(dot(p, dir), -0.12, len);
	float d = length(p - dir * t);
	return 1.0 - smoothstep(width, width + 0.02, d);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float a = atan(p.x, p.y);
	vec3 col = mix(face_dark, face_lit, lit);
	// Softer glow towards the rim, like a backlit opal face.
	col *= mix(1.0, 0.82 - 0.12 * r, lit);

	float step_a = TAU / 12.0;
	float seg = mod(a + step_a * 0.5, step_a) - step_a * 0.5;
	float quarter = step(abs(mod(a + PI * 0.25, PI * 0.5) - PI * 0.25), step_a * 0.5);
	float tick_w = mix(0.022, 0.04, quarter);
	float tick = (1.0 - smoothstep(tick_w, tick_w + 0.015, abs(seg) * r))
		* step(mix(0.72, 0.64, quarter), r) * step(r, 0.84);
	vec3 marks = mix(ink, rim * 0.5, 1.0 - lit);
	col = mix(col, marks, tick);

	float hands = max(hand(p, hour_angle, 0.45, 0.05), hand(p, minute_angle, 0.7, 0.032));
	col = mix(col, marks, hands);
	// The second hand only runs while the face is lit; the hub is always there.
	float hub = 1.0 - smoothstep(0.05, 0.07, r);
	float sec = max(hand(p, second_angle, 0.76, 0.012) * step(0.5, lit), hub);
	col = mix(col, mix(marks, second_ink, lit), sec);

	float ring = smoothstep(0.86, 0.89, r);
	col = mix(col, rim * mix(0.45, 1.0, lit), ring);
	ALBEDO = col;
}
