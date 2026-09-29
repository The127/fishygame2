class_name SettingsScreen
extends Control
## Streamer settings: edits a [GameSettings], saving after every change.

const HOME_SCENE: String = "res://scenes/ui/home_screen.tscn"
const RANDOM_LABEL: String = "Random"

var settings: GameSettings = null

var _spinners: Dictionary[String, SpinBox] = {}
var _map_picker: OptionButton
var _chat_replies: CheckBox
var _status: Label


func _ready() -> void:
	if settings == null:
		settings = GameSettings.new(GameSettings.DEFAULT_PATH)
		settings.load_settings()
	_build()
	_refresh()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.012, 0.047, 0.102)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 640.0
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(title, 44, 900, UiStyle.CYAN, 6)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for field: Dictionary in GameSettings.FIELDS:
		var spinner := SpinBox.new()
		spinner.min_value = float(field["min"])
		spinner.max_value = float(field["max"])
		spinner.step = float(field["step"])
		spinner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spinner.value_changed.connect(_on_number_changed.bind(String(field["key"])))
		_spinners[String(field["key"])] = spinner
		grid.add_child(_row_label(String(field["label"])))
		grid.add_child(spinner)
	_map_picker = OptionButton.new()
	_map_picker.add_item(RANDOM_LABEL)
	_map_picker.set_item_metadata(0, GameSettings.RANDOM_MAP)
	for id: String in TrackCatalog.ids():
		_map_picker.add_item(TrackCatalog.get_name_of(id))
		_map_picker.set_item_metadata(_map_picker.item_count - 1, id)
	_map_picker.item_selected.connect(_on_map_picked)
	UiStyle.style_button(_map_picker, 20)
	grid.add_child(_row_label("Default map"))
	grid.add_child(_map_picker)
	_chat_replies = CheckBox.new()
	_chat_replies.text = "Reply in chat"
	_chat_replies.add_theme_font_override("font", UiStyle.font(600))
	_chat_replies.add_theme_font_size_override("font_size", 22)
	_chat_replies.add_theme_color_override("font_color", UiStyle.TEXT)
	_chat_replies.toggled.connect(_on_chat_replies_toggled)
	box.add_child(_chat_replies)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(_status, 18, 600, UiStyle.MUTED)
	box.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var reset := Button.new()
	reset.name = "Reset"
	reset.text = "RESET TO DEFAULTS"
	reset.pressed.connect(reset_pressed)
	UiStyle.style_button(reset, 20)
	buttons.add_child(reset)
	var back := Button.new()
	back.name = "Back"
	back.text = "BACK"
	back.pressed.connect(_on_back_pressed)
	UiStyle.style_button(back, 20)
	buttons.add_child(back)


func _row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.style_label(label, 22, 600, UiStyle.MUTED)
	return label


## Copies the settings into the controls without triggering their change handlers.
func _refresh() -> void:
	for key: String in _spinners:
		_spinners[key].set_value_no_signal(float(settings.get(key)))
	for i: int in _map_picker.item_count:
		if String(_map_picker.get_item_metadata(i)) == settings.default_map:
			_map_picker.select(i)
	_chat_replies.set_pressed_no_signal(settings.chat_replies)


func _commit() -> void:
	settings.sanitize()
	_refresh()
	_status.text = "Saved" if settings.save() else "Could not save in this browser"


func _on_number_changed(value: float, key: String) -> void:
	settings.set_number(key, value)
	_commit()


func _on_map_picked(index: int) -> void:
	settings.default_map = String(_map_picker.get_item_metadata(index))
	_commit()


func _on_chat_replies_toggled(pressed: bool) -> void:
	settings.chat_replies = pressed
	_commit()


func reset_pressed() -> void:
	settings.reset_to_defaults()
	_commit()
	_status.text = "Defaults restored"


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)
