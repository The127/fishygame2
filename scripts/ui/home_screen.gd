class_name HomeScreen
extends Control
## Landing screen. Buttons in the menu box open one part of the game each.
## Also lets the streamer log in with Twitch (web only) so chat works without hand-made URLs.

const RACE_SCENE: String = "res://scenes/main.tscn"
## The menu box never exceeds this width, and shrinks with the window.
const MAX_BOX_WIDTH: float = 1200.0
const SIDE_MARGIN: float = 24.0
const TITLE_FONT_SIZE: int = 96
const TITLE_MIN_FONT_SIZE: int = 36
## Window width at which the title uses its full size on a single line.
const TITLE_FULL_WIDTH: float = 1100.0

@onready var _box: VBoxContainer = $Center/Box
@onready var _title: Label = $Center/Box/Title
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
	resized.connect(_fit_to_window)
	_fit_to_window()
	_open_lobby.grab_focus()
	_refresh_login()


## Keeps the title (and the box around it) inside the window: the box narrows
## with the window and the title font shrinks until it fits, wrapping as a last resort.
func _fit_to_window() -> void:
	var width: float = maxf(size.x - SIDE_MARGIN * 2.0, 0.0)
	_box.custom_minimum_size.x = minf(width, MAX_BOX_WIDTH)
	var scale: float = clampf(width / TITLE_FULL_WIDTH, 0.0, 1.0)
	var font_size: int = maxi(roundi(TITLE_FONT_SIZE * scale), TITLE_MIN_FONT_SIZE)
	_title.add_theme_font_size_override("font_size", font_size)


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
