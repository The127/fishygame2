extends GutTest
## GameSettings: the streamer power switch, cooldown and cap.

const PATH: String = "user://test_settings_powers.cfg"


func after_each() -> void:
	var path: String = ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_defaults() -> void:
	var settings := GameSettings.new()
	assert_true(settings.powers_enabled)
	assert_eq(settings.power_cooldown, 8)
	assert_eq(settings.powers_per_race, 6)
	assert_true(settings.reply_powers)


func test_round_trip() -> void:
	var settings := GameSettings.new(PATH)
	settings.powers_enabled = false
	settings.power_cooldown = 30
	settings.powers_per_race = 2
	settings.reply_powers = false
	assert_true(settings.save())
	var loaded := GameSettings.new(PATH)
	loaded.load_settings()
	assert_false(loaded.powers_enabled)
	assert_eq(loaded.power_cooldown, 30)
	assert_eq(loaded.powers_per_race, 2)
	assert_false(loaded.reply_powers)


func test_values_are_clamped() -> void:
	var settings := GameSettings.new()
	settings.set_number("powers_per_race", 0.0)
	assert_eq(settings.powers_per_race, 1)
	settings.set_number("powers_per_race", 999.0)
	assert_eq(settings.powers_per_race, 20)
	settings.set_number("power_cooldown", -5.0)
	assert_eq(settings.power_cooldown, 0)


func test_reset_restores_defaults() -> void:
	var settings := GameSettings.new()
	settings.powers_enabled = false
	settings.power_cooldown = 1
	settings.reset_to_defaults()
	assert_true(settings.powers_enabled)
	assert_eq(settings.power_cooldown, 8)
