class_name ControlPanel
extends CanvasLayer
## Every streamer control in one place, as a drawer that slides in from the top edge.
## The faint "Controls" tab or F1 opens and closes it. A drawer opened with the tab closes
## itself after a few seconds without the mouse over it; one opened with F1 stays.

signal open_lobby_pressed
signal start_pressed
signal stop_pressed
signal add_debug_players_pressed(count: int)
## Emits a map id, or TrackCatalog.RANDOM_ID for a random map.
signal map_selected(choice: String)
## Emits a bus name (see AudioSettings.BUSES) and a linear volume 0..1.
signal volume_changed(bus: String, value: float)
## Streamer switched auto mode (unattended rounds) on or off.
signal auto_mode_toggled(enabled: bool)
signal mute_toggled(muted: bool)
## Streamer wants to leave for the home screen (button or Esc).
signal home_pressed
## Streamer confirmed leaving after [method ask_leave].
signal leave_confirmed

const VOLUME_ROWS: Dictionary = {
	AudioSettings.BUS_MASTER: "Master",
	AudioSettings.BUS_MUSIC: "Music",
	AudioSettings.BUS_SFX: "Effects",
}

## Seconds the drawer takes to slide, and to fade the tab.
const SLIDE_SECONDS: float = 0.25
const FADE_SECONDS: float = 0.15
## Seconds without the mouse over the tab or drawer before a tab-opened drawer closes.
const AUTO_HIDE_SECONDS: float = 4.0
const TAB_IDLE_ALPHA: float = 0.2
## Top of the open drawer, just below the tab.
const OPEN_TOP: float = 64.0

var _open: bool = true
var _slide: float = 1.0
## The current drawer closes on its own when the mouse stays away.
var _auto_hide: bool = false
var _idle_seconds: float = 0.0
var _tab_hovered: bool = false
var _hidden_before_ask: bool = false
var _slide_tween: Tween
var _fade_tween: Tween

@onready var _panel: PanelContainer = $Panel
@onready var _tab: Button = $Handle
@onready var _status: Label = $Panel/Box/Status
@onready var _map_picker: OptionButton = $Panel/Box/MapRow/MapPicker
@onready var _confirm: Control = $Panel/Box/LeaveConfirm
@onready var _auto: CheckBox = $Panel/Box/Auto
@onready var _mute: CheckBox = $Panel/Box/Mute
@onready var _volume_sliders: Dictionary = {
	AudioSettings.BUS_MASTER: $Panel/Box/MasterRow/Slider,
	AudioSettings.BUS_MUSIC: $Panel/Box/MusicRow/Slider,
	AudioSettings.BUS_SFX: $Panel/Box/SfxRow/Slider,
}


func _ready() -> void:
	_apply_style()
	_tab.modulate.a = TAB_IDLE_ALPHA
	_tab.pressed.connect(_on_tab_pressed)
	_tab.mouse_entered.connect(_set_tab_hovered.bind(true))
	_tab.mouse_exited.connect(_set_tab_hovered.bind(false))
	($Panel/Box/Buttons/Open as Button).pressed.connect(open_lobby_pressed.emit)
	($Panel/Box/Buttons/Start as Button).pressed.connect(start_pressed.emit)
	($Panel/Box/Buttons/Stop as Button).pressed.connect(stop_pressed.emit)
	($Panel/Box/Home as Button).pressed.connect(home_pressed.emit)
	($Panel/Box/LeaveConfirm/Answers/Leave as Button).pressed.connect(_on_leave_pressed)
	($Panel/Box/LeaveConfirm/Answers/Stay as Button).pressed.connect(cancel_leave)
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
	_auto.toggled.connect(auto_mode_toggled.emit)
	_mute.toggled.connect(mute_toggled.emit)
	for bus: String in _volume_sliders:
		(_volume_sliders[bus] as HSlider).value_changed.connect(volume_changed.emit.bind(bus))


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F1:
		toggle_drawer()
	elif key.keycode == KEY_SPACE:
		start_pressed.emit()
	elif key.keycode == KEY_ESCAPE:
		if _confirm.visible:
			cancel_leave()
		else:
			home_pressed.emit()


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


func set_status(text: String) -> void:
	_status.text = text


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
	UiStyle.style_label($Panel/Box/LeaveConfirm/Question as Label, 20, 600, UiStyle.TEXT)
	($Panel/Box/LeaveConfirm/Question as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for box: CheckBox in [_auto, _mute]:
		box.add_theme_font_override("font", UiStyle.font(600))
		box.add_theme_font_size_override("font_size", 22)
		box.add_theme_color_override("font_color", UiStyle.TEXT)
	for row: String in ["MasterRow", "MusicRow", "SfxRow"]:
		UiStyle.style_label(get_node("Panel/Box/%s/Label" % row) as Label, 22, 600, UiStyle.MUTED)
	for button: Button in [
		$Panel/Box/Buttons/Open,
		$Panel/Box/Buttons/Start,
		$Panel/Box/Buttons/Stop,
		$Panel/Box/Home,
		$Panel/Box/LeaveConfirm/Answers/Leave,
		$Panel/Box/LeaveConfirm/Answers/Stay,
		$Panel/Box/DebugButtons/AddOne,
		$Panel/Box/DebugButtons/AddFive,
		_map_picker,
	]:
		UiStyle.style_button(button, 20)
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
