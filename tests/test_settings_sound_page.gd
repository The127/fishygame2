extends GutTest
## The Sound page of the settings screen: it edits the same AudioSettings as the control
## panel's Sound card, and its rows are searchable.

const PANEL_SCENE: PackedScene = preload("res://scenes/ui/control_panel.tscn")


func before_each() -> void:
	# The page edits the autoload's settings; keep them off the real audio.cfg.
	Sound.settings = AudioSettings.new()


func after_each() -> void:
	Sound.reset_settings()
	Sound.set_music_theme(Sound.HOME_THEME)


func _sound_page() -> SettingsScreen:
	var screen: SettingsScreen = (load(HomeScreen.SETTINGS_SCENE) as PackedScene).instantiate()
	screen.settings = GameSettings.new()
	add_child_autofree(screen)
	screen.show_page(screen.page_titles().find("Sound"))
	return screen


func test_sound_page_shows_the_levels_the_control_panel_set() -> void:
	var panel: ControlPanel = PANEL_SCENE.instantiate()
	add_child_autofree(panel)
	panel.volume_changed.connect(Sound.set_volume)
	panel.mute_toggled.connect(Sound.set_muted)
	(panel.get_node("%MusicRow/Slider") as HSlider).value = 0.3
	(panel.get_node("%Mute") as SwitchButton).button_pressed = true
	var screen: SettingsScreen = _sound_page()
	assert_almost_eq(screen._sound.volume_sliders["volume_music"].value, 0.3, 0.001)
	assert_eq(
		(screen._row_of["volume_music"].find_child("Value", true, false) as Label).text, "30%"
	)
	assert_true(screen._sound.toggles["muted"].button_pressed)
	assert_true(screen._row_of["volume_master"].modulate.a < 1.0, "muted levels are dimmed")


func test_sound_page_levels_reach_the_control_panel() -> void:
	var screen: SettingsScreen = _sound_page()
	assert_true(screen._row_of["volume_sfx"].is_visible_in_tree())
	screen._sound.volume_sliders["volume_sfx"].value = 0.4
	assert_almost_eq(Sound.settings.get_volume(AudioSettings.BUS_SFX), 0.4, 0.001)
	var index: int = AudioServer.get_bus_index(AudioSettings.BUS_SFX)
	assert_almost_eq(AudioServer.get_bus_volume_db(index), linear_to_db(0.4), 0.01)
	var panel: ControlPanel = PANEL_SCENE.instantiate()
	add_child_autofree(panel)
	# How the game fills the panel when a race scene opens.
	panel.set_audio_state(Sound.settings.get_volumes(), Sound.settings.muted)
	assert_almost_eq((panel.get_node("%SfxRow/Slider") as HSlider).value, 0.4, 0.001)


func test_music_switch_greys_out_its_options_and_keeps_effects() -> void:
	var screen: SettingsScreen = _sound_page()
	assert_false(screen._sound.music_mode.disabled)
	screen._sound.toggles["music_enabled"].button_pressed = false
	assert_false(Sound.settings.music_enabled)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioSettings.BUS_MUSIC)))
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioSettings.BUS_SFX)))
	assert_true(screen._sound.music_mode.disabled)
	assert_false(screen._sound.crossfade.editable)
	assert_true(screen._row_of["crossfade"].modulate.a < 1.0)


func test_music_options_reach_the_sound_settings() -> void:
	var screen: SettingsScreen = _sound_page()
	screen._sound.music_mode.item_selected.emit(AudioSettings.MUSIC_HOME)
	assert_eq(Sound.settings.music_mode, AudioSettings.MUSIC_HOME)
	screen._sound.crossfade.value = 5.0
	assert_eq(Sound.settings.crossfade, 5.0)
	screen._sound.toggles["jingles"].button_pressed = false
	assert_false(Sound.settings.jingles)
	screen.reset_pressed()
	assert_eq(Sound.settings.music_mode, AudioSettings.MUSIC_PER_MAP)
	assert_true(Sound.settings.jingles)
	assert_eq(screen._sound.music_mode.selected, AudioSettings.MUSIC_PER_MAP, "the page shows it")
	assert_true(screen._sound.toggles["jingles"].button_pressed)


func test_search_finds_the_sound_rows() -> void:
	var screen: SettingsScreen = _sound_page()
	screen.show_page(0)
	for query: String in ["jingle", "crossfade", "ambience", "mute"]:
		screen._search.text = query
		screen._search.text_changed.emit(query)
		assert_false(screen._no_match.visible, query)
	assert_true(screen._row_of["muted"].is_visible_in_tree())
	assert_false(screen._row_of["min_players"].is_visible_in_tree())
