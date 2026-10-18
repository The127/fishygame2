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
## Streamer started a tournament: one map id (or TrackCatalog.RANDOM_ID) per round, in order.
signal tournament_requested(maps: PackedStringArray)

const VOLUME_ROWS: Dictionary = {
	AudioSettings.BUS_MASTER: "Master",
	AudioSettings.BUS_MUSIC: "Music",
	AudioSettings.BUS_AMBIENCE: "Ambience",
	AudioSettings.BUS_SFX: "Effects",
}

## Seconds the drawer takes to slide, and to fade the tab.
const SLIDE_SECONDS: float = 0.25
const FADE_SECONDS: float = 0.15
## Opening takes a little longer: it overshoots and settles.
const OPEN_SECONDS: float = 0.35
## Share of the overshoot past fully open that is shown.
const OVERSHOOT_SCALE: float = 0.35
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
@onready var _status: Label = %Status
@onready var _map_picker: OptionButton = %MapPicker
@onready var _rounds_picker: OptionButton = %RoundsPicker
@onready var _round_maps: VBoxContainer = %TournamentMaps
@onready var _power_status: Label = %PowerStatus
@onready
var _power_buttons: Array[PowerButton] = [%PowerButtons/Rod, %PowerButtons/Net, %PowerButtons/Blast]
@onready var _confirm: Control = %LeaveConfirm
@onready var _auto: SwitchButton = %Auto
@onready var _mute: SwitchButton = %Mute
@onready var _volume_rows: Dictionary = {
	AudioSettings.BUS_MASTER: %MasterRow,
	AudioSettings.BUS_MUSIC: %MusicRow,
	AudioSettings.BUS_AMBIENCE: %AmbienceRow,
	AudioSettings.BUS_SFX: %SfxRow,
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
	(%Open as Button).pressed.connect(open_lobby_pressed.emit)
	(%Start as Button).pressed.connect(start_pressed.emit)
	(%Stop as Button).pressed.connect(stop_pressed.emit)
	(%Home as Button).pressed.connect(home_pressed.emit)
	for i: int in _power_buttons.size():
		_power_buttons[i].pressed.connect(power_pressed.emit.bind(i))
	(%SkipReplay as Button).pressed.connect(skip_replay_pressed.emit)
	(%Leave as Button).pressed.connect(_on_leave_pressed)
	(%Stay as Button).pressed.connect(cancel_leave)
	(%DebugButtons as Control).visible = DebugMode.is_enabled()
	(%DebugButtons/AddOne as Button).pressed.connect(add_debug_players_pressed.emit.bind(1))
	(%DebugButtons/AddFive as Button).pressed.connect(add_debug_players_pressed.emit.bind(5))
	(%DebugButtons/Duck as Button).pressed.connect(debug_duck_pressed.emit)
	(%DebugButtons/Meow as Button).pressed.connect(debug_meow_pressed.emit)
	_fill_map_options(_map_picker)
	_map_picker.item_selected.connect(_on_map_picked)
	for count: int in Tournament.ROUND_CHOICES:
		_rounds_picker.add_item("%d" % count)
		_rounds_picker.set_item_metadata(_rounds_picker.item_count - 1, count)
	_rounds_picker.item_selected.connect(_on_rounds_picked)
	_on_rounds_picked(0)
	(%StartTournament as Button).pressed.connect(_on_start_tournament_pressed)
	(%TournamentToggle as Button).pressed.connect(toggle_tournament)
	_auto.toggled.connect(auto_mode_toggled.emit)
	_mute.toggled.connect(_on_mute_toggled)
	for bus: String in _volume_rows:
		_slider(bus).value_changed.connect(_on_volume_slider_changed.bind(bus))
		_show_volume(bus)


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
	# Opening overshoots a little and settles; closing dips first, then snaps away.
	_slide_tween = create_tween().set_trans(Tween.TRANS_BACK)
	_slide_tween.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if open:
		_panel.visible = true
	var seconds: float = OPEN_SECONDS if open else SLIDE_SECONDS
	_slide_tween.tween_method(_set_slide, _slide, 1.0 if open else 0.0, seconds)
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
	(%SkipReplay as Control).visible = shown


func set_status(text: String) -> void:
	_status.text = text


## Highlights the armed power (a [enum StreamerPowers.Kind]), or none for -1.
func set_armed_power(kind: int) -> void:
	for i: int in _power_buttons.size():
		_power_buttons[i].set_pressed_no_signal(i == kind)
		_power_buttons[i].armed_changed()


## Fills the power buttons' cooldown bars. [param total] is the cooldown length, [param left]
## what remains; 0 left means ready. All powers share one cooldown.
func set_power_cooldown(left: float, total: float, quiet: bool = false) -> void:
	var fraction: float = 1.0 if left <= 0.0 or total <= 0.0 else 1.0 - left / total
	_cooldown_fraction = fraction
	_update_tab_bar()
	for button: PowerButton in _power_buttons:
		button.set_cooldown_progress(fraction, quiet)


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
	_auto.show_state(enabled)


## Shows the current audio choices without emitting any signal. Volumes are linear 0..1 per bus.
func set_audio_state(volumes: Dictionary, muted: bool) -> void:
	_mute.show_state(muted)
	for bus: String in _volume_rows:
		_slider(bus).set_value_no_signal(float(volumes.get(bus, 1.0)))
		_show_volume(bus)
	_dim_volumes(muted)


func _apply_style() -> void:
	_panel.add_theme_stylebox_override("panel", _drawer_box())
	UiStyle.style_button(_tab, 16)
	UiStyle.style_label(_status, 20, 700, UiStyle.CYAN)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for card: PanelContainer in [%RaceCard, %PowersCard, %TournamentCard, %SoundCard]:
		card.add_theme_stylebox_override("panel", _card_box())
		var heading: Label = card.find_child("Heading", true, false) as Label
		UiStyle.style_label(heading, 15, 800, UiStyle.CYAN, 3)
		heading.add_theme_constant_override("outline_size", 0)
	for label: Label in [
		%MapLabel,
		%AutoLabel,
		%TournamentLabel,
		%MuteLabel,
		%MasterRow/Label,
		%MusicRow/Label,
		%AmbienceRow/Label,
		%SfxRow/Label,
	]:
		_style_text(label, 19, 600, UiStyle.TEXT)
	for label: Label in [%AutoHint, %Keys, %Hint]:
		_style_text(label, 15, 500, UiStyle.MUTED)
	_style_text(_power_status, 16, 500, UiStyle.MUTED)
	_power_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for row: Control in _volume_rows.values():
		_style_text(row.get_node("Value") as Label, 16, 600, UiStyle.MUTED)
	var version: Label = %Version
	_style_text(version, 13, 600, UiStyle.MUTED)
	version.modulate.a = 0.6
	version.text = BuildInfo.label()
	var question: Label = %Question
	_style_text(question, 18, 600, UiStyle.TEXT)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for button: Button in [
		%Open,
		%Stop,
		%Home,
		%SkipReplay,
		%Leave,
		%Stay,
		%DebugButtons/AddOne,
		%DebugButtons/AddFive,
		%DebugButtons/Duck,
		%DebugButtons/Meow,
		%StartTournament,
	]:
		UiStyle.style_button(button, 17)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiStyle.style_button(%TournamentToggle as Button, 14)
	_style_primary(%Start as Button)
	for picker: OptionButton in [_map_picker, _rounds_picker]:
		_style_picker(picker)
	for power: PowerButton in _power_buttons:
		power.apply_style()
		power.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Solid, so a lobby list or a track behind the open drawer never shows through its text.
static func _drawer_box() -> StyleBoxFlat:
	var box: StyleBoxFlat = UiStyle.panel_box()
	box.bg_color = Color(UiStyle.PANEL_BG, 0.97)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 14.0
	return box


## Section card, as on the settings screen.
static func _card_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiStyle.CYAN, 0.05)
	box.set_corner_radius_all(10)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	return box


## Plain text on the drawer's own background needs no outline.
static func _style_text(label: Label, size: int, weight: int, color: Color) -> void:
	UiStyle.style_label(label, size, weight, color)
	label.add_theme_constant_override("outline_size", 0)


## Filled cyan: the one button the streamer presses most.
static func _style_primary(button: Button) -> void:
	UiStyle.style_button(button, 22)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var ink := Color(0.01, 0.05, 0.1)
	for state: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"
	]:
		button.add_theme_color_override(state, ink)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = UiStyle.button_box(state != "normal")
		box.bg_color = UiStyle.CYAN_LIGHT if state == "hover" else UiStyle.CYAN
		box.border_color = box.bg_color
		box.content_margin_top = 10.0
		box.content_margin_bottom = 10.0
		button.add_theme_stylebox_override(state, box)


## Input-box look of the settings screen, with a dark popup menu in the drawer's font.
func _style_picker(picker: OptionButton) -> void:
	# Sized by the picked name, so a long map name cannot widen the drawer.
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	picker.add_theme_font_override("font", UiStyle.font(600))
	picker.add_theme_font_size_override("font_size", 19)
	picker.add_theme_color_override("font_color", UiStyle.TEXT)
	for state: String in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		picker.add_theme_color_override(state, Color.WHITE)
	var looks: Dictionary[String, float] = {
		"normal": 0.3, "hover": 0.9, "pressed": 0.9, "focus": 0.3
	}
	for state: String in looks:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(UiStyle.CYAN, 0.08 * (looks[state] + 0.1))
		box.set_border_width_all(1)
		box.border_color = Color(UiStyle.CYAN, looks[state])
		box.set_corner_radius_all(6)
		box.content_margin_left = 12.0
		box.content_margin_right = 12.0
		box.content_margin_top = 6.0
		box.content_margin_bottom = 6.0
		picker.add_theme_stylebox_override(state, box)
	_style_picker_popup(picker)


## Dark panel and the drawer's font for the popup menu of a picker.
func _style_picker_popup(picker: OptionButton) -> void:
	var popup: PopupMenu = picker.get_popup()
	popup.add_theme_font_override("font", UiStyle.font(600))
	popup.add_theme_font_size_override("font_size", 19)
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
	_show_volume(bus)
	volume_changed.emit(bus, value)


func _slider(bus: String) -> HSlider:
	return (_volume_rows[bus] as Control).get_node("Slider") as HSlider


## Writes a slider's level next to it, in percent.
func _show_volume(bus: String) -> void:
	var value: Label = (_volume_rows[bus] as Control).get_node("Value") as Label
	value.text = "%d%%" % roundi(_slider(bus).value * 100.0)


## Muted sound keeps its levels; the rows fade to show they are not heard.
func _dim_volumes(muted: bool) -> void:
	for row: Control in _volume_rows.values():
		row.modulate.a = 0.4 if muted else 1.0


func _on_mute_toggled(muted: bool) -> void:
	_dim_volumes(muted)
	mute_toggled.emit(muted)


func _on_map_picked(index: int) -> void:
	map_selected.emit(String(_map_picker.get_item_metadata(index)))


## "Random" first, then every map, each with its id (or TrackCatalog.RANDOM_ID) as metadata.
func _fill_map_options(picker: OptionButton) -> void:
	picker.add_item("Random")
	picker.set_item_metadata(0, TrackCatalog.RANDOM_ID)
	for id: String in TrackCatalog.ids():
		picker.add_item(TrackCatalog.get_name_of(id))
		picker.set_item_metadata(picker.item_count - 1, id)


## One map picker per round. Pickers that stay keep their choice.
func _on_rounds_picked(index: int) -> void:
	var count: int = int(_rounds_picker.get_item_metadata(index))
	var pickers: Array[Node] = _round_maps.get_children()
	for i: int in range(count, pickers.size()):
		_round_maps.remove_child(pickers[i])
		pickers[i].queue_free()
	for i: int in range(pickers.size(), count):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = "Round %d" % (i + 1)
		label.custom_minimum_size.x = 90.0
		_style_text(label, 17, 600, UiStyle.MUTED)
		row.add_child(label)
		var picker := OptionButton.new()
		picker.focus_mode = Control.FOCUS_NONE
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fill_map_options(picker)
		_style_picker(picker)
		row.add_child(picker)
		_round_maps.add_child(row)


## The picked map of every round, in order.
func tournament_maps() -> PackedStringArray:
	var maps: PackedStringArray = []
	for row: Node in _round_maps.get_children():
		var picker: OptionButton = row.get_child(1) as OptionButton
		maps.append(String(picker.get_item_metadata(picker.selected)))
	return maps


## Picks the round count and the map of each round, as the streamer would.
func set_tournament(maps: PackedStringArray) -> void:
	var index: int = Tournament.ROUND_CHOICES.find(maps.size())
	if index < 0:
		return
	_rounds_picker.select(index)
	_on_rounds_picked(index)
	for i: int in maps.size():
		var picker: OptionButton = _round_maps.get_child(i).get_child(1) as OptionButton
		for item: int in picker.item_count:
			if String(picker.get_item_metadata(item)) == maps[i]:
				picker.select(item)


## Shows or hides the tournament setup. It starts hidden to keep the drawer short.
func toggle_tournament() -> void:
	var shown: bool = not _round_maps.visible
	for node: Control in [%TournamentRow, _round_maps, %StartTournament]:
		node.visible = shown
	(%TournamentToggle as Button).text = "Hide" if shown else "Set up"


func is_tournament_shown() -> bool:
	return _round_maps.visible


func _on_start_tournament_pressed() -> void:
	tournament_requested.emit(tournament_maps())


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
	var top: float = lerpf(-height - 8.0, OPEN_TOP, slide_travel(amount))
	_panel.modulate.a = slide_alpha(amount)
	_panel.offset_top = top
	_panel.offset_bottom = top + height


## How far along its path the drawer is for a slide [param amount]; the overshoot past fully
## open is damped so the bounce stays a few pixels.
static func slide_travel(amount: float) -> float:
	return amount if amount <= 1.0 else 1.0 + (amount - 1.0) * OVERSHOOT_SCALE


## The drawer's contents fade in over the first part of the slide and out over the last.
static func slide_alpha(amount: float) -> float:
	return smoothstep(0.0, 0.6, amount)


## Plays the burst of the power [param kind] firing on its button.
func play_power_activate(kind: int) -> void:
	for button: PowerButton in _power_buttons:
		if button.kind == kind:
			button.play_activate()


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
