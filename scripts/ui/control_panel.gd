class_name ControlPanel
extends CanvasLayer
## Every streamer control in one place. F1 hides or shows it (hide it for OBS).

signal open_lobby_pressed
signal start_pressed
signal stop_pressed
signal add_debug_players_pressed(count: int)
## Emits a map id, or TrackCatalog.RANDOM_ID for a random map.
signal map_selected(choice: String)

@onready var _panel: PanelContainer = $Panel
@onready var _status: Label = $Panel/Box/Status
@onready var _map_picker: OptionButton = $Panel/Box/MapRow/MapPicker


func _ready() -> void:
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


func _on_map_picked(index: int) -> void:
	map_selected.emit(String(_map_picker.get_item_metadata(index)))
