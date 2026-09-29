class_name ControlPanel
extends CanvasLayer
## Every streamer control in one place. F1 hides or shows it (hide it for OBS).

signal open_lobby_pressed
signal start_pressed
signal stop_pressed
signal add_debug_players_pressed(count: int)

@onready var _panel: PanelContainer = $Panel
@onready var _status: Label = $Panel/Box/Status


func _ready() -> void:
	($Panel/Box/Buttons/Open as Button).pressed.connect(open_lobby_pressed.emit)
	($Panel/Box/Buttons/Start as Button).pressed.connect(start_pressed.emit)
	($Panel/Box/Buttons/Stop as Button).pressed.connect(stop_pressed.emit)
	($Panel/Box/DebugButtons/AddOne as Button).pressed.connect(
		add_debug_players_pressed.emit.bind(1)
	)
	($Panel/Box/DebugButtons/AddFive as Button).pressed.connect(
		add_debug_players_pressed.emit.bind(5)
	)


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
