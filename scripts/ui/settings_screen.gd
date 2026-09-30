class_name SettingsScreen
extends Control
## Streamer settings: edits a [GameSettings], saving after every change.

const HOME_SCENE: String = "res://scenes/ui/home_screen.tscn"
const ONBOARDING_SCENE: String = "res://scenes/ui/onboarding_screen.tscn"
const RANDOM_LABEL: String = "Random"
const PANEL_WIDTH: float = 640.0
const PREVIEW_KEY: String = "preview"
## Tab layout: each item is a setting key (or [constant PREVIEW_KEY]).
const TABS: Array[Dictionary] = [
	{
		"title": "Race",
		"items":
		[
			"min_players",
			"max_players",
			"countdown_seconds",
			"default_map",
			"hazards_enabled",
			"hazard_frequency",
			"auto_mode",
			"auto_join_seconds",
		],
	},
	{
		"title": "Betting & Chaos",
		"items":
		[
			"starting_balance",
			"min_bet",
			"max_bet",
			"pick_reward",
			"boost_cost",
			"curse_cost",
			"viewer_cooldown",
			"fish_lockout",
		],
	},
	{
		"title": "Streamer powers",
		"items": ["powers_enabled", "power_cooldown", "powers_per_race", "reply_powers"],
	},
	{"title": "Shop", "items": ["species_price", "color_price"]},
	{
		"title": "Chat",
		"items":
		[
			"chat_replies",
			"reply_joins",
			"reply_bets",
			"reply_chaos",
			"reply_shop",
			"reply_results",
			"cheer_strength",
			"cheer_viewer_cooldown",
			"cheer_fish_cooldown",
			"cheer_max_emotes",
		],
	},
	{"title": "Accessibility", "items": ["colorblind"]},
	{
		"title": "Stream layout",
		"items": ["pad_left", "pad_right", "pad_top", "pad_bottom", "preview"],
	},
]

var settings: GameSettings = null

var _spinners: Dictionary[String, SpinBox] = {}
var _captions: Dictionary[String, String] = {}
var _map_picker: OptionButton
var _auto_mode: CheckBox
var _hazards: CheckBox
var _powers: CheckBox
var _chat_replies: CheckBox
var _reply_toggles: Dictionary[String, CheckBox] = {}
var _colorblind: CheckBox
var _status: Label
var _preview: PaddingPreview


func _ready() -> void:
	if settings == null:
		settings = GameSettings.new(GameSettings.DEFAULT_PATH)
		settings.load_settings()
	_build()
	_refresh()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.012, 0.047, 0.102)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	panel.custom_minimum_size.x = PANEL_WIDTH
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)
	var home := Button.new()
	home.name = "Home"
	home.text = "< HOME"
	home.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	home.pressed.connect(_on_back_pressed)
	UiStyle.style_button(home, 24)
	header.add_child(home)
	var title := Label.new()
	title.text = "SETTINGS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(title, 36, 900, UiStyle.CYAN, 6)
	header.add_child(title)
	# Same width as the Home button so the title stays centred.
	var spacer := Control.new()
	spacer.custom_minimum_size.x = home.get_minimum_size().x
	header.add_child(spacer)
	var controls: Dictionary[String, Control] = _build_controls()
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_override("font_selected", UiStyle.font(700))
	tabs.add_theme_font_override("font_unselected", UiStyle.font(600))
	tabs.add_theme_font_size_override("font_size", 20)
	box.add_child(tabs)
	var placed: Dictionary[String, bool] = {}
	for tab: Dictionary in TABS:
		_add_tab(tabs, String(tab["title"]), tab["items"], controls, placed)
	# Settings no tab lists yet still show up, so a new field is never unreachable.
	var leftover: Array[String] = []
	for key: String in controls:
		if not placed.has(key):
			leftover.append(key)
	if not leftover.is_empty():
		_add_tab(tabs, "More", leftover, controls, placed)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(_status, 18, 600, UiStyle.MUTED)
	box.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var reset := Button.new()
	reset.name = "Reset"
	reset.text = "RESET TO DEFAULTS"
	reset.pressed.connect(reset_pressed)
	UiStyle.style_button(reset, 20)
	buttons.add_child(reset)
	var guide := Button.new()
	guide.name = "SetupGuide"
	guide.text = "SETUP GUIDE"
	guide.pressed.connect(_on_guide_pressed)
	UiStyle.style_button(guide, 20)
	buttons.add_child(guide)
	var back := Button.new()
	back.name = "Back"
	back.text = "BACK"
	back.pressed.connect(_on_back_pressed)
	UiStyle.style_button(back, 20)
	buttons.add_child(back)


## Creates every control, keyed by the setting it edits (plus [constant PREVIEW_KEY]).
func _build_controls() -> Dictionary[String, Control]:
	var controls: Dictionary[String, Control] = {}
	for field: Dictionary in GameSettings.FIELDS:
		var spinner := SpinBox.new()
		spinner.min_value = float(field["min"])
		spinner.max_value = float(field["max"])
		spinner.step = 1.0
		spinner.custom_arrow_step = float(field["step"])
		spinner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spinner.value_changed.connect(_on_number_changed.bind(String(field["key"])))
		_spinners[String(field["key"])] = spinner
		_captions[String(field["key"])] = String(field["label"])
		controls[String(field["key"])] = spinner
	_preview = PaddingPreview.new()
	_preview.custom_minimum_size = Vector2(256.0, 144.0)
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_captions[PREVIEW_KEY] = "Game area"
	controls[PREVIEW_KEY] = _preview
	_map_picker = OptionButton.new()
	_map_picker.add_item(RANDOM_LABEL)
	_map_picker.set_item_metadata(0, GameSettings.RANDOM_MAP)
	for id: String in TrackCatalog.ids():
		_map_picker.add_item(TrackCatalog.get_name_of(id))
		_map_picker.set_item_metadata(_map_picker.item_count - 1, id)
	_map_picker.item_selected.connect(_on_map_picked)
	UiStyle.style_button(_map_picker, 20)
	_captions["default_map"] = "Default map"
	controls["default_map"] = _map_picker
	_hazards = _make_check("On")
	_hazards.toggled.connect(_on_hazards_toggled)
	_captions["hazards_enabled"] = "Map hazards (currents, eels, planks)"
	controls["hazards_enabled"] = _hazards
	_powers = _make_check("On")
	_powers.toggled.connect(_on_powers_toggled)
	_captions["powers_enabled"] = "Streamer powers (rod, net, bubble blast)"
	controls["powers_enabled"] = _powers
	_auto_mode = _make_check("On")
	_auto_mode.toggled.connect(_on_auto_mode_toggled)
	_captions["auto_mode"] = "Auto mode (rounds run on their own)"
	controls["auto_mode"] = _auto_mode
	_chat_replies = _make_check("On")
	_chat_replies.toggled.connect(_on_chat_replies_toggled)
	_captions["chat_replies"] = "Reply in chat"
	controls["chat_replies"] = _chat_replies
	for toggle: Dictionary in GameSettings.CHAT_TOGGLES:
		var key: String = toggle["key"]
		var check := _make_check("On")
		check.toggled.connect(_on_reply_toggled.bind(key))
		_reply_toggles[key] = check
		_captions[key] = String(toggle["label"])
		controls[key] = check
	_colorblind = _make_check("On")
	_colorblind.toggled.connect(_on_colorblind_toggled)
	_captions["colorblind"] = "Colorblind mode (alternate colors and fish markings)"
	controls["colorblind"] = _colorblind
	return controls


func _make_check(text: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.add_theme_font_override("font", UiStyle.font(600))
	check.add_theme_font_size_override("font_size", 22)
	check.add_theme_color_override("font_color", UiStyle.TEXT)
	return check


## Adds a scrollable tab holding the listed controls as caption/control rows.
func _add_tab(
	tabs: TabContainer,
	title: String,
	items: Array,
	controls: Dictionary[String, Control],
	placed: Dictionary[String, bool]
) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	scroll.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	margin.add_child(grid)
	for item: Variant in items:
		var key := String(item)
		if not controls.has(key):
			continue
		placed[key] = true
		var caption := _row_label(_captions[key])
		if key == PREVIEW_KEY:
			caption.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(caption)
		grid.add_child(controls[key])


func _row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.style_label(label, 22, 600, UiStyle.MUTED)
	return label


## Copies the settings into the controls without triggering their change handlers.
func _refresh() -> void:
	for key: String in _spinners:
		var wanted: float = float(settings.get(key))
		# Leave the control alone when it already shows the value, so typing is not interrupted.
		if _spinners[key].value != wanted:
			_spinners[key].set_value_no_signal(wanted)
	for i: int in _map_picker.item_count:
		if String(_map_picker.get_item_metadata(i)) == settings.default_map:
			_map_picker.select(i)
	_hazards.set_pressed_no_signal(settings.hazards_enabled)
	_spinners["hazard_frequency"].editable = settings.hazards_enabled
	_powers.set_pressed_no_signal(settings.powers_enabled)
	_spinners["power_cooldown"].editable = settings.powers_enabled
	_spinners["powers_per_race"].editable = settings.powers_enabled
	_auto_mode.set_pressed_no_signal(settings.auto_mode)
	_chat_replies.set_pressed_no_signal(settings.chat_replies)
	for key: String in _reply_toggles:
		_reply_toggles[key].set_pressed_no_signal(bool(settings.get(key)))
	_colorblind.set_pressed_no_signal(settings.colorblind)
	_preview.set_play_fraction(settings.play_fraction())


func _commit(saved_text: String = "Saved") -> void:
	settings.sanitize()
	_refresh()
	_status.text = saved_text if settings.save() else "Could not save in this browser"


func _on_number_changed(value: float, key: String) -> void:
	settings.set_number(key, value)
	_commit()


func _on_map_picked(index: int) -> void:
	settings.default_map = String(_map_picker.get_item_metadata(index))
	_commit()


func _on_hazards_toggled(pressed: bool) -> void:
	settings.hazards_enabled = pressed
	_commit()


func _on_powers_toggled(pressed: bool) -> void:
	settings.powers_enabled = pressed
	_commit()


func _on_auto_mode_toggled(pressed: bool) -> void:
	settings.auto_mode = pressed
	_commit()


func _on_chat_replies_toggled(pressed: bool) -> void:
	settings.chat_replies = pressed
	_commit()


func _on_reply_toggled(pressed: bool, key: String) -> void:
	settings.set(key, pressed)
	_commit()


func _on_colorblind_toggled(pressed: bool) -> void:
	settings.colorblind = pressed
	_commit()


func reset_pressed() -> void:
	settings.reset_to_defaults()
	_commit("Defaults restored")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)


func _on_guide_pressed() -> void:
	get_tree().change_scene_to_file(ONBOARDING_SCENE)
