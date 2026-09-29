shader_type canvas_item;
// Sways a statically drawn silhouette: the further from its anchor line, the more it moves.

uniform float amplitude = 20.0;
uniform float anchor_y = 1140.0;
uniform float reach = 400.0;
uniform float speed = 0.9;

void vertex() {
	float h = clamp(abs(VERTEX.y - anchor_y) / reach, 0.0, 1.0);
	VERTEX.x += sin(TIME * speed + VERTEX.y * 0.008 + VERTEX.x * 0.01) * amplitude * h * h;
}
