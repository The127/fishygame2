class_name ControlPanel
extends CanvasLayer
## Every streamer control in one place. F1 hides or shows it (hide it for OBS).

signal open_lobby_pressed
signal start_pressed
signal stop_pressed
signal add_debug_players_pressed(count: int)
## Emits a map id, or TrackCatalog.RANDOM_ID for a random map.
signal map_selected(choice: String)
## Emits a bus name (see AudioSettings.BUSES) and a linear volume 0..1.
signal volume_changed(bus: String, value: float)
signal mute_toggled(muted: bool)

const VOLUME_ROWS: Dictionary = {
	AudioSettings.BUS_MASTER: "Master",
	AudioSettings.BUS_MUSIC: "Music",
	AudioSettings.BUS_SFX: "Effects",
}

@onready var _panel: PanelContainer = $Panel
@onready var _status: Label = $Panel/Box/Status
@onready var _map_picker: OptionButton = $Panel/Box/MapRow/MapPicker
@onready var _mute: CheckBox = $Panel/Box/Mute
@onready var _volume_sliders: Dictionary = {
	AudioSettings.BUS_MASTER: $Panel/Box/MasterRow/Slider,
	AudioSettings.BUS_MUSIC: $Panel/Box/MusicRow/Slider,
	AudioSettings.BUS_SFX: $Panel/Box/SfxRow/Slider,
}


func _ready() -> void:
	_apply_style()
	($Panel/Box/Buttons/Open as Button).pressed.connect(open_lobby_pressed.emit)
	($Panel/Box/Buttons/Start as Button).pressed.connect(start_pressed.emit)
	($Panel/Box/Buttons/Stop as Button).pressed.connect(stop_pressed.emit)
	($Panel/Box/DebugButtons as Control).visible = DebugMode.is_enabled()
	($Panel/Box/DebugButtons/AddOne as Button).pressed.connect(
		add_debug_players_pressed.emit.bind(1)
	)
	($Panel/Box/DebugButtons/AddFive as Button).pressed.connect(
		add_debug_players_pressed.emit.bind(5)
	)
	_map_picker.add_item("Random")
	_map_picker.set_item_metadata(0, TrackCatalog.RANDOM_ID)
	for id: String in TrackCatalog.ids():
		_map_picker.add_item(TrackCatalog.get_name_of(id))
		_map_picker.set_item_metadata(_map_picker.item_count - 1, id)
	_map_picker.item_selected.connect(_on_map_picked)
	_mute.toggled.connect(mute_toggled.emit)
	for bus: String in _volume_sliders:
		(_volume_sliders[bus] as HSlider).value_changed.connect(volume_changed.emit.bind(bus))


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F1:
		_panel.visible = not _panel.visible
	elif key.keycode == KEY_SPACE:
		start_pressed.emit()


func set_status(text: String) -> void:
	_status.text = text


## Shows the current audio choices without emitting any signal. Volumes are linear 0..1 per bus.
func set_audio_state(volumes: Dictionary, muted: bool) -> void:
	_mute.set_pressed_no_signal(muted)
	for bus: String in _volume_sliders:
		(_volume_sliders[bus] as HSlider).set_value_no_signal(float(volumes.get(bus, 1.0)))


func _apply_style() -> void:
	_panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	UiStyle.style_label(_status, 22, 700, UiStyle.CYAN)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.style_label($Panel/Box/MapRow/MapLabel as Label, 22, 600, UiStyle.MUTED)
	UiStyle.style_label($Panel/Box/Hint as Label, 18, 600, UiStyle.MUTED)
	_mute.add_theme_font_override("font", UiStyle.font(600))
	_mute.add_theme_font_size_override("font_size", 22)
	_mute.add_theme_color_override("font_color", UiStyle.TEXT)
	for row: String in ["MasterRow", "MusicRow", "SfxRow"]:
		UiStyle.style_label(get_node("Panel/Box/%s/Label" % row) as Label, 22, 600, UiStyle.MUTED)
	for button: Button in [
		$Panel/Box/Buttons/Open,
		$Panel/Box/Buttons/Start,
		$Panel/Box/Buttons/Stop,
		$Panel/Box/DebugButtons/AddOne,
		$Panel/Box/DebugButtons/AddFive,
		_map_picker,
	]:
		UiStyle.style_button(button, 20)
	# Popup menu of the map picker: dark panel and the same font.
	var popup: PopupMenu = _map_picker.get_popup()
	popup.add_theme_font_override("font", UiStyle.font(600))
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_stylebox_override("panel", UiStyle.panel_box())
	popup.add_theme_color_override("font_color", UiStyle.TEXT)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_stylebox_override("hover", UiStyle.button_box(true))


func _on_map_picked(index: int) -> void:
	map_selected.emit(String(_map_picker.get_item_metadata(index)))
