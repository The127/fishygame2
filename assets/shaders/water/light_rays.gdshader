shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// A soft shaft of sunlight. Put several on slanted quads.

uniform vec3 ray_color : source_color = vec3(0.45, 0.85, 1.0);
uniform float strength = 0.22;
uniform float phase = 0.0;

void fragment() {
	float edge = smoothstep(0.0, 0.5, UV.x) * smoothstep(1.0, 0.5, UV.x);
	float fade = pow(1.0 - UV.y, 1.4);
	float shimmer = 0.75 + 0.25 * sin(TIME * 0.7 + phase) * sin(TIME * 0.31 + phase * 2.3);
	ALBEDO = ray_color;
	ALPHA = edge * edge * fade * strength * shimmer;
}
