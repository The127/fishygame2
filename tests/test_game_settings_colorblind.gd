extends GutTest
## The colorblind setting: default, persistence and reset.

const PATH: String = "user://test_settings_colorblind.cfg"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_colorblind_is_off_by_default_and_survives_save_and_load() -> void:
	assert_false(GameSettings.new().colorblind)
	var settings := GameSettings.new(PATH)
	settings.colorblind = true
	assert_true(settings.save())
	var loaded := GameSettings.new(PATH)
	loaded.load_settings()
	assert_true(loaded.colorblind)


func test_colorblind_ignores_a_value_of_the_wrong_type_and_resets() -> void:
	_write("[game]\ncolorblind=3\n")
	var settings := GameSettings.new(PATH)
	settings.load_settings()
	assert_false(settings.colorblind)
	settings.colorblind = true
	settings.reset_to_defaults()
	assert_false(settings.colorblind)
