extends GutTest
## The RTX setting: default, persistence, reset, and the filter it switches.

const PATH: String = "user://test_settings_rtx.cfg"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_rtx_is_off_by_default_and_survives_save_load_and_reset() -> void:
	assert_false(GameSettings.new().rtx)
	var settings := GameSettings.new(PATH)
	settings.rtx = true
	assert_true(settings.save())
	var loaded := GameSettings.new(PATH)
	loaded.load_settings()
	assert_true(loaded.rtx)
	loaded.reset_to_defaults()
	assert_false(loaded.rtx)


func test_the_rtx_unlock_show_is_on_by_default_and_survives_save_load_and_reset() -> void:
	assert_true(GameSettings.new().rtx_intro)
	var settings := GameSettings.new(PATH)
	settings.rtx_intro = false
	assert_true(settings.save())
	var loaded := GameSettings.new(PATH)
	loaded.load_settings()
	assert_false(loaded.rtx_intro)
	loaded.reset_to_defaults()
	assert_true(loaded.rtx_intro)


func test_rtx_ignores_a_value_of_the_wrong_type() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string('[game]\nrtx="yes"\n')
	file.close()
	var settings := GameSettings.new(PATH)
	settings.load_settings()
	assert_false(settings.rtx)


func test_filter_is_hidden_and_idle_until_enabled() -> void:
	var filter: RtxFilter = autofree(RtxFilter.new())
	add_child(filter)
	assert_false(filter.is_enabled())
	assert_false(filter.is_processing())
	filter.set_enabled(true)
	assert_true(filter.visible)
	assert_true(filter.is_processing())
	filter.set_enabled(false)
	assert_false(filter.visible)
	assert_false(filter.is_processing())
