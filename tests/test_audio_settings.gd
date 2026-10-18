extends GutTest
## The music options of AudioSettings (music on/off, theme mode, jingles, crossfade) and how
## the Sound autoload applies them.

const TMP_PATH: String = "user://test_audio_music.cfg"


func before_each() -> void:
	# The Sound autoload's own settings point at the real audio.cfg.
	Sound.settings = AudioSettings.new()


func after_each() -> void:
	DirAccess.remove_absolute(TMP_PATH)
	Sound.settings = AudioSettings.new()
	Sound.reset_settings()
	Sound.set_music_theme(Sound.HOME_THEME)


func test_music_option_defaults() -> void:
	var settings := AudioSettings.new()
	assert_true(settings.music_enabled)
	assert_eq(settings.music_mode, AudioSettings.MUSIC_PER_MAP)
	assert_true(settings.jingles)
	assert_eq(settings.crossfade, AudioSettings.DEFAULT_CROSSFADE)


func test_music_options_round_trip() -> void:
	var settings := AudioSettings.new(TMP_PATH)
	settings.music_enabled = false
	settings.set_music_mode(AudioSettings.MUSIC_HOME)
	settings.jingles = false
	settings.set_crossfade(4.5)
	assert_true(settings.save())
	var loaded := AudioSettings.new(TMP_PATH)
	loaded.load_settings()
	assert_false(loaded.music_enabled)
	assert_eq(loaded.music_mode, AudioSettings.MUSIC_HOME)
	assert_false(loaded.jingles)
	assert_almost_eq(loaded.crossfade, 4.5, 0.001)


func test_old_file_without_music_options_keeps_their_defaults() -> void:
	var file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	file.store_string("[audio]\nMaster=0.3\nmuted=true\n")
	file.close()
	var loaded := AudioSettings.new(TMP_PATH)
	loaded.load_settings()
	assert_almost_eq(loaded.get_volume(AudioSettings.BUS_MASTER), 0.3, 0.001)
	assert_true(loaded.music_enabled)
	assert_eq(loaded.music_mode, AudioSettings.MUSIC_PER_MAP)
	assert_true(loaded.jingles)
	assert_eq(loaded.crossfade, AudioSettings.DEFAULT_CROSSFADE)


func test_malformed_music_options_keep_their_defaults() -> void:
	var file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	file.store_string('[audio]\nmusic_enabled="no"\nmusic_mode=7\njingles=0\ncrossfade="slow"\n')
	file.close()
	var garbage := AudioSettings.new(TMP_PATH)
	garbage.load_settings()
	assert_true(garbage.music_enabled)
	assert_eq(garbage.music_mode, AudioSettings.MUSIC_PER_MAP)
	assert_true(garbage.jingles)
	assert_eq(garbage.crossfade, AudioSettings.DEFAULT_CROSSFADE)
	file = FileAccess.open(TMP_PATH, FileAccess.WRITE)
	file.store_string("[audio]\nmusic_mode=1.0\ncrossfade=99\n")
	file.close()
	var odd := AudioSettings.new(TMP_PATH)
	odd.load_settings()
	assert_eq(odd.music_mode, AudioSettings.MUSIC_PER_MAP, "a float is not a mode")
	assert_eq(odd.crossfade, AudioSettings.MAX_CROSSFADE, "clamped")


func test_reset_to_defaults_restores_every_choice() -> void:
	var settings := AudioSettings.new()
	settings.set_volume(AudioSettings.BUS_MASTER, 0.1)
	settings.muted = true
	settings.music_enabled = false
	settings.set_music_mode(AudioSettings.MUSIC_HOME)
	settings.jingles = false
	settings.set_crossfade(8.0)
	settings.reset_to_defaults()
	assert_almost_eq(settings.get_volume(AudioSettings.BUS_MASTER), 0.8, 0.001)
	assert_false(settings.muted)
	assert_true(settings.music_enabled)
	assert_eq(settings.music_mode, AudioSettings.MUSIC_PER_MAP)
	assert_true(settings.jingles)
	assert_eq(settings.crossfade, AudioSettings.DEFAULT_CROSSFADE)


func test_music_off_mutes_only_the_music_bus() -> void:
	Sound.set_music_enabled(false)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioSettings.BUS_MUSIC)))
	for bus: String in [
		AudioSettings.BUS_MASTER, AudioSettings.BUS_AMBIENCE, AudioSettings.BUS_SFX
	]:
		assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)), bus)
	Sound.set_music_enabled(true)
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioSettings.BUS_MUSIC)))


func test_home_theme_mode_keeps_the_home_theme_on_maps() -> void:
	Sound.set_music_mode(AudioSettings.MUSIC_HOME)
	Sound.set_music_theme("abyss")
	assert_eq(Sound.get_music_theme(), Sound.HOME_THEME)
	Sound.set_music_mode(AudioSettings.MUSIC_PER_MAP)
	assert_eq(Sound.get_music_theme(), "abyss", "switching back plays the map's theme")


func test_play_win_with_jingles_off_never_crashes() -> void:
	Sound.set_jingles(false)
	for id: String in TrackCatalog.ids():
		Sound.set_music_theme(id)
		Sound.play_win()
	pass_test("played the generic win sound on every map")
