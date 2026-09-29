class_name PaddingPreview
extends Control
## Miniature screen for the settings: the blocked-out edges are shaded, the area the game
## uses is outlined.

const SCREEN_COLOR: Color = Color(0.02, 0.09, 0.16)
const BLOCKED_COLOR: Color = Color(0.35, 0.4, 0.45, 0.55)

var _play_fraction: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)


## `fraction` is the game area as fractions of the screen size.
func set_play_fraction(fraction: Rect2) -> void:
	_play_fraction = fraction
	queue_redraw()


func _draw() -> void:
	var screen := Rect2(Vector2.ZERO, size)
	var play := Rect2(_play_fraction.position * size, _play_fraction.size * size)
	draw_rect(screen, SCREEN_COLOR)
	draw_rect(screen, BLOCKED_COLOR)
	draw_rect(play, SCREEN_COLOR)
	draw_rect(play, UiStyle.CYAN, false, 2.0)
	draw_rect(screen, UiStyle.MUTED, false, 1.0)
