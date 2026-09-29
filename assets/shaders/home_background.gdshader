shader_type canvas_item;
// Deep ocean backdrop: dark navy vertical gradient with a soft glow behind the title.

const vec3 TOP = vec3(0.012, 0.047, 0.102);
const vec3 BOTTOM = vec3(0.024, 0.078, 0.141);
const vec3 GLOW = vec3(0.0, 0.39, 0.78);

void fragment() {
	vec3 col = mix(TOP, BOTTOM, UV.y);
	vec2 p = (UV - vec2(0.5, 0.45)) / vec2(0.6, 0.5);
	float glow = smoothstep(1.0, 0.0, length(p));
	col += GLOW * glow * 0.14;
	COLOR = vec4(col, 1.0);
}
