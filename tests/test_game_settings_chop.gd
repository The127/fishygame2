extends GutTest
## The Sushi Bar chop limit in GameSettings.


func test_the_chop_limit_is_a_share_of_the_field_by_default_and_survives_a_save() -> void:
	assert_eq(GameSettings.new().chop_limit, GameSettings.CHOP_SHARE)
	assert_eq(GameSettings.new().chop_cap(), SushiChef.SHARE_LIMIT)
	var path: String = "user://test_chop_settings.cfg"
	var settings := GameSettings.new(path)
	settings.chop_limit = GameSettings.CHOP_UNLIMITED
	assert_true(settings.save())
	var loaded := GameSettings.new(path)
	loaded.load_settings()
	assert_eq(loaded.chop_limit, GameSettings.CHOP_UNLIMITED)
	assert_eq(loaded.chop_cap(), SushiChef.UNLIMITED)
	loaded.reset_to_defaults()
	assert_eq(loaded.chop_limit, GameSettings.CHOP_SHARE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_number_of_fish_is_handed_on_as_is() -> void:
	var settings := GameSettings.new()
	assert_true(settings.set_number("chop_limit", 4))
	assert_eq(settings.chop_cap(), 4)
	settings.set_number("chop_limit", 99)
	assert_eq(settings.chop_limit, GameSettings.CHOP_UNLIMITED, "clamped to its range")


func test_the_settings_screen_names_every_value() -> void:
	var names: Array = SettingsScreen.CHOICES["chop_limit"]
	assert_eq(names.size(), GameSettings.CHOP_UNLIMITED - GameSettings.CHOP_SHARE + 1)
	assert_eq(names[GameSettings.CHOP_UNLIMITED], "Unlimited")
