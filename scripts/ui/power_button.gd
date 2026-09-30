class_name PowerButton
extends Button
## A streamer power button that shows the shared cooldown: while it runs the button is
## disabled and a bar fills it from left to right. A short pulse marks the moment it is ready.

const FLASH_SECONDS: float = 0.35
const BAR_COLOR: Color = Color(UiStyle.CYAN, 0.35)
## Gap between the button border and the bar.
const INSET: float = 2.0

var _bar: ColorRect
var _cooling: bool = false
var _fraction: float = 1.0
var _flash_tween: Tween


func _ready() -> void:
	_bar = ColorRect.new()
	_bar.color = BAR_COLOR
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.anchor_bottom = 1.0
	_bar.offset_left = INSET
	_bar.offset_top = INSET
	_bar.offset_bottom = -INSET
	_bar.visible = false
	add_child(_bar)
	resized.connect(_update_bar)


func is_cooling() -> bool:
	return _cooling


## Shows the cooldown as [param fraction] done, 0..1. Use 1 for ready.
func set_cooldown_progress(fraction: float) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	var cooling: bool = _fraction < 1.0
	if cooling != _cooling:
		_cooling = cooling
		disabled = cooling
		_bar.visible = cooling
		if not cooling:
			_flash()
	_update_bar()


func _update_bar() -> void:
	if _bar != null:
		_bar.offset_right = INSET + maxf(0.0, size.x - 2.0 * INSET) * _fraction


func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	modulate = Color(1.8, 1.8, 1.8)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, FLASH_SECONDS)
