class_name HomeScreen
extends Control
## Landing screen. Buttons in the menu box open one part of the game each.

const RACE_SCENE: String = "res://scenes/main.tscn"

@onready var _open_lobby: Button = $Center/Box/OpenLobby


func _ready() -> void:
	_open_lobby.pressed.connect(_on_open_lobby_pressed)
	_open_lobby.grab_focus()


func _on_open_lobby_pressed() -> void:
	get_tree().change_scene_to_file(RACE_SCENE)
