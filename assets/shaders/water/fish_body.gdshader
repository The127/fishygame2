shader_type spatial;
// Fish skin: lighter belly, darker back, a few soft stripes, in the viewer's color.

uniform vec4 base_color : source_color = vec4(1.0);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Local sphere space: y in [-1, 1] runs belly to back, x in [-1, 1] runs tail to nose.
	float belly = smoothstep(-0.2, -0.85, local_pos.y);
	float back = smoothstep(0.2, 0.9, local_pos.y);
	float stripes = smoothstep(0.55, 0.75, sin(local_pos.x * 9.0)) * 0.18;
	vec3 c = base_color.rgb;
	c = mix(c, c * 0.65, back * 0.7);
	c = mix(c, vec3(1.0), belly * 0.45);
	c *= 1.0 - stripes;
	// Eyes are painted on both flanks: a white disc with a dark pupil toward the nose.
	vec3 dir = normalize(vec3(local_pos.x, local_pos.y, abs(local_pos.z)));
	float eye_d = distance(dir, normalize(vec3(0.62, 0.3, 0.75)));
	c = mix(c, vec3(1.0), smoothstep(0.34, 0.3, eye_d));
	float pupil_d = distance(dir, normalize(vec3(0.72, 0.3, 0.68)));
	c = mix(c, vec3(0.02), smoothstep(0.17, 0.14, pupil_d));
	ALBEDO = c;
	ROUGHNESS = 0.35;
	RIM = 0.4;
	RIM_TINT = 0.5;
}
