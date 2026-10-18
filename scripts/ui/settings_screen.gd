class_name SettingsScreen
extends Control
## Streamer settings: edits a [GameSettings], saving after every change.
##
## A sidebar picks one page at a time; each page groups its settings in titled sections, and
## every row carries a one-line explanation. The search box shows matching rows from all pages.

const HOME_SCENE: String = "res://scenes/ui/home_screen.tscn"
const ONBOARDING_SCENE: String = "res://scenes/ui/onboarding_screen.tscn"
const RANDOM_LABEL: String = "Random"
## Width of the whole panel; it fits a 1280x720 window.
const PANEL_WIDTH: float = 1200.0
const SIDEBAR_WIDTH: float = 250.0
const CONTROL_WIDTH: float = 240.0
const PREVIEW_KEY: String = "preview"
const DANGER_TITLE: String = "Danger area"
const MORE_TITLE: String = "More"
## Control key of the button that arms the release surprise again.
const REPLAY_SURPRISE_KEY: String = "replay_surprise"
## Page layout: each page has titled sections; each item is a setting key, or
## [constant PREVIEW_KEY] / [constant REPLAY_SURPRISE_KEY]. A section "hint" explains it.
const PAGES: Array[Dictionary] = [
	{
		"title": "Race",
		"sections":
		[
			{"title": "Players", "items": ["min_players", "max_players"]},
			{
				"title": "Timing",
				"items": ["countdown_seconds", "race_time_limit", "finish_replay"],
			},
			{
				"title": "Maps",
				"items":
				[
					"default_map",
					"hazards_enabled",
					"hazard_frequency",
					"treasures_enabled",
					"random_events",
				],
			},
			{"title": "Auto mode", "items": ["auto_mode", "auto_join_seconds"]},
		],
	},
	{
		"title": "Points & betting",
		"sections":
		[
			{"title": "New viewers", "items": ["starting_balance"]},
			{"title": "Betting", "items": ["min_bet", "max_bet"]},
			{
				"title": "Prizes",
				"hint": "Points paid to the owners of the fastest fish.",
				"items": ["win_reward", "second_reward", "third_reward", "rival_reward"],
			},
		],
	},
	{
		"title": "Chaos & powers",
		"sections":
		[
			{
				"title": "Boost and curse",
				"items": ["boost_cost", "curse_cost", "viewer_cooldown", "fish_lockout"],
			},
			{
				"title": "Cheering",
				"hint": "A chat message that names a fish and has emotes nudges it forward.",
				"items":
				[
					"cheer_strength",
					"cheer_viewer_cooldown",
					"cheer_fish_cooldown",
					"cheer_max_emotes",
				],
			},
			{
				"title": "Streamer powers",
				"items": ["powers_enabled", "power_cooldown", "powers_per_race"],
			},
		],
	},
	{
		"title": "Shop",
		"sections":
		[
			{
				"title": "Prices",
				"items":
				[
					"species_price",
					"color_price",
					"premium_color_price",
					"hat_price",
					"trail_price",
				],
			},
			{"title": "Gifts", "items": ["welcome_hat"]},
		],
	},
	{
		"title": "Chat",
		"sections":
		[
			{"title": "Replies", "items": ["chat_replies"]},
			{
				"title": "Confirmations",
				"hint": "What the game posts in chat. The overlay shows everything either way.",
				"items":
				[
					"reply_joins",
					"reply_bets",
					"reply_chaos",
					"reply_shop",
					"reply_rivals",
					"reply_catalog",
					"reply_results",
					"reply_powers",
				],
			},
		],
	},
	{
		"title": "Display",
		"sections":
		[
			{
				"title": "Blocked edges",
				"hint": "Keeps screen edges free for your own overlays (webcam, alerts).",
				"items": ["pad_left", "pad_right", "pad_top", "pad_bottom", PREVIEW_KEY],
			},
			{"title": "Accessibility", "items": ["colorblind"]},
			{"title": "Graphics", "items": ["rtx"]},
		],
	},
	{
		"title": "Extras",
		"sections":
		[
			{"title": "Release surprise", "items": ["release_surprise", REPLAY_SURPRISE_KEY]},
		],
	},
]

## Caption, explanation and unit of each row. A setting missing here falls back to its
## [constant GameSettings.FIELDS] or [constant GameSettings.CHAT_TOGGLES] label.
const ROWS: Dictionary[String, Dictionary] = {
	"min_players": {"label": "Minimum players", "hint": "Fish needed before a race can start."},
	"max_players": {"label": "Maximum players", "hint": "The lobby is full at this many fish."},
	"countdown_seconds": {"label": "Countdown", "hint": "Before the start.", "unit": "s"},
	"race_time_limit":
	{"label": "Time limit", "hint": "Fish still racing then are DNF. 0 means none.", "unit": "s"},
	"finish_replay": {"label": "Finish replay", "hint": "Replays the finish before the podium."},
	"default_map": {"label": "Map", "hint": "The map every race uses, or a random one."},
	"hazards_enabled": {"label": "Map hazards", "hint": "Currents, eels and collapsing planks."},
	"hazard_frequency": {"label": "Hazard frequency", "hint": "How often hazards strike."},
	"treasures_enabled": {"label": "Treasures", "hint": "Fish pick them up for points."},
	"random_events":
	{"label": "Random events", "hint": "A wheel before each race, now and then a twist."},
	"auto_mode": {"label": "Auto mode", "hint": "Lobby, race and podium cycle on their own."},
	"auto_join_seconds":
	{"label": "Join window", "hint": "How long the lobby stays open.", "unit": "s"},
	"starting_balance":
	{"label": "Starting points", "hint": "What a viewer has on their first visit.", "unit": "pts"},
	"min_bet": {"label": "Minimum bet", "unit": "pts"},
	"max_bet": {"label": "Maximum bet", "hint": "0 means no limit.", "unit": "pts"},
	"win_reward": {"label": "1st place", "unit": "pts"},
	"second_reward": {"label": "2nd place", "unit": "pts"},
	"third_reward": {"label": "3rd place", "unit": "pts"},
	"rival_reward":
	{
		"label": "Beating your rival",
		"hint": "Bonus for finishing ahead of a #rival.",
		"unit": "pts"
	},
	"boost_cost": {"label": "Boost cost", "hint": "#boost kicks a fish forward.", "unit": "pts"},
	"curse_cost": {"label": "Curse cost", "hint": "#curse knocks a fish back.", "unit": "pts"},
	"viewer_cooldown":
	{"label": "Viewer cooldown", "hint": "Wait between one viewer's effects.", "unit": "s"},
	"fish_lockout":
	{"label": "Fish lockout", "hint": "Wait before a fish can be hit again.", "unit": "s"},
	"cheer_strength": {"label": "Cheer strength", "hint": "0 turns cheering off.", "unit": "%"},
	"cheer_viewer_cooldown":
	{"label": "Viewer cooldown", "hint": "Wait between one viewer's cheers.", "unit": "s"},
	"cheer_fish_cooldown":
	{"label": "Fish cooldown", "hint": "Wait before a fish can be cheered again.", "unit": "s"},
	"cheer_max_emotes":
	{"label": "Emotes counted", "hint": "More emotes in one message add nothing."},
	"powers_enabled":
	{"label": "Streamer powers", "hint": "Your rod, net and bubble blast during a race."},
	"power_cooldown": {"label": "Cooldown", "hint": "Wait between two powers.", "unit": "s"},
	"powers_per_race": {"label": "Uses per race"},
	"species_price": {"label": "Fish species", "unit": "pts"},
	"color_price": {"label": "Fish color", "unit": "pts"},
	"premium_color_price": {"label": "Premium color", "unit": "pts"},
	"hat_price": {"label": "Accessory", "hint": "Hats and other accessories.", "unit": "pts"},
	"trail_price": {"label": "Trail", "unit": "pts"},
	"welcome_hat": {"label": "Welcome hat", "hint": "A free random hat for a first race."},
	"chat_replies":
	{"label": "Reply in chat", "hint": "Off silences everything: errors, #help, #top and below."},
	"pad_left": {"label": "Left", "unit": "%"},
	"pad_right": {"label": "Right", "unit": "%"},
	"pad_top": {"label": "Top", "unit": "%"},
	"pad_bottom": {"label": "Bottom", "unit": "%"},
	PREVIEW_KEY: {"label": "Preview", "hint": "Black is blocked, the outline is the game."},
	"colorblind":
	{"label": "Colorblind mode", "hint": "Alternate fish colors and a marking on each fish."},
	"rtx": {"label": "RTX", "hint": "Ray tracing, allegedly. Bloom, lens flares, light shafts."},
	"release_surprise":
	{"label": "Release surprise", "hint": "A fake sequel announcement, once, on Open Lobby."},
	REPLAY_SURPRISE_KEY: {"label": "Play it again", "hint": "On the next Open Lobby press."},
}

## Yes/no settings outside [constant GameSettings.CHAT_TOGGLES]. A new boolean setting needs a
## key here and a place in [constant PAGES].
const TOGGLES: Array[String] = [
	"hazards_enabled",
	"powers_enabled",
	"treasures_enabled",
	"random_events",
	"auto_mode",
	"chat_replies",
	"colorblind",
	"welcome_hat",
	"release_surprise",
	"rtx",
]

## Number settings picked from named steps instead of typed: the names, from the field's min.
const CHOICES: Dictionary[String, Array] = {
	"finish_replay": ["Off", "Close finishes", "Every race"],
	"hazard_frequency": ["Rare", "Occasional", "Normal", "Frequent", "Constant"],
}

## Rows that are greyed out while the yes/no setting they depend on is off. The chat
## confirmations are added in [method _ready].
const DEPENDENTS: Dictionary[String, Array] = {
	"hazards_enabled": ["hazard_frequency"],
	"powers_enabled": ["power_cooldown", "powers_per_race"],
	"auto_mode": ["auto_join_seconds"],
	"release_surprise": [REPLAY_SURPRISE_KEY],
}

## Page shown when the screen opens again during this session.
static var last_page: int = 0

var settings: GameSettings = null
var surprise_store: ReleaseSurpriseStore = ReleaseSurpriseStore.new()

var _spinners: Dictionary[String, SpinBox] = {}
var _choices: Dictionary[String, OptionButton] = {}
var _toggles: Dictionary[String, SwitchButton] = {}
var _map_picker: OptionButton
var _replay: Button
var _preview: PaddingPreview
var _status: Label
var _search: LineEdit
var _no_match: Label
var _wipe_dialog: ConfirmationDialog
var _reset_dialog: ConfirmationDialog
var _dependents: Dictionary[String, Array] = {}
## Page containers, in sidebar order; the last one is the danger area.
var _pages: Array[Control] = []
var _nav: Array[Button] = []
## Each row: {"node": Control, "text": lower-case search text, "section": Control}.
var _rows: Array[Dictionary] = []
## key -> its row container, for greying out dependents.
var _row_of: Dictionary[String, Control] = {}
var _current_page: int = 0


func _ready() -> void:
	if settings == null:
		settings = GameSettings.new(GameSettings.DEFAULT_PATH)
		settings.load_settings()
	_dependents = DEPENDENTS.duplicate()
	var chat_keys: Array = []
	for toggle: Dictionary in GameSettings.CHAT_TOGGLES:
		chat_keys.append(String(toggle["key"]))
	_dependents["chat_replies"] = chat_keys
	_build()
	_refresh()
	show_page(clampi(last_page, 0, _pages.size() - 1))


## Shows one page (an index into the sidebar) and clears the search.
func show_page(index: int) -> void:
	_current_page = index
	last_page = index
	if _search.text != "":
		_search.text = ""
	_apply_filter()


func page_titles() -> Array[String]:
	var titles: Array[String] = []
	for page: Control in _pages:
		titles.append(String(page.name))
	return titles


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
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	box.add_child(body)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = SIDEBAR_WIDTH
	nav.add_theme_constant_override("separation", 6)
	body.add_child(nav)
	var scroll := ScrollContainer.new()
	scroll.name = "Pages"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Keeps the scrollbar off the controls.
	gutter.add_theme_constant_override("margin_right", 20)
	scroll.add_child(gutter)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	gutter.add_child(content)
	_build_pages(content)
	_no_match = Label.new()
	_no_match.text = "No setting matches that search."
	UiStyle.style_label(_no_match, 22, 600, UiStyle.MUTED)
	content.add_child(_no_match)
	_build_nav(nav)
	_build_dialogs()


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
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
	UiStyle.style_label(title, 36, 900, UiStyle.CYAN, 6)
	header.add_child(title)
	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.style_label(_status, 18, 600, UiStyle.GOOD)
	header.add_child(_status)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "Search settings"
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(320.0, 0.0)
	_search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search.text_changed.connect(_on_search_changed)
	_style_field(_search)
	header.add_child(_search)
	return header


func _build_nav(nav: VBoxContainer) -> void:
	var group := ButtonGroup.new()
	for i: int in _pages.size():
		var button := Button.new()
		button.name = "Nav%d" % i
		button.text = String(_pages[i].name)
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(show_page.bind(i))
		_style_nav_button(button, UiStyle.BAD if i == _pages.size() - 1 else UiStyle.CYAN)
		if i == _pages.size() - 1:
			# Keeps the destructive page apart from the everyday ones.
			var spacer := Control.new()
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			nav.add_child(spacer)
		nav.add_child(button)
		_nav.append(button)
	var guide := Button.new()
	guide.name = "SetupGuide"
	guide.text = "SETUP GUIDE"
	guide.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	guide.pressed.connect(_on_guide_pressed)
	UiStyle.style_button(guide, 18)
	nav.add_child(guide)


func _style_nav_button(button: Button, accent: Color) -> void:
	button.add_theme_font_override("font", UiStyle.font(700))
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override(
		"font_color", UiStyle.MUTED.lerp(accent, 0.25 if accent == UiStyle.CYAN else 0.7)
	)
	for state: String in ["font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(state, UiStyle.TEXT)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	var looks: Dictionary[String, float] = {"normal": 0.0, "hover": 0.08, "focus": 0.08}
	for state: String in looks:
		var box := _nav_box(Color(accent, looks[state]))
		button.add_theme_stylebox_override(state, box)
	var selected := _nav_box(Color(accent, 0.2))
	selected.border_width_left = 4
	selected.border_color = accent
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("hover_pressed", selected)


func _nav_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	box.content_margin_left = 18.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


## Builds every page into `content`, then the danger area. Settings no page lists still get a
## "More" page, so a new field is never unreachable.
func _build_pages(content: VBoxContainer) -> void:
	var controls: Dictionary[String, Control] = _build_controls()
	var placed: Dictionary[String, bool] = {}
	for page: Dictionary in PAGES:
		_add_page(content, String(page["title"]), page["sections"], controls, placed)
	var leftover: Array = []
	for key: String in controls:
		if not placed.has(key):
			leftover.append(key)
	if not leftover.is_empty():
		var sections: Array = [{"title": "Other settings", "items": leftover}]
		_add_page(content, MORE_TITLE, sections, controls, placed)
	var danger: VBoxContainer = _page_box(DANGER_TITLE, UiStyle.BAD)
	content.add_child(danger)
	_pages.append(danger)
	danger.add_child(
		_danger_card(
			"Reset settings",
			"Puts every setting on every page back to its default. Viewer data is kept.",
			"RESET SETTINGS",
			"Reset",
			_on_reset_asked
		)
	)
	danger.add_child(
		_danger_card(
			"Reset save state",
			(
				"Deletes every viewer's points, wins, stats and names, and everything they "
				+ "bought in the shop. Settings and the Twitch login are kept."
			),
			"RESET SAVE STATE",
			"WipeSave",
			_on_wipe_pressed
		)
	)


func _page_box(title: String, accent: Color = UiStyle.CYAN) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 16)
	var heading := Label.new()
	heading.text = title
	UiStyle.style_label(heading, 30, 800, accent)
	page.add_child(heading)
	return page


func _add_page(
	content: VBoxContainer,
	title: String,
	sections: Array,
	controls: Dictionary[String, Control],
	placed: Dictionary[String, bool]
) -> void:
	var page: VBoxContainer = _page_box(title)
	content.add_child(page)
	_pages.append(page)
	for section: Dictionary in sections:
		var card := _card()
		page.add_child(card)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 4)
		card.add_child(rows)
		var heading := Label.new()
		heading.text = String(section["title"]).to_upper()
		UiStyle.style_label(heading, 16, 800, UiStyle.CYAN, 3)
		rows.add_child(heading)
		var section_text: String = ("%s %s" % [title, section["title"]]).to_lower()
		if section.has("hint"):
			var hint := _hint_label(String(section["hint"]))
			rows.add_child(hint)
		for item: Variant in section["items"]:
			var key := String(item)
			if not controls.has(key):
				continue
			placed[key] = true
			var row := _row(key, controls[key])
			rows.add_child(row)
			_row_of[key] = row
			var text: String = "%s %s %s" % [_caption(key), _hint(key), section_text]
			_rows.append({"node": row, "text": text.to_lower(), "section": card})


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiStyle.CYAN, 0.05)
	box.set_corner_radius_all(10)
	box.content_margin_left = 22.0
	box.content_margin_right = 22.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	card.add_theme_stylebox_override("panel", box)
	return card


## One setting: caption and explanation on the left, its control on the right.
func _row(key: String, control: Control) -> Control:
	var indent := MarginContainer.new()
	var dependent: bool = false
	for parent: String in _dependents:
		dependent = dependent or _dependents[parent].has(key)
	indent.add_theme_constant_override("margin_left", 28 if dependent else 0)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 56.0
	row.add_theme_constant_override("separation", 24)
	indent.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var caption := Label.new()
	caption.text = _caption(key)
	UiStyle.style_label(caption, 22, 600, UiStyle.TEXT)
	text.add_child(caption)
	if _hint(key) != "":
		text.add_child(_hint_label(_hint(key)))
	var slot := HBoxContainer.new()
	slot.custom_minimum_size.x = CONTROL_WIDTH
	slot.alignment = BoxContainer.ALIGNMENT_END
	if key == PREVIEW_KEY:
		slot.custom_minimum_size.x = control.custom_minimum_size.x
	row.add_child(slot)
	slot.add_child(control)
	return indent


func _hint_label(text: String) -> Label:
	var hint := Label.new()
	hint.text = text
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.style_label(hint, 17, 500, UiStyle.MUTED)
	hint.add_theme_constant_override("outline_size", 0)
	return hint


func _caption(key: String) -> String:
	if ROWS.has(key) and ROWS[key].has("label"):
		return String(ROWS[key]["label"])
	for toggle: Dictionary in GameSettings.CHAT_TOGGLES:
		if toggle["key"] == key:
			return String(toggle["label"])
	var field: Dictionary = GameSettings.field_of(key)
	return String(field.get("label", key.capitalize()))


func _hint(key: String) -> String:
	return String(ROWS.get(key, {}).get("hint", ""))


func _danger_card(
	title: String, text: String, button_text: String, button_name: String, action: Callable
) -> Control:
	var card := _card()
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	card.add_child(rows)
	var heading := Label.new()
	heading.text = title.to_upper()
	UiStyle.style_label(heading, 16, 800, UiStyle.BAD, 3)
	rows.add_child(heading)
	var info := _hint_label(text + " This cannot be undone.")
	info.add_theme_font_size_override("font_size", 20)
	rows.add_child(info)
	var button := Button.new()
	button.name = button_name
	button.text = button_text
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	UiStyle.style_button(button, 20)
	button.add_theme_color_override("font_color", UiStyle.BAD)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = (button.get_theme_stylebox(state) as StyleBoxFlat).duplicate()
		box.border_color = UiStyle.BAD
		box.shadow_color = Color(UiStyle.BAD, 0.25)
		if state != "normal":
			box.bg_color = Color(UiStyle.BAD, 0.16)
		button.add_theme_stylebox_override(state, box)
	rows.add_child(button)
	return card


func _build_dialogs() -> void:
	_wipe_dialog = ConfirmationDialog.new()
	_wipe_dialog.title = "Reset save state?"
	_wipe_dialog.dialog_text = "All viewer points, wins, stats and shop items will be deleted."
	_wipe_dialog.ok_button_text = "DELETE EVERYTHING"
	_wipe_dialog.cancel_button_text = "CANCEL"
	_wipe_dialog.confirmed.connect(wipe_save_state)
	add_child(_wipe_dialog)
	_reset_dialog = ConfirmationDialog.new()
	_reset_dialog.title = "Reset settings?"
	_reset_dialog.dialog_text = "Every setting goes back to its default."
	_reset_dialog.ok_button_text = "RESET SETTINGS"
	_reset_dialog.cancel_button_text = "CANCEL"
	_reset_dialog.confirmed.connect(reset_pressed)
	add_child(_reset_dialog)


## Creates every control, keyed by the setting it edits (plus [constant PREVIEW_KEY] and
## [constant REPLAY_SURPRISE_KEY]).
func _build_controls() -> Dictionary[String, Control]:
	var controls: Dictionary[String, Control] = {}
	for field: Dictionary in GameSettings.FIELDS:
		var key := String(field["key"])
		if CHOICES.has(key):
			var picker := OptionButton.new()
			for label: Variant in CHOICES[key]:
				picker.add_item(String(label))
			picker.item_selected.connect(_on_choice_picked.bind(key))
			_style_picker(picker)
			_choices[key] = picker
			controls[key] = picker
			continue
		var spinner := SpinBox.new()
		spinner.min_value = float(field["min"])
		spinner.max_value = float(field["max"])
		spinner.step = 1.0
		spinner.custom_arrow_step = float(field["step"])
		spinner.custom_minimum_size.x = CONTROL_WIDTH
		spinner.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		spinner.select_all_on_focus = true
		spinner.suffix = String(ROWS.get(key, {}).get("unit", ""))
		spinner.value_changed.connect(_on_number_changed.bind(key))
		_style_field(spinner.get_line_edit())
		_spinners[key] = spinner
		controls[key] = spinner
	_preview = PaddingPreview.new()
	_preview.custom_minimum_size = Vector2(320.0, 180.0)
	controls[PREVIEW_KEY] = _preview
	_map_picker = OptionButton.new()
	_map_picker.add_item(RANDOM_LABEL)
	_map_picker.set_item_metadata(0, GameSettings.RANDOM_MAP)
	for id: String in TrackCatalog.ids():
		_map_picker.add_item(TrackCatalog.get_name_of(id))
		_map_picker.set_item_metadata(_map_picker.item_count - 1, id)
	_map_picker.item_selected.connect(_on_map_picked)
	_style_picker(_map_picker)
	controls["default_map"] = _map_picker
	_replay = Button.new()
	_replay.name = "ReplaySurprise"
	_replay.text = "PLAY AGAIN"
	_replay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_replay.pressed.connect(replay_surprise)
	UiStyle.style_button(_replay, 18)
	controls[REPLAY_SURPRISE_KEY] = _replay
	var keys: Array[String] = TOGGLES.duplicate()
	for toggle: Dictionary in GameSettings.CHAT_TOGGLES:
		keys.append(String(toggle["key"]))
	for key: String in keys:
		var switch := SwitchButton.new()
		switch.toggled.connect(_on_toggle_toggled.bind(key))
		_toggles[key] = switch
		controls[key] = switch
	return controls


func _style_field(field: LineEdit) -> void:
	field.add_theme_font_override("font", UiStyle.font(600))
	field.add_theme_font_size_override("font_size", 22)
	field.add_theme_color_override("font_color", UiStyle.TEXT)
	field.add_theme_color_override("font_uneditable_color", Color(UiStyle.MUTED, 0.6))
	field.add_theme_color_override("font_placeholder_color", Color(UiStyle.MUTED, 0.8))
	field.add_theme_stylebox_override("normal", _field_box(0.3))
	field.add_theme_stylebox_override("focus", _field_box(0.9, true))
	field.add_theme_stylebox_override("read_only", _field_box(0.15))


## Input box look: `border` is the outline's opacity; `thick` marks focus.
func _field_box(border: float, thick: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiStyle.CYAN, 0.08 * (border + 0.1))
	box.set_border_width_all(2 if thick else 1)
	box.border_color = Color(UiStyle.CYAN, border)
	box.set_corner_radius_all(6)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


func _style_picker(picker: OptionButton) -> void:
	# Sized by the picked name, so a long map name cannot widen the page.
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.custom_minimum_size.x = CONTROL_WIDTH
	picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	picker.add_theme_font_override("font", UiStyle.font(600))
	picker.add_theme_font_size_override("font_size", 22)
	picker.add_theme_color_override("font_color", UiStyle.TEXT)
	for state: String in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		picker.add_theme_color_override(state, Color.WHITE)
	picker.add_theme_color_override("font_disabled_color", Color(UiStyle.MUTED, 0.6))
	var looks: Dictionary[String, float] = {
		"normal": 0.3, "hover": 0.9, "pressed": 0.9, "focus": 0.9, "disabled": 0.15
	}
	for state: String in looks:
		var box := _field_box(looks[state], state == "focus")
		if state == "focus":
			box.bg_color = Color.TRANSPARENT
		picker.add_theme_stylebox_override(state, box)
	var popup: PopupMenu = picker.get_popup()
	popup.add_theme_font_override("font", UiStyle.font(600))
	popup.add_theme_font_size_override("font_size", 20)


## Copies the settings into the controls without triggering their change handlers.
func _refresh() -> void:
	for key: String in _spinners:
		var wanted: float = float(settings.get(key))
		# Leave the control alone when it already shows the value, so typing is not interrupted.
		if _spinners[key].value != wanted:
			_spinners[key].set_value_no_signal(wanted)
	for key: String in _choices:
		var lowest: int = int(GameSettings.field_of(key)["min"])
		_choices[key].select(int(settings.get(key)) - lowest)
	for i: int in _map_picker.item_count:
		if String(_map_picker.get_item_metadata(i)) == settings.default_map:
			_map_picker.select(i)
	for key: String in _toggles:
		_toggles[key].show_state(bool(settings.get(key)))
	for key: String in _dependents:
		var on: bool = bool(settings.get(key))
		for dependent: String in _dependents[key]:
			_set_enabled(dependent, on)
	_preview.set_play_fraction(settings.play_fraction())


func _set_enabled(key: String, on: bool) -> void:
	if _spinners.has(key):
		_spinners[key].editable = on
	if _choices.has(key):
		_choices[key].disabled = not on
	if _toggles.has(key):
		_toggles[key].show_state(_toggles[key].button_pressed, on)
	if key == REPLAY_SURPRISE_KEY:
		_replay.disabled = not on
	if _row_of.has(key):
		_row_of[key].modulate.a = 1.0 if on else 0.45


## Shows the current page, or every row matching the search across all pages.
func _apply_filter() -> void:
	var query: String = _search.text.strip_edges().to_lower()
	var searching: bool = query != ""
	var shown_sections: Dictionary[Control, bool] = {}
	for row: Dictionary in _rows:
		var hit: bool = not searching or String(row["text"]).contains(query)
		(row["node"] as Control).visible = hit
		if hit:
			shown_sections[row["section"] as Control] = true
	var any: bool = false
	for i: int in _pages.size():
		var page: Control = _pages[i]
		var page_has_match: bool = false
		for child: Node in page.get_children():
			if child is PanelContainer and _is_section(child):
				(child as Control).visible = shown_sections.has(child as Control)
				page_has_match = page_has_match or (child as Control).visible
		if searching:
			page.visible = page_has_match
		else:
			page.visible = i == _current_page
		any = any or page.visible
		_nav[i].set_pressed_no_signal(not searching and i == _current_page)
	_no_match.visible = searching and not any
	var scroll: ScrollContainer = _no_match.get_parent().get_parent().get_parent()
	scroll.scroll_vertical = 0


## Whether `card` holds settings rows (the danger area's cards do not and always show).
func _is_section(card: Node) -> bool:
	for row: Dictionary in _rows:
		if row["section"] == card:
			return true
	return false


func _commit(saved_text: String = "Saved") -> void:
	settings.sanitize()
	_refresh()
	var saved: bool = settings.save()
	_status.text = saved_text if saved else "Could not save in this browser"
	_status.add_theme_color_override("font_color", UiStyle.GOOD if saved else UiStyle.BAD)


func _on_number_changed(value: float, key: String) -> void:
	settings.set_number(key, value)
	_commit()


func _on_choice_picked(index: int, key: String) -> void:
	settings.set_number(key, float(index + int(GameSettings.field_of(key)["min"])))
	_commit()


func _on_map_picked(index: int) -> void:
	settings.default_map = String(_map_picker.get_item_metadata(index))
	_commit()


func _on_toggle_toggled(pressed: bool, key: String) -> void:
	settings.set(key, pressed)
	_commit()


func _on_search_changed(_text: String) -> void:
	_apply_filter()


func _on_reset_asked() -> void:
	_reset_dialog.popup_centered()


func reset_pressed() -> void:
	settings.reset_to_defaults()
	_commit("Defaults restored")


## Arms the release surprise again, so it plays on the next Open Lobby press.
func replay_surprise() -> void:
	var saved: bool = ReleaseSurprise.rearm(surprise_store)
	if not settings.release_surprise:
		_status.text = "Turn the release surprise on to see it"
	else:
		_status.text = (
			"Surprise plays on the next Open Lobby" if saved else "Could not save in this browser"
		)


func _on_wipe_pressed() -> void:
	_wipe_dialog.popup_centered()


## Deletes the saved viewer data (points, wins, stats, shop). Settings and Twitch login stay.
func wipe_save_state() -> void:
	PointsStore.erase_saved(PointsStore.DEFAULT_PATH)
	ShopStore.erase_saved(Shop.DEFAULT_PATH)
	_status.text = "Save state deleted"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _search.text != "":
			show_page(_current_page)
		else:
			_on_back_pressed()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)


func _on_guide_pressed() -> void:
	get_tree().change_scene_to_file(ONBOARDING_SCENE)
