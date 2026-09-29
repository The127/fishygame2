class_name OnboardingScreen
extends Control
## First-run setup guide for the streamer: Twitch app, login, OBS, safe areas, debug mode.
## Shown until finished or skipped, and reopenable from the settings screen.

const HOME_SCENE: String = "res://scenes/ui/home_screen.tscn"
const TWITCH_CONSOLE_URL: String = "https://dev.twitch.tv/console/apps"
const REDIRECT_PLACEHOLDER: String = "https://<where the game is hosted>/"
const STEP_TITLES: PackedStringArray = [
	"REGISTER A TWITCH APP",
	"LOG IN",
	"ADD TO OBS",
	"SAFE AREAS AND DEBUG",
]
const STEP_TEXTS: PackedStringArray = [
	(
		"Once per host, at the Twitch developer console:\n"
		+ "1. Create an app. Category: Game Integration, client type: Public.\n"
		+ "2. Add this exact OAuth Redirect URL (with the trailing slash).\n"
		+ "3. Copy the app's Client ID. It is not a secret; never use a client secret."
	),
	(
		"Paste the Client ID and log in with the Twitch account that owns the channel. "
		+ "You will be asked to allow reading and writing chat."
	),
	(
		"In OBS add a Browser source with this page's address, width 1920 and height 1080.\n"
		+ "Right-click the source and choose Interact to click buttons and log in.\n"
		+ 'Tick "Control audio via OBS" so the game\'s sound reaches your mix.'
	),
	(
		"Settings has Blocked left, right, top and bottom: screen edges the game stays out of, "
		+ "for your webcam or chat overlay.\n"
		+ "Debug mode (add ?debug=1 to the address) shows fake players and fake chat for "
		+ "testing. Never leave it on for a stream."
	),
]

var store: OnboardingStore = OnboardingStore.new()

var _step: int = 0
var _title: Label
var _body: Label
var _extra: VBoxContainer
var _progress: Label
var _status: Label
var _back: Button
var _next: Button
var _client_id: LineEdit
var _login: Button
var _logout: Button
var _login_status: Label


func _ready() -> void:
	_build()
	# Coming back from twitch.tv: continue at the login step to show the result.
	if Chat.login_status != TwitchAuth.LoginStatus.LOGGED_OUT:
		_step = 1
	Chat.login_changed.connect(_refresh_login)
	_show_step()


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
	box.custom_minimum_size.x = 720.0
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(_progress, 18, 600, UiStyle.MUTED, 3)
	box.add_child(_progress)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(_title, 40, 900, UiStyle.CYAN, 5)
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.style_label(_body, 22, 600)
	box.add_child(_body)
	_extra = VBoxContainer.new()
	_extra.add_theme_constant_override("separation", 10)
	box.add_child(_extra)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(_status, 18, 600, UiStyle.MUTED)
	box.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var skip := _make_button("Skip", "SKIP", buttons)
	skip.pressed.connect(finish)
	_back = _make_button("Back", "BACK", buttons)
	_back.pressed.connect(go_back)
	_next = _make_button("Next", "NEXT", buttons)
	_next.pressed.connect(go_next)
	_build_extras()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finish()


func _make_button(node_name: String, text: String, parent: Node) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiStyle.style_button(button, 20)
	parent.add_child(button)
	return button


## Widgets that belong to one step live in their own container, shown only on that step.
func _build_extras() -> void:
	var redirect_row := HBoxContainer.new()
	redirect_row.name = "Redirect"
	redirect_row.add_theme_constant_override("separation", 10)
	var redirect := LineEdit.new()
	redirect.name = "RedirectUrl"
	redirect.editable = false
	redirect.text = redirect_url()
	redirect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	redirect.add_theme_font_size_override("font_size", 20)
	redirect_row.add_child(redirect)
	var copy := _make_button("Copy", "COPY", redirect_row)
	copy.pressed.connect(_on_copy_pressed.bind(redirect))
	_extra.add_child(redirect_row)
	var console := _make_button("OpenConsole", "OPEN TWITCH CONSOLE", _extra)
	console.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	console.pressed.connect(OS.shell_open.bind(TWITCH_CONSOLE_URL))
	var login_box := VBoxContainer.new()
	login_box.name = "LoginBox"
	login_box.add_theme_constant_override("separation", 10)
	_login_status = Label.new()
	_login_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_login_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.style_label(_login_status, 20, 600, UiStyle.MUTED)
	login_box.add_child(_login_status)
	_client_id = LineEdit.new()
	_client_id.placeholder_text = "Twitch app client id"
	_client_id.text = Chat.store.load_client_id()
	_client_id.add_theme_font_size_override("font_size", 22)
	login_box.add_child(_client_id)
	_login = _make_button("Login", "LOG IN WITH TWITCH", login_box)
	_login.pressed.connect(_on_login_pressed)
	_logout = _make_button("Logout", "LOG OUT", login_box)
	_logout.pressed.connect(Chat.logout)
	_extra.add_child(login_box)


## The redirect URL to register at Twitch: this page's own address on web.
static func redirect_url() -> String:
	var url: String = TwitchAuth.current_redirect_url()
	return url if not url.is_empty() else REDIRECT_PLACEHOLDER


func _show_step() -> void:
	_progress.text = "STEP %d OF %d" % [_step + 1, STEP_TITLES.size()]
	_title.text = STEP_TITLES[_step]
	_body.text = STEP_TEXTS[_step]
	_extra.get_node("Redirect").visible = _step == 0
	_extra.get_node("OpenConsole").visible = _step == 0
	_extra.get_node("LoginBox").visible = _step == 1
	_status.text = ""
	_back.disabled = _step == 0
	_next.text = "FINISH" if is_last_step() else "NEXT"
	_refresh_login()


func is_last_step() -> bool:
	return _step == STEP_TITLES.size() - 1


func go_next() -> void:
	if is_last_step():
		finish()
		return
	_step += 1
	_show_step()


func go_back() -> void:
	_step = maxi(_step - 1, 0)
	_show_step()


## Marks the onboarding as done (at least for this page load) and returns to the home screen.
func finish() -> void:
	OnboardingStore.dismissed_this_session = true
	store.set_done(true)
	get_tree().change_scene_to_file(HOME_SCENE)


func _on_copy_pressed(field: LineEdit) -> void:
	DisplayServer.clipboard_set(field.text)
	_status.text = "Copied"


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
