extends GutTest
## Audio settings persistence and the bus wiring of the Sound autoload.

const TMP_PATH: String = "user://test_audio.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(TMP_PATH)
	Sound.settings = AudioSettings.new()
	Sound.set_muted(false)
	for bus: String in AudioSettings.BUSES:
		Sound.set_volume(bus, AudioSettings.DEFAULT_VOLUMES[bus])
	Sound.settings.save_path = ""


func test_defaults() -> void:
	var settings := AudioSettings.new()
	assert_false(settings.muted)
	assert_almost_eq(settings.get_volume(AudioSettings.BUS_MUSIC), 0.5, 0.001)


func test_volume_is_clamped_and_unknown_bus_rejected() -> void:
	var settings := AudioSettings.new()
	settings.set_volume(AudioSettings.BUS_SFX, 3.0)
	assert_eq(settings.get_volume(AudioSettings.BUS_SFX), 1.0)
	settings.set_volume(AudioSettings.BUS_SFX, -1.0)
	assert_eq(settings.get_volume(AudioSettings.BUS_SFX), 0.0)
	assert_false(settings.set_volume("Nope", 0.5))


func test_save_and_load_round_trip() -> void:
	var settings := AudioSettings.new(TMP_PATH)
	settings.set_volume(AudioSettings.BUS_MASTER, 0.3)
	settings.set_volume(AudioSettings.BUS_MUSIC, 0.0)
	settings.muted = true
	assert_true(settings.save())
	var loaded := AudioSettings.new(TMP_PATH)
	loaded.load_settings()
	assert_almost_eq(loaded.get_volume(AudioSettings.BUS_MASTER), 0.3, 0.001)
	assert_eq(loaded.get_volume(AudioSettings.BUS_MUSIC), 0.0)
	assert_almost_eq(loaded.get_volume(AudioSettings.BUS_SFX), 0.8, 0.001)
	assert_true(loaded.muted)


func test_missing_or_garbage_file_keeps_defaults() -> void:
	var missing := AudioSettings.new("user://does_not_exist.cfg")
	missing.load_settings()
	assert_almost_eq(missing.get_volume(AudioSettings.BUS_MASTER), 0.8, 0.001)
	var file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	file.store_string('[audio]\nMaster="loud"\nmuted=3\n')
	file.close()
	var garbage := AudioSettings.new(TMP_PATH)
	garbage.load_settings()
	assert_almost_eq(garbage.get_volume(AudioSettings.BUS_MASTER), 0.8, 0.001)
	assert_false(garbage.muted)


func test_buses_exist_and_route_to_master() -> void:
	for bus: String in [AudioSettings.BUS_MUSIC, AudioSettings.BUS_SFX]:
		var index: int = AudioServer.get_bus_index(bus)
		assert_ne(index, -1, "%s bus should exist" % bus)
		assert_eq(AudioServer.get_bus_send(index), AudioSettings.BUS_MASTER)


func test_volume_to_db() -> void:
	assert_eq(Sound.volume_to_db(0.0), Sound.SILENT_DB)
	assert_almost_eq(Sound.volume_to_db(1.0), 0.0, 0.001)
	assert_lt(Sound.volume_to_db(0.5), 0.0)


func test_set_volume_reaches_the_bus() -> void:
	Sound.set_volume(AudioSettings.BUS_MUSIC, 0.5)
	var index: int = AudioServer.get_bus_index(AudioSettings.BUS_MUSIC)
	assert_almost_eq(AudioServer.get_bus_volume_db(index), linear_to_db(0.5), 0.01)


func test_mute_toggles_master_bus() -> void:
	var index: int = AudioServer.get_bus_index(AudioSettings.BUS_MASTER)
	Sound.set_muted(true)
	assert_true(AudioServer.is_bus_mute(index))
	Sound.set_muted(false)
	assert_false(AudioServer.is_bus_mute(index))


func test_changes_are_saved_to_disk() -> void:
	Sound.settings.save_path = TMP_PATH
	Sound.set_volume(AudioSettings.BUS_SFX, 0.25)
	Sound.set_muted(true)
	Sound.save_now()
	var loaded := AudioSettings.new(TMP_PATH)
	loaded.load_settings()
	assert_almost_eq(loaded.get_volume(AudioSettings.BUS_SFX), 0.25, 0.001)
	assert_true(loaded.muted)


func test_every_effect_has_a_stream_and_music_loops() -> void:
	for sfx: int in Sound.SFX_PATHS:
		var stream: AudioStreamWAV = load(Sound.SFX_PATHS[sfx]) as AudioStreamWAV
		assert_not_null(stream, "effect %d should load" % sfx)
	var music: AudioStreamWAV = load(Sound.MUSIC_PATH) as AudioStreamWAV
	assert_not_null(music)
	assert_true(music.get_length() > 10.0, "music should be a long loop")


func test_play_never_crashes_for_any_effect() -> void:
	for sfx: int in Sound.SFX_PATHS:
		Sound.play(sfx)
	pass_test("played every effect")


func test_music_loop_covers_the_whole_clip() -> void:
	var music: AudioStreamWAV = Sound.make_loop(load(Sound.MUSIC_PATH) as AudioStreamWAV)
	assert_eq(music.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(music.loop_begin, 0)
	assert_eq(music.loop_end, roundi(music.get_length() * music.mix_rate))
