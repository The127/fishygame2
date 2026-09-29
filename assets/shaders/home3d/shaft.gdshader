shader_type spatial;
// Soft slanted light shaft: fades toward its edges and toward the bottom, shimmers slowly.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 shaft_color : source_color = vec4(0.25, 0.75, 1.0, 0.16);
uniform float shimmer_speed = 0.6;
uniform float phase = 0.0;

void fragment() {
	float across = pow(1.0 - abs(UV.x * 2.0 - 1.0), 2.0);
	float down = pow(1.0 - UV.y, 1.6);
	float shimmer = 0.75 + 0.25 * sin(TIME * shimmer_speed + phase + UV.y * 5.0);
	ALBEDO = shaft_color.rgb;
	ALPHA = across * down * shimmer * shaft_color.a;
}
