class_name NetZone
extends Node2D
## A net the streamer cast: a round patch of the track that holds fish for a few seconds.
## It only remembers where it is and how long it lasts; Race does the holding.

var radius: float = 170.0
var life: float = 2.5
var _age: float = 0.0


func _ready() -> void:
	z_index = 6


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= life:
		queue_free()


func contains(point: Vector2) -> bool:
	return global_position.distance_to(point) <= radius


## 1 while the net is fully there, fading to 0 in its last half second.
func strength() -> float:
	return clampf((life - _age) / 0.5, 0.0, 1.0)


func _draw() -> void:
	var alpha: float = strength()
	var color: Color = Color(0.85, 0.95, 1.0, 0.75 * alpha)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 3.0)
	draw_circle(Vector2.ZERO, radius, Color(0.6, 0.85, 1.0, 0.08 * alpha))
	var step: float = radius / 3.0
	for i: int in range(-2, 3):
		var offset: float = float(i) * step
		var half: float = sqrt(maxf(radius * radius - offset * offset, 0.0))
		draw_line(Vector2(offset, -half), Vector2(offset, half), color, 1.5)
		draw_line(Vector2(-half, offset), Vector2(half, offset), color, 1.5)
