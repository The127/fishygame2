class_name ControlPanel
extends CanvasLayer
## Every streamer control in one place, as a drawer that slides in from the top edge.
## The faint "Controls" tab or F1 opens and closes it. A drawer opened with the tab closes
## itself after a few seconds without the mouse over it; one opened with F1 stays.

signal open_lobby_pressed
signal start_pressed
signal stop_pressed
signal add_debug_players_pressed(count: int)
signal debug_duck_pressed
signal debug_meow_pressed
## Emits a map id, or TrackCatalog.RANDOM_ID for a random map.
signal map_selected(choice: String)
## Emits a bus name (see AudioSettings.BUSES) and a linear volume 0..1.
signal volume_changed(bus: String, value: float)
## Streamer switched auto mode (unattended rounds) on or off.
signal auto_mode_toggled(enabled: bool)
signal mute_toggled(muted: bool)
## Streamer picked a streamer power (button or hotkey 1 to 3): a [enum StreamerPowers.Kind].
signal power_pressed(kind: int)
## Streamer wants to skip the finish replay (button or Space).
signal skip_replay_pressed
## Streamer wants to leave for the home screen (button).
signal home_pressed
## Streamer pressed Esc: step back one level (podium to an empty map). Never goes home.
signal back_pressed
## Streamer confirmed leaving after [method ask_leave].
signal leave_confirmed

const VOLUME_ROWS: Dictionary = {
	AudioSettings.BUS_MASTER: "Master",
	AudioSettings.BUS_MUSIC: "Music",
	AudioSettings.BUS_AMBIENCE: "Ambience",
	AudioSettings.BUS_SFX: "Effects",
}

## Seconds the drawer takes to slide, and to fade the tab.
const SLIDE_SECONDS: float = 0.25
const FADE_SECONDS: float = 0.15
## Seconds without the mouse over the tab or drawer before a tab-opened drawer closes.
const AUTO_HIDE_SECONDS: float = 4.0
const TAB_IDLE_ALPHA: float = 0.2
## Slim bar under the tab that shows the power cooldown while the drawer is closed.
const TAB_BAR_HEIGHT: float = 4.0
const TAB_BAR_GAP: float = 3.0
const TAB_BAR_COLOR: Color = Color(UiStyle.CYAN, 0.7)
## Top of the open drawer, just below the tab.
const OPEN_TOP: float = 64.0

var _open: bool = true
var _slide: float = 1.0
## The current drawer closes on its own when the mouse stays away.
var _auto_hide: bool = false
var _idle_seconds: float = 0.0
var _tab_hovered: bool = false
var _hidden_before_ask: bool = false
var _cooldown_fraction: float = 1.0
var _slide_tween: Tween
var _fade_tween: Tween

@onready var _panel: PanelContainer = $Panel
@onready var _tab: Button = $Handle
@onready var _tab_bar: ColorRect = $HandleCooldown
@onready var _status: Label = $Panel/Box/Status
@onready var _map_picker: OptionButton = $Panel/Box/MapRow/MapPicker
@onready var _power_status: Label = $Panel/Box/PowerStatus
@onready var _power_buttons: Array[PowerButton] = [
	$Panel/Box/PowerButtons/Rod, $Panel/Box/PowerButtons/Net, $Panel/Box/PowerButtons/Blast
]
@onready var _confirm: Control = $Panel/Box/LeaveConfirm
@onready var _auto: CheckBox = $Panel/Box/Auto
@onready var _mute: CheckBox = $Panel/Box/Mute
@onready var _volume_sliders: Dictionary = {
	AudioSettings.BUS_MASTER: $Panel/Box/MasterRow/Slider,
	AudioSettings.BUS_MUSIC: $Panel/Box/MusicRow/Slider,
	AudioSettings.BUS_AMBIENCE: $Panel/Box/AmbienceRow/Slider,
	AudioSettings.BUS_SFX: $Panel/Box/SfxRow/Slider,
}


func _ready() -> void:
	_apply_style()
	_tab.modulate.a = TAB_IDLE_ALPHA
	_tab_bar.color = TAB_BAR_COLOR
	# The tab grows to fit its text after the first layout; its offsets follow.
	_tab.item_rect_changed.connect(_update_tab_bar)
	_update_tab_bar()
	_tab.pressed.connect(_on_tab_pressed)
	_tab.mouse_entered.connect(_set_tab_hovered.bind(true))
	_tab.mouse_exited.connect(_set_tab_hovered.bind(false))
	($Panel/Box/Buttons/Open as Button).pressed.connect(open_lobby_pressed.emit)
	($Panel/Box/Buttons/Start as Button).pressed.connect(start_pressed.emit)
	($Panel/Box/Buttons/Stop as Button).pressed.connect(stop_pressed.emit)
	($Panel/Box/Home as Button).pressed.connect(home_pressed.emit)
	for i: int in _power_buttons.size():
		_power_buttons[i].pressed.connect(power_pressed.emit.bind(i))
	($Panel/Box/SkipReplay as Button).pressed.connect(skip_replay_pressed.emit)
	($Panel/Box/LeaveConfirm/Answers/Leave as Button).pressed.connect(_on_leave_pressed)
	($Panel/Box/LeaveConfirm/Answers/Stay as Button).pressed.connect(cancel_leave)
	($Panel/Box/DebugButtons as Control).visible = DebugMode.is_enabled()
	($Panel/Box/DebugButtons/AddOne as Button).pressed.connect(
		add_debug_players_pressed.emit.bind(1)
	)
	($Panel/Box/DebugButtons/AddFive as Button).pressed.connect(
		add_debug_players_pressed.emit.bind(5)
	)
	($Panel/Box/DebugButtons/Duck as Button).pressed.connect(debug_duck_pressed.emit)
	($Panel/Box/DebugButtons/Meow as Button).pressed.connect(debug_meow_pressed.emit)
	_map_picker.add_item("Random")
	_map_picker.set_item_metadata(0, TrackCatalog.RANDOM_ID)
	for id: String in TrackCatalog.ids():
		_map_picker.add_item(TrackCatalog.get_name_of(id))
		_map_picker.set_item_metadata(_map_picker.item_count - 1, id)
	_map_picker.item_selected.connect(_on_map_picked)
	_auto.toggled.connect(auto_mode_toggled.emit)
	_mute.toggled.connect(mute_toggled.emit)
	for bus: String in _volume_sliders:
		(_volume_sliders[bus] as HSlider).value_changed.connect(_on_volume_slider_changed.bind(bus))


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F1:
		toggle_drawer()
	elif key.keycode >= KEY_1 and key.keycode < KEY_1 + _power_buttons.size():
		var index: int = key.keycode - KEY_1
		if not _power_buttons[index].is_cooling():
			power_pressed.emit(index)
	elif key.keycode == KEY_SPACE:
		start_pressed.emit()
	elif key.keycode == KEY_ESCAPE:
		if _confirm.visible:
			cancel_leave()
		else:
			back_pressed.emit()


func _process(delta: float) -> void:
	update_auto_hide(delta, _pointer_over_drawer())


func is_open() -> bool:
	return _open


## Slides the drawer in or out. [param auto_hide] lets an open drawer close by itself.
func set_open(open: bool, auto_hide: bool = false) -> void:
	_auto_hide = open and auto_hide
	_idle_seconds = 0.0
	if open == _open:
		return
	_open = open
	if _slide_tween != null:
		_slide_tween.kill()
	_slide_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if open:
		_panel.visible = true
	_slide_tween.tween_method(_set_slide, _slide, 1.0 if open else 0.0, SLIDE_SECONDS)
	if not open:
		_slide_tween.tween_callback(_hide_if_closed)
	_refresh_tab()
	_update_tab_bar()


func toggle_drawer() -> void:
	set_open(not _open)


## Counts time without the mouse over the drawer and closes a tab-opened one when it runs out.
## The leave question and the map picker's menu keep it open.
func update_auto_hide(delta: float, pointer_over: bool) -> void:
	if not _open or not _auto_hide:
		return
	if pointer_over or _confirm.visible or _map_picker.get_popup().visible:
		_idle_seconds = 0.0
		return
	_idle_seconds += delta
	if _idle_seconds >= AUTO_HIDE_SECONDS:
		set_open(false)


## Shows the "leave the round?" question. Reveals the drawer so it can be answered.
func ask_leave() -> void:
	if not _confirm.visible:
		_hidden_before_ask = not _open
	_confirm.visible = true
	set_open(true, _auto_hide)


## Hides the leave question without leaving, and re-hides the drawer if it was closed before.
func cancel_leave() -> void:
	if _confirm.visible and _hidden_before_ask:
		set_open(false)
	_confirm.visible = false


## Shows or hides the skip button. Space skips too, even with the panel hidden.
func show_skip_replay(shown: bool) -> void:
	($Panel/Box/SkipReplay as Control).visible = shown


func set_status(text: String) -> void:
	_status.text = text


## Highlights the armed power (a [enum StreamerPowers.Kind]), or none for -1.
func set_armed_power(kind: int) -> void:
	for i: int in _power_buttons.size():
		_power_buttons[i].set_pressed_no_signal(i == kind)


## Fills the power buttons' cooldown bars. [param total] is the cooldown length, [param left]
## what remains; 0 left means ready. All powers share one cooldown.
func set_power_cooldown(left: float, total: float) -> void:
	var fraction: float = 1.0 if left <= 0.0 or total <= 0.0 else 1.0 - left / total
	_cooldown_fraction = fraction
	_update_tab_bar()
	for button: PowerButton in _power_buttons:
		button.set_cooldown_progress(fraction)


## Slim bar under the tab, filling left to right while the drawer is closed and a power cools down.
## Anchored to the right edge like the tab, so it follows the tab when the window is resized.
func _update_tab_bar() -> void:
	_tab_bar.visible = not _open and _cooldown_fraction < 1.0
	# The tab grows to fit its text, so read its real rect, not its offsets, and express it
	# relative to the right edge the bar is anchored to.
	var rect: Rect2 = _tab.get_rect()
	var edge: float = _tab_bar.get_viewport().get_visible_rect().size.x
	_tab_bar.offset_left = rect.position.x - edge
	_tab_bar.offset_right = _tab_bar.offset_left + rect.size.x * _cooldown_fraction
	_tab_bar.offset_top = rect.end.y + TAB_BAR_GAP
	_tab_bar.offset_bottom = _tab_bar.offset_top + TAB_BAR_HEIGHT


## One line for the streamer under the power buttons. It is not shown to viewers.
func set_power_status(text: String) -> void:
	_power_status.text = text


## Shows the auto mode choice without emitting [signal auto_mode_toggled].
func set_auto_mode(enabled: bool) -> void:
	_auto.set_pressed_no_signal(enabled)


## Shows the current audio choices without emitting any signal. Volumes are linear 0..1 per bus.
func set_audio_state(volumes: Dictionary, muted: bool) -> void:
	_mute.set_pressed_no_signal(muted)
	for bus: String in _volume_sliders:
		(_volume_sliders[bus] as HSlider).set_value_no_signal(float(volumes.get(bus, 1.0)))


func _apply_style() -> void:
	_panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	UiStyle.style_button(_tab, 16)
	UiStyle.style_label(_status, 22, 700, UiStyle.CYAN)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.style_label($Panel/Box/MapRow/MapLabel as Label, 22, 600, UiStyle.MUTED)
	UiStyle.style_label($Panel/Box/Hint as Label, 18, 600, UiStyle.MUTED)
	var version: Label = $Panel/Box/Version
	UiStyle.style_label(version, 14, 600, UiStyle.MUTED)
	version.modulate.a = 0.6
	version.text = BuildInfo.label()
	UiStyle.style_label(_power_status, 18, 600, UiStyle.MUTED)
	_power_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.style_label($Panel/Box/LeaveConfirm/Question as Label, 20, 600, UiStyle.TEXT)
	($Panel/Box/LeaveConfirm/Question as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for box: CheckBox in [_auto, _mute]:
		box.add_theme_font_override("font", UiStyle.font(600))
		box.add_theme_font_size_override("font_size", 22)
		box.add_theme_color_override("font_color", UiStyle.TEXT)
	for row: String in ["MasterRow", "MusicRow", "AmbienceRow", "SfxRow"]:
		UiStyle.style_label(get_node("Panel/Box/%s/Label" % row) as Label, 22, 600, UiStyle.MUTED)
	for button: Button in [
		$Panel/Box/Buttons/Open,
		$Panel/Box/Buttons/Start,
		$Panel/Box/Buttons/Stop,
		$Panel/Box/PowerButtons/Rod,
		$Panel/Box/PowerButtons/Net,
		$Panel/Box/PowerButtons/Blast,
		$Panel/Box/Home,
		$Panel/Box/SkipReplay,
		$Panel/Box/LeaveConfirm/Answers/Leave,
		$Panel/Box/LeaveConfirm/Answers/Stay,
		$Panel/Box/DebugButtons/AddOne,
		$Panel/Box/DebugButtons/AddFive,
		$Panel/Box/DebugButtons/Duck,
		$Panel/Box/DebugButtons/Meow,
		_map_picker,
	]:
		UiStyle.style_button(button, 20)
	for power: PowerButton in _power_buttons:
		power.add_theme_stylebox_override("disabled", UiStyle.disabled_button_box())
	# Popup menu of the map picker: dark panel and the same font.
	var popup: PopupMenu = _map_picker.get_popup()
	popup.add_theme_font_override("font", UiStyle.font(600))
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_stylebox_override("panel", UiStyle.panel_box())
	popup.add_theme_color_override("font_color", UiStyle.TEXT)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_stylebox_override("hover", UiStyle.button_box(true))


## Shows the given choice (a map id or TrackCatalog.RANDOM_ID) without emitting map_selected.
func select_map(choice: String) -> void:
	for i: int in _map_picker.item_count:
		if String(_map_picker.get_item_metadata(i)) == choice:
			_map_picker.select(i)
			return


## A bound argument comes after the signal's own (value, bus), so it cannot go straight to
## [signal volume_changed], which wants the bus first.
func _on_volume_slider_changed(value: float, bus: String) -> void:
	volume_changed.emit(bus, value)


func _on_map_picked(index: int) -> void:
	map_selected.emit(String(_map_picker.get_item_metadata(index)))


func _on_tab_pressed() -> void:
	set_open(not _open, true)


func _set_tab_hovered(hovered: bool) -> void:
	_tab_hovered = hovered
	_refresh_tab()


## The tab is nearly invisible until the mouse is on it, so it barely shows on stream.
func _refresh_tab() -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	var alpha: float = 1.0 if _tab_hovered else TAB_IDLE_ALPHA
	_fade_tween.tween_property(_tab, "modulate:a", alpha, FADE_SECONDS)


## 1 is fully open, 0 fully out of sight above the top edge. The height is measured on every
## step because the panel's content can grow after the first layout.
func _set_slide(amount: float) -> void:
	_slide = amount
	var height: float = maxf(_panel.size.y, _panel.get_combined_minimum_size().y)
	var top: float = lerpf(-height - 8.0, OPEN_TOP, amount)
	_panel.offset_top = top
	_panel.offset_bottom = top + height


func _hide_if_closed() -> void:
	if not _open:
		_panel.visible = false


func _pointer_over_drawer() -> bool:
	# A held button means a slider drag, which may wander off the panel.
	if _open and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	var mouse: Vector2 = _panel.get_viewport().get_mouse_position()
	return (
		_tab.get_global_rect().has_point(mouse)
		or (_open and _panel.get_global_rect().has_point(mouse))
	)


func _on_leave_pressed() -> void:
	cancel_leave()
	leave_confirmed.emit()
