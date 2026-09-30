extends GutTest
## The random-events switch in GameSettings.

const PATH: String = "user://test_settings_events.cfg"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_random_events_are_off_by_default() -> void:
	assert_false(GameSettings.new().random_events)


func test_random_events_survive_a_save_and_load() -> void:
	var settings := GameSettings.new(PATH)
	settings.random_events = true
	assert_true(settings.save())
	var loaded := GameSettings.new(PATH)
	loaded.load_settings()
	assert_true(loaded.random_events)


func test_malformed_value_keeps_the_default() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string('[game]\nrandom_events="yes"\n')
	file.close()
	var settings := GameSettings.new(PATH)
	settings.load_settings()
	assert_false(settings.random_events)


func test_reset_turns_random_events_off() -> void:
	var settings := GameSettings.new()
	settings.random_events = true
	settings.reset_to_defaults()
	assert_false(settings.random_events)


func test_wheel_stretches_a_short_countdown_only_when_events_are_on() -> void:
	var settings := GameSettings.new()
	settings.countdown_seconds = 3
	assert_eq(settings.effective_countdown(), 3)
	settings.random_events = true
	assert_eq(settings.effective_countdown(), RaceEvent.MIN_COUNTDOWN)
	settings.countdown_seconds = 20
	assert_eq(settings.effective_countdown(), 20)
