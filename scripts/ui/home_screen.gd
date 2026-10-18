class_name HomeScreen
extends Control
## Landing screen. Buttons in the menu box open one part of the game each.
## Also lets the streamer log in with Twitch (web only) so chat works without hand-made URLs.

## Emitted when the 4D joke glitched back to the normal home screen.
signal surprise_ended

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
## Characters at the end of the title that the release surprise squishes (the "II").
const TITLE_NUMBER_LENGTH: int = 2
const SEQUEL_TAGLINE: String = "NOW IN 3D. CHAT JOINS AS FISH. FISH RACE DOWN THE TRACK."
const SEQUEL_PLAY_TEXT: String = "PLAY"
const REPLAY_SURPRISE_TEXT: String = "REPLAY 3D"
const RTX_ON_TEXT: String = "RTX ON"
const RTX_OFF_TEXT: String = "RTX OFF"
const SEQUEL_REVEAL_SHADER: String = "res://assets/shaders/surprise/sequel_reveal.gdshader"
## Seconds the ring takes to uncover the fake sequel's flyover backdrop.
const SEQUEL_REVEAL_SECONDS: float = 1.6
const FOUR_D_TAGLINE: String = "NOW IN 4D. YOUR FISH SWIM IN EVERY DIRECTION AT ONCE."
const GLITCH_SHADER: String = "res://assets/shaders/surprise/glitch.gdshader"
const FOUR_D_RIM: Color = Color(0.7, 0.3, 1.0)
## Seconds of 4D before it starts to break, and of the glitch before and after the switch
## back to the real game.
const FOUR_D_SECONDS: float = 5.0
const GLITCH_IN_SECONDS: float = 1.4
const GLITCH_OUT_SECONDS: float = 0.6
## Ends of the title gradient, as in title_gradient.gdshader.
const TITLE_LEFT_COLOR: Color = Color(0.0, 0.91, 0.533)
const TITLE_RIGHT_COLOR: Color = Color(0.541, 0.91, 1.0)
## The aquarium button fades to this alpha and back until it has been pressed once.
const AQUARIUM_BLINK_ALPHA: float = 0.35
const AQUARIUM_BLINK_SECONDS: float = 0.6

var settings: GameSettings = null
var surprise_store: ReleaseSurpriseStore = ReleaseSurpriseStore.new()
var aquarium_store: AquariumVisitStore = AquariumVisitStore.new()

var _board: LeaderboardPanel
var _title_drop: TitleDrop
var _flyover: TrackFlyover
var _four_d: FourDView
var _replay_surprise: Button
var _rtx_button: Button
var _rtx_filter: RtxFilter = RtxFilter.new()
var _tagline_text: String
var _open_lobby_text: String
var _aquarium_blink: Tween

@onready var _box: VBoxContainer = $Center/Box
@onready var _title: Label = $Center/Box/Title
@onready var _tagline: Label = $Center/Box/Tagline
@onready var _open_lobby: Button = $Center/Box/OpenLobby
@onready var _aquarium: Button = $Center/Box/Aquarium
@onready var _settings: Button = $Center/Box/Settings
@onready var _login_status: Label = $Center/Box/LoginStatus
@onready var _client_id: LineEdit = $Center/Box/ClientId
@onready var _login: Button = $Center/Box/Login
@onready var _logout: Button = $Center/Box/Logout


func _ready() -> void:
	if settings == null:
		settings = GameSettings.new(GameSettings.DEFAULT_PATH)
		settings.load_settings()
	Sound.set_music_theme(Sound.HOME_THEME)
	_board = LeaderboardPanel.new()
	_board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_board)
	_box.move_child(_board, _settings.get_index() + 1)
	show_leaderboard(_load_store())
	_add_version_tag()
	_tagline_text = _tagline.text
	_open_lobby_text = _open_lobby.text
	_open_lobby.pressed.connect(_on_open_lobby_pressed)
	_aquarium.pressed.connect(_on_aquarium_pressed)
	_settings.pressed.connect(_on_settings_pressed)
	UiStyle.style_button(_aquarium, 28)
	UiStyle.style_button(_settings, 28)
	if not aquarium_store.is_visited():
		_start_aquarium_blink()
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
	if ReleaseSurprise.is_sequel():
		if settings.release_surprise:
			_show_sequel.call_deferred(false)
		else:
			# Turned off in the settings: back to the real game.
			ReleaseSurprise.end()
	_add_corner_buttons()
	_rtx_filter.set_badge_at_top(true)
	add_child(_rtx_filter)
	_apply_rtx()
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


## Small buttons stacked in the bottom left corner: one that arms the release surprise
## again, shown once it has played (the next Open Lobby press then starts it over), and
## below it the RTX switch, which saves to the settings. They sit on their own layer.
func _add_corner_buttons() -> void:
	# Above the RTX filter, so its vignette never darkens the switch that turns it off.
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CornerLayer"
	layer.layer = RtxFilter.LAYER + 1
	add_child(layer)
	var corner: VBoxContainer = VBoxContainer.new()
	corner.name = "Corner"
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(corner)
	_replay_surprise = Button.new()
	_replay_surprise.name = "ReplaySurprise"
	_replay_surprise.text = REPLAY_SURPRISE_TEXT
	_replay_surprise.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(_replay_surprise, 16)
	_replay_surprise.pressed.connect(_on_replay_surprise_pressed)
	corner.add_child(_replay_surprise)
	_rtx_button = Button.new()
	_rtx_button.name = "Rtx"
	_rtx_button.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(_rtx_button, 16)
	_rtx_button.pressed.connect(_on_rtx_pressed)
	corner.add_child(_rtx_button)
	corner.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12
	)
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_refresh_replay_button()


func _refresh_replay_button() -> void:
	# Kept out of the release surprise, which it would otherwise sit on top of.
	# RTX is unlocked by the fake 3D sequel having played once.
	_rtx_button.visible = (
		ReleaseSurprise.stage == ReleaseSurprise.Stage.OFF and surprise_store.has_played()
	)
	_replay_surprise.visible = (
		settings.release_surprise
		and ReleaseSurprise.stage == ReleaseSurprise.Stage.OFF
		and surprise_store.is_seen()
	)


func _on_rtx_pressed() -> void:
	settings.rtx = not settings.rtx
	settings.save()
	_apply_rtx()


func _apply_rtx() -> void:
	var on: bool = settings.rtx and surprise_store.has_played()
	_rtx_button.text = RTX_ON_TEXT if on else RTX_OFF_TEXT
	_rtx_filter.set_enabled(on)
	($Scene3D as HomeScene3D).set_rtx(on)


func is_rtx_on() -> bool:
	return _rtx_filter.is_enabled()


func _on_replay_surprise_pressed() -> void:
	ReleaseSurprise.rearm(surprise_store)
	_refresh_replay_button()


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
	if _title_drop != null:
		_reframe_title_drop.call_deferred()


func _on_open_lobby_pressed() -> void:
	if ReleaseSurprise.should_start(settings.release_surprise, surprise_store):
		start_release_surprise()
		return
	if ReleaseSurprise.stage == ReleaseSurprise.Stage.THREE_PLAYED and _flyover != null:
		start_fourth_dimension()
		return
	get_tree().change_scene_to_file(RACE_SCENE)


## Plays the fake "Fishy Marble Run 3" reveal on the title instead of opening the lobby.
func start_release_surprise() -> void:
	ReleaseSurprise.begin(surprise_store)
	_refresh_replay_button()
	_open_lobby.disabled = true
	await _show_sequel(true)
	_open_lobby.disabled = false
	_open_lobby.grab_focus()


## The fake 3D round was played: a 4 squishes the 3, a glimpse of a 4D track, and the whole
## thing glitches back to the real home screen.
func start_fourth_dimension() -> void:
	_open_lobby.disabled = true
	_title_drop.drop_four()
	await _title_drop.four_finished
	if not is_inside_tree():
		return
	_tagline.text = FOUR_D_TAGLINE
	_four_d = FourDView.new()
	_four_d.name = "FourD"
	add_child(_four_d)
	move_child(_four_d, _flyover.get_index() + 1)
	var screen: Vector2 = size.max(Vector2.ONE)
	var reveal := ShaderMaterial.new()
	reveal.shader = load(SEQUEL_REVEAL_SHADER)
	reveal.set_shader_parameter("origin", title_number_rect().get_center() / screen)
	reveal.set_shader_parameter("aspect", screen.x / screen.y)
	reveal.set_shader_parameter("rim_color", FOUR_D_RIM)
	_four_d.material = reveal
	await _tween_shader(reveal, "progress", 0.0, 1.0, SEQUEL_REVEAL_SECONDS)
	if not is_inside_tree():
		return
	_four_d.material = null
	_flyover.visible = false
	_flyover.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(FOUR_D_SECONDS).timeout
	if not is_inside_tree():
		return
	var glitch := ColorRect.new()
	glitch.name = "Glitch"
	glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glitch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glitch_material := ShaderMaterial.new()
	glitch_material.shader = load(GLITCH_SHADER)
	glitch.material = glitch_material
	add_child(glitch)
	await _tween_shader(glitch_material, "amount", 0.0, 1.0, GLITCH_IN_SECONDS)
	if not is_inside_tree():
		return
	_end_sequel()
	await _tween_shader(glitch_material, "amount", 1.0, 0.0, GLITCH_OUT_SECONDS)
	if not is_inside_tree():
		return
	glitch.queue_free()
	_open_lobby.disabled = false
	_open_lobby.grab_focus()
	surprise_ended.emit()


## Back to the real "Fishy Marble Run II" home screen, as if nothing happened.
func _end_sequel() -> void:
	ReleaseSurprise.end()
	for node: Control in [_title_drop, _flyover, _four_d]:
		if node != null:
			node.queue_free()
	_title_drop = null
	_flyover = null
	_four_d = null
	_title.visible_characters = -1
	_tagline.text = _tagline_text
	_open_lobby.text = _open_lobby_text
	_refresh_replay_button()
	var backdrop: Control = $Scene3D
	backdrop.visible = true
	backdrop.process_mode = Node.PROCESS_MODE_INHERIT


func _tween_shader(
	material: ShaderMaterial, parameter: String, from: float, to: float, seconds: float
) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(
		func(value: float) -> void: material.set_shader_parameter(parameter, value),
		from,
		to,
		seconds
	)
	await tween.finished


## Turns the title into "FISHY MARBLE RUN 3D" with 3D letters, falling in with
## [param animate], and relabels the menu for the fake sequel.
func _show_sequel(animate: bool) -> void:
	# The menu box may not be laid out yet on the first frame; the letters need the title's place.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	# The label keeps its layout (so nothing shifts) but stops drawing the "II".
	_title.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_title.visible_characters = _title.text.length() - TITLE_NUMBER_LENGTH
	_title_drop = TitleDrop.new()
	_title_drop.name = "TitleDrop"
	add_child(_title_drop)
	var rect: Rect2 = title_number_rect()
	_title_drop.setup(
		rect,
		_title.get_theme_font("font"),
		_title.get_theme_font_size("font_size"),
		_title_color_at(rect.get_center().x),
		animate
	)
	if animate:
		await _title_drop.finished
		if not is_inside_tree():
			return
	_tagline.text = SEQUEL_TAGLINE
	_open_lobby.text = SEQUEL_PLAY_TEXT
	await _show_flyover(animate, rect.get_center())


## Swaps the underwater backdrop for the 3D course flyover of the fake sequel; with
## [param reveal] a ring ripples out from [param from] (screen point) to uncover it.
func _show_flyover(reveal: bool, from: Vector2) -> void:
	if _flyover != null:
		return
	var backdrop: Control = $Scene3D
	_flyover = TrackFlyover.new()
	_flyover.name = "Flyover"
	add_child(_flyover)
	move_child(_flyover, backdrop.get_index() + 1)
	if reveal:
		var material := ShaderMaterial.new()
		material.shader = load(SEQUEL_REVEAL_SHADER)
		var screen: Vector2 = size.max(Vector2.ONE)
		material.set_shader_parameter("origin", from / screen)
		material.set_shader_parameter("aspect", screen.x / screen.y)
		_flyover.material = material
		await _tween_shader(material, "progress", 0.0, 1.0, SEQUEL_REVEAL_SECONDS)
		if not is_inside_tree():
			return
		_flyover.material = null
	backdrop.visible = false
	backdrop.process_mode = Node.PROCESS_MODE_DISABLED


## Screen rectangle of the "II" at the end of the title (its line box).
func title_number_rect() -> Rect2:
	var first: int = _title.text.length() - TITLE_NUMBER_LENGTH
	var rect: Rect2 = _title.get_character_bounds(first)
	for i: int in range(first + 1, _title.text.length()):
		rect = rect.merge(_title.get_character_bounds(i))
	rect.position += _title.get_global_rect().position
	return rect


## The title's gradient color at screen x [param x] (mirrors title_gradient.gdshader).
func _title_color_at(x: float) -> Color:
	var t: float = smoothstep(0.28, 0.72, x / maxf(size.x, 1.0))
	return TITLE_LEFT_COLOR.lerp(TITLE_RIGHT_COLOR, t)


func _reframe_title_drop() -> void:
	# Queued by a resize; the letters may be gone by now.
	if _title_drop == null:
		return
	_title_drop.frame(title_number_rect())


## Pulses the aquarium button so new streamers notice it.
func _start_aquarium_blink() -> void:
	_aquarium_blink = create_tween().set_loops()
	_aquarium_blink.set_trans(Tween.TRANS_SINE)
	_aquarium_blink.tween_property(
		_aquarium, "modulate:a", AQUARIUM_BLINK_ALPHA, AQUARIUM_BLINK_SECONDS
	)
	_aquarium_blink.tween_property(_aquarium, "modulate:a", 1.0, AQUARIUM_BLINK_SECONDS)


func is_aquarium_blinking() -> bool:
	return _aquarium_blink != null and _aquarium_blink.is_valid()


func _stop_aquarium_blink() -> void:
	if _aquarium_blink != null:
		_aquarium_blink.kill()
		_aquarium_blink = null
	_aquarium.modulate.a = 1.0


func _on_aquarium_pressed() -> void:
	_stop_aquarium_blink()
	aquarium_store.set_visited(true)
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
