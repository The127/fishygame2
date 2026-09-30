class_name SoundHint
extends CanvasLayer
## Small "click to enable sound" note, shown on the web build while the browser still keeps
## the audio context suspended (autoplay policy). It disappears by itself on the first click
## or key press, and never shows in an OBS source that is allowed to autoplay.

const POLL_SECONDS: float = 0.5
const TEXT: String = "Click anywhere to enable sound"
## Defined by html/head_include in the export preset.
const STATE_JS: String = "window.fishyAudioState ? window.fishyAudioState() : 'none'"

var _label: Label
var _elapsed: float = 0.0


func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.text = TEXT
	_label.visible = false
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_bottom = -24.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.09, 0.16, 1.0))
	_label.add_theme_constant_override("outline_size", 8)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	set_process(OS.has_feature("web"))


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < POLL_SECONDS:
		return
	_elapsed = 0.0
	var state: Variant = JavaScriptBridge.eval(STATE_JS, true)
	_label.visible = is_blocked(str(state))


## True for the browser audio context state that means "waiting for a user gesture".
static func is_blocked(context_state: String) -> bool:
	return context_state == "suspended"
