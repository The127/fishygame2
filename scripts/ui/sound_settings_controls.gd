class_name SoundSettingsControls
extends RefCounted
## The Sound page of [SettingsScreen]. Its controls edit the [AudioSettings] of the Sound
## autoload, the same ones the control panel's Sound card shows, so both always agree.

## Emitted after a change was written; false when the browser refused the save.
signal saved(ok: bool)

const MUTED_KEY: String = "muted"
const MUSIC_ENABLED_KEY: String = "music_enabled"
const MUSIC_MODE_KEY: String = "music_mode"
const JINGLES_KEY: String = "jingles"
const CROSSFADE_KEY: String = "crossfade"
## Volume row key -> the bus its slider sets.
const VOLUME_KEYS: Dictionary[String, String] = {
	"volume_master": AudioSettings.BUS_MASTER,
	"volume_music": AudioSettings.BUS_MUSIC,
	"volume_ambience": AudioSettings.BUS_AMBIENCE,
	"volume_sfx": AudioSettings.BUS_SFX,
}
## Names of [member AudioSettings.music_mode], from [constant AudioSettings.MUSIC_PER_MAP].
const MUSIC_MODES: Array[String] = ["Each map's theme", "Home theme"]
const SLIDER_WIDTH: float = 170.0
## The page, in the layout of [constant SettingsScreen.PAGES].
const PAGE: Dictionary = {
	"title": "Sound",
	"sections":
	[
		{
			"title": "Volume",
			"hint": "The same levels as the Sound card in the control panel.",
			"items": ["volume_master", "volume_music", "volume_ambience", "volume_sfx", MUTED_KEY],
		},
		{
			"title": "Music",
			"items": [MUSIC_ENABLED_KEY, MUSIC_MODE_KEY, CROSSFADE_KEY, JINGLES_KEY],
		},
	],
}
## Caption, explanation and unit of each row, as in [constant SettingsScreen.ROWS].
const ROWS: Dictionary[String, Dictionary] = {
	"volume_master": {"label": "Master", "hint": "Everything the game plays."},
	"volume_music": {"label": "Music", "hint": "The theme of the map or the home screen."},
	"volume_ambience": {"label": "Ambience", "hint": "Each map's background bed."},
	"volume_sfx": {"label": "Effects", "hint": "Joins, countdown, powers and wins."},
	MUTED_KEY: {"label": "Mute", "hint": "Silences everything and keeps the levels."},
	MUSIC_ENABLED_KEY:
	{"label": "Music", "hint": "Off silences the music only. Ambience and effects keep playing."},
	MUSIC_MODE_KEY: {"label": "Theme", "hint": "Which music plays during a race."},
	CROSSFADE_KEY:
	{"label": "Crossfade", "hint": "How long one theme fades into the next.", "unit": "s"},
	JINGLES_KEY:
	{"label": "Map jingles", "hint": "Each map's podium sting. Off plays the generic win sound."},
}
## Rows greyed out while the [AudioSettings] switch they depend on is off.
const DEPENDENTS: Dictionary[String, Array] = {
	MUSIC_ENABLED_KEY: [MUSIC_MODE_KEY, CROSSFADE_KEY],
}

var volume_sliders: Dictionary[String, HSlider] = {}
## Switches keyed by their [AudioSettings] property.
var toggles: Dictionary[String, SwitchButton] = {}
var music_mode: OptionButton
var crossfade: SpinBox

var _volume_values: Dictionary[String, Label] = {}
## key -> its row on the settings screen, for dimming.
var _row_of: Dictionary[String, Control] = {}


## Adds a control for every row of [constant PAGE] to `controls`. The callables style an
## OptionButton and a LineEdit the way the rest of the settings screen looks.
func build(
	controls: Dictionary[String, Control],
	style_picker: Callable,
	style_field: Callable,
	control_width: float
) -> void:
	for key: String in VOLUME_KEYS:
		controls[key] = _volume_control(key)
	for key: String in [MUTED_KEY, MUSIC_ENABLED_KEY, JINGLES_KEY]:
		var switch := SwitchButton.new()
		switch.toggled.connect(_on_toggled.bind(key))
		toggles[key] = switch
		controls[key] = switch
	music_mode = OptionButton.new()
	for label: String in MUSIC_MODES:
		music_mode.add_item(label)
	music_mode.item_selected.connect(_on_music_mode_picked)
	style_picker.call(music_mode)
	controls[MUSIC_MODE_KEY] = music_mode
	crossfade = SpinBox.new()
	crossfade.min_value = 0.0
	crossfade.max_value = AudioSettings.MAX_CROSSFADE
	crossfade.step = 0.5
	crossfade.custom_minimum_size.x = control_width
	crossfade.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crossfade.select_all_on_focus = true
	crossfade.suffix = String(ROWS[CROSSFADE_KEY]["unit"])
	crossfade.value_changed.connect(_on_crossfade_changed)
	style_field.call(crossfade.get_line_edit())
	controls[CROSSFADE_KEY] = crossfade


## Whether the row of `key` sits under a switch (and is indented like other dependents).
static func is_dependent(key: String) -> bool:
	for parent: String in DEPENDENTS:
		if DEPENDENTS[parent].has(key):
			return true
	return false


## Copies the Sound autoload's settings into the controls without emitting anything.
## `row_of` maps row keys to their rows on the screen, for dimming.
func refresh(row_of: Dictionary[String, Control]) -> void:
	_row_of = row_of
	var audio: AudioSettings = Sound.settings
	for key: String in volume_sliders:
		volume_sliders[key].set_value_no_signal(audio.get_volume(VOLUME_KEYS[key]))
		_show_volume(key)
		# Muted sound keeps its levels; the rows fade to show they are not heard.
		var heard: bool = not audio.muted
		if key == "volume_music":
			heard = heard and audio.music_enabled
		_dim(key, heard)
	for key: String in toggles:
		toggles[key].show_state(bool(audio.get(key)))
	music_mode.select(audio.music_mode)
	# Leave the box alone when it already shows the value, so typing is not interrupted.
	if crossfade.value != audio.crossfade:
		crossfade.set_value_no_signal(audio.crossfade)
	var music_on: bool = audio.music_enabled
	music_mode.disabled = not music_on
	crossfade.editable = music_on
	for key: String in DEPENDENTS[MUSIC_ENABLED_KEY]:
		_dim(key, music_on)


## Puts every sound choice back to its default. Returns whether the save worked.
func reset() -> bool:
	Sound.reset_settings()
	refresh(_row_of)
	return Sound.save_now()


func _volume_control(key: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size.x = SLIDER_WIDTH
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.value_changed.connect(_on_volume_changed.bind(key))
	box.add_child(slider)
	var value := Label.new()
	value.name = "Value"
	value.custom_minimum_size.x = 58.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.style_label(value, 20, 600, UiStyle.TEXT)
	box.add_child(value)
	volume_sliders[key] = slider
	_volume_values[key] = value
	return box


func _show_volume(key: String) -> void:
	_volume_values[key].text = "%d%%" % roundi(volume_sliders[key].value * 100.0)


func _dim(key: String, on: bool) -> void:
	if _row_of.has(key):
		_row_of[key].modulate.a = 1.0 if on else 0.45


## Sliders save through the Sound autoload's short delay, as the control panel's do.
func _on_volume_changed(value: float, key: String) -> void:
	Sound.set_volume(VOLUME_KEYS[key], value)
	_show_volume(key)


func _on_toggled(pressed: bool, key: String) -> void:
	match key:
		MUTED_KEY:
			Sound.set_muted(pressed)
		MUSIC_ENABLED_KEY:
			Sound.set_music_enabled(pressed)
		JINGLES_KEY:
			Sound.set_jingles(pressed)
	_commit()


func _on_music_mode_picked(index: int) -> void:
	Sound.set_music_mode(index)
	_commit()


func _on_crossfade_changed(value: float) -> void:
	Sound.set_crossfade(value)
	_commit()


func _commit() -> void:
	refresh(_row_of)
	saved.emit(Sound.save_now())
