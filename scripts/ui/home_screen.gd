class_name HomeScreen
extends Control
## Landing screen. Buttons in the menu box open one part of the game each.
## Also lets the streamer log in with Twitch (web only) so chat works without hand-made URLs.

const RACE_SCENE: String = "res://scenes/main.tscn"

@onready var _open_lobby: Button = $Center/Box/OpenLobby
@onready var _login_status: Label = $Center/Box/LoginStatus
@onready var _client_id: LineEdit = $Center/Box/ClientId
@onready var _login: Button = $Center/Box/Login
@onready var _logout: Button = $Center/Box/Logout


func _ready() -> void:
	_open_lobby.pressed.connect(_on_open_lobby_pressed)
	_login.pressed.connect(_on_login_pressed)
	_logout.pressed.connect(Chat.logout)
	Chat.login_changed.connect(_refresh_login)
	_client_id.text = Chat.store.load_client_id()
	_open_lobby.grab_focus()
	_refresh_login()


func _on_open_lobby_pressed() -> void:
	get_tree().change_scene_to_file(RACE_SCENE)


func _on_login_pressed() -> void:
	Chat.begin_login(_client_id.text)


func _refresh_login() -> void:
	var logged_in: bool = Chat.login_status == "logged_in"
	var web: bool = OS.has_feature("web")
	match Chat.login_status:
		"logged_in":
			_login_status.text = "Logged in as %s" % Chat.session.get("login", "?")
		"validating":
			_login_status.text = "Checking Twitch login..."
		"error":
			_login_status.text = Chat.login_error
		_:
			_login_status.text = "Not logged in" if web else "Twitch login needs the web build"
	_client_id.visible = not logged_in
	_login.visible = not logged_in
	_login.disabled = not web
	_logout.visible = logged_in
