shader_type canvas_item;
// Green to cyan gradient across the screen width, keeping the label's alpha.

uniform vec3 left_color : source_color = vec3(0.0, 0.91, 0.533);
uniform vec3 right_color : source_color = vec3(0.541, 0.91, 1.0);

void fragment() {
	float t = smoothstep(0.28, 0.72, SCREEN_UV.x);
	COLOR = vec4(mix(left_color, right_color, t), COLOR.a);
}
