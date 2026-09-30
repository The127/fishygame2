class_name HomeScreen
extends Control
## Landing screen. Buttons in the menu box open one part of the game each.
## Also lets the streamer log in with Twitch (web only) so chat works without hand-made URLs.

const SETTINGS_SCENE: String = "res://scenes/ui/settings_screen.tscn"
const ONBOARDING_SCENE: String = "res://scenes/ui/onboarding_screen.tscn"
const AQUARIUM_SCENE: String = "res://scenes/aquarium/aquarium_screen.tscn"
const RACE_SCENE: String = "res://scenes/main.tscn"
## The menu box never exceeds this width, and shrinks with the window.
const MAX_BOX_WIDTH: float = 1200.0
const SIDE_MARGIN: float = 24.0
const TITLE_FONT_SIZE: int = 96
const TITLE_MIN_FONT_SIZE: int = 36
## Window width at which the title uses its full size on a single line.
const TITLE_FULL_WIDTH: float = 1100.0

var _board: LeaderboardPanel

@onready var _box: VBoxContainer = $Center/Box
@onready var _title: Label = $Center/Box/Title
@onready var _open_lobby: Button = $Center/Box/OpenLobby
@onready var _aquarium: Button = $Center/Box/Aquarium
@onready var _settings: Button = $Center/Box/Settings
@onready var _login_status: Label = $Center/Box/LoginStatus
@onready var _client_id: LineEdit = $Center/Box/ClientId
@onready var _login: Button = $Center/Box/Login
@onready var _logout: Button = $Center/Box/Logout


func _ready() -> void:
	Sound.set_music_theme(Sound.HOME_THEME)
	_board = LeaderboardPanel.new()
	_board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_board)
	_box.move_child(_board, _settings.get_index() + 1)
	show_leaderboard(_load_store())
	_add_version_tag()
	_open_lobby.pressed.connect(_on_open_lobby_pressed)
	_aquarium.pressed.connect(_on_aquarium_pressed)
	_settings.pressed.connect(_on_settings_pressed)
	UiStyle.style_button(_aquarium, 28)
	UiStyle.style_button(_settings, 28)
	if DebugMode.is_enabled():
		var ears_button: Button = Button.new()
		ears_button.name = "DebugEars"
		ears_button.text = "Debug: cat ears"
		ears_button.focus_mode = Control.FOCUS_NONE
		ears_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		UiStyle.style_button(ears_button, 24)
		ears_button.pressed.connect(($Scene3D as HomeScene3D).force_ears)
		_box.add_child(ears_button)
		_box.move_child(ears_button, _settings.get_index() + 1)
	_login.pressed.connect(_on_login_pressed)
	_logout.pressed.connect(Chat.logout)
	Chat.login_changed.connect(_refresh_login)
	_client_id.text = Chat.store.load_client_id()
	resized.connect(_fit_to_window)
	_fit_to_window()
	_open_lobby.grab_focus()
	_refresh_login()
	# Fire and forget: waits a few frames, then makes the web page transparent again.
	WebBoot.release_background()
	# Only when this is the running scene, so tests that instantiate the screen stay put.
	if get_tree().current_scene == self and not OnboardingStore.new().is_done():
		get_tree().change_scene_to_file.call_deferred(ONBOARDING_SCENE)


## Small build tag in the bottom right corner.
func _add_version_tag() -> void:
	var tag: Label = Label.new()
	tag.name = "Version"
	tag.text = BuildInfo.label()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.style_label(tag, 14, 600, UiStyle.MUTED)
	tag.modulate.a = 0.6
	add_child(tag)
	tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)


## Fills the all-time board from [param store]; hidden while nobody is ranked.
func show_leaderboard(store: PointsStore) -> void:
	_board.visible = _board.set_rows(
		store.top_by_points(LeaderboardPanel.ROWS), store.top_by_wins(LeaderboardPanel.ROWS)
	)


func _load_store() -> PointsStore:
	var store := PointsStore.new(PointsStore.DEFAULT_PATH)
	store.load_from_disk()
	return store


## Keeps the title (and the box around it) inside the window: the box narrows
## with the window and the title font shrinks until it fits, wrapping as a last resort.
func _fit_to_window() -> void:
	var width: float = maxf(size.x - SIDE_MARGIN * 2.0, 0.0)
	_box.custom_minimum_size.x = minf(width, MAX_BOX_WIDTH)
	_board.fit_width(_box.custom_minimum_size.x)
	var fit: float = clampf(width / TITLE_FULL_WIDTH, 0.0, 1.0)
	var font_size: int = maxi(roundi(TITLE_FONT_SIZE * fit), TITLE_MIN_FONT_SIZE)
	_title.add_theme_font_size_override("font_size", font_size)


func _on_open_lobby_pressed() -> void:
	get_tree().change_scene_to_file(RACE_SCENE)


func _on_aquarium_pressed() -> void:
	get_tree().change_scene_to_file(AQUARIUM_SCENE)


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _on_login_pressed() -> void:
	Chat.begin_login(_client_id.text)


func _refresh_login() -> void:
	var logged_in: bool = Chat.login_status == TwitchAuth.LoginStatus.LOGGED_IN
	var web: bool = OS.has_feature("web")
	_login_status.text = TwitchAuth.status_text(
		Chat.login_status, str(Chat.session.get("login", "?")), Chat.login_error, web
	)
	_client_id.visible = not logged_in
	_login.visible = not logged_in
	_login.disabled = not web
	_logout.visible = logged_in
