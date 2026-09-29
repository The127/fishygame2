shader_type spatial;
// Camera-facing additive glow sprite. Instance colour is the glow colour, INSTANCE_CUSTOM.x
// the pulse phase.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;

varying float pulse;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	pulse = 0.7 + 0.3 * sin(TIME * 1.3 + INSTANCE_CUSTOM.x);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 2.5);
	ALBEDO = COLOR.rgb * 1.6;
	ALPHA = a * pulse * COLOR.a;
}
