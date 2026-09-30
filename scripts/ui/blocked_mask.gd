class_name BlockedMask
extends Control
## Solid black over the screen edges the streamer reserved for their own overlays, so the
## race never shows through behind a webcam or chat box.

const COLOR: Color = Color.BLACK

var _play_fraction: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## `fraction` is the game area as fractions of the screen size.
func set_play_fraction(fraction: Rect2) -> void:
	_play_fraction = fraction
	queue_redraw()


func _draw() -> void:
	var play := Rect2(_play_fraction.position * size, _play_fraction.size * size)
	# Four bars around the play area; overlapping corners are drawn once.
	draw_rect(Rect2(0.0, 0.0, size.x, play.position.y), COLOR)
	draw_rect(Rect2(0.0, play.end.y, size.x, size.y - play.end.y), COLOR)
	draw_rect(Rect2(0.0, play.position.y, play.position.x, play.size.y), COLOR)
	draw_rect(Rect2(play.end.x, play.position.y, size.x - play.end.x, play.size.y), COLOR)
