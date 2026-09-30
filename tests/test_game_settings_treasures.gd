extends GutTest
## The treasures switch in GameSettings.


func test_treasures_are_on_by_default_and_survive_a_save() -> void:
	assert_true(GameSettings.new().treasures_enabled)
	var path: String = "user://test_treasure_settings.cfg"
	var settings := GameSettings.new(path)
	settings.treasures_enabled = false
	assert_true(settings.save())
	var loaded := GameSettings.new(path)
	loaded.load_settings()
	assert_false(loaded.treasures_enabled)
	loaded.reset_to_defaults()
	assert_true(loaded.treasures_enabled)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
