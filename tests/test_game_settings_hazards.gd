extends GutTest
## The hazard switch and frequency in GameSettings.

const PATH: String = "user://test_settings_hazards.cfg"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_hazard_level_is_zero_when_hazards_are_off() -> void:
	var settings := GameSettings.new()
	settings.hazard_frequency = 4
	assert_eq(settings.hazard_level(), 4)
	settings.hazards_enabled = false
	assert_eq(settings.hazard_level(), 0)


func test_hazard_frequency_is_clamped() -> void:
	var settings := GameSettings.new()
	settings.set_number("hazard_frequency", 0.0)
	assert_eq(settings.hazard_frequency, 1)
	settings.set_number("hazard_frequency", 99.0)
	assert_eq(settings.hazard_frequency, 5)


func test_reset_restores_the_hazard_settings() -> void:
	var settings := GameSettings.new()
	settings.hazards_enabled = false
	settings.hazard_frequency = 1
	settings.reset_to_defaults()
	assert_true(settings.hazards_enabled)
	assert_eq(settings.hazard_frequency, 3)


func test_malformed_hazard_values_keep_the_defaults() -> void:
	_write('[game]\nhazards_enabled="yes"\nhazard_frequency="often"\n')
	var settings := GameSettings.new(PATH)
	settings.load_settings()
	assert_true(settings.hazards_enabled)
	assert_eq(settings.hazard_frequency, 3)
