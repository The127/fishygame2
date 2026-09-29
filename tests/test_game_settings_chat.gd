extends GutTest
## GameSettings: the per-type chat confirmation toggles.

const PATH: String = "user://test_settings_chat.cfg"


func after_each() -> void:
	var path: String = ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_chat_toggles_default_on_and_round_trip() -> void:
	var settings := GameSettings.new(PATH)
	for toggle: Dictionary in GameSettings.CHAT_TOGGLES:
		assert_true(settings.get(toggle["key"]), "%s defaults on" % toggle["key"])
	settings.reply_bets = false
	settings.reply_results = false
	assert_true(settings.save())
	var loaded := GameSettings.new(PATH)
	loaded.load_settings()
	assert_false(loaded.reply_bets)
	assert_false(loaded.reply_results)
	assert_true(loaded.reply_joins)


func test_replies_enabled_needs_master_switch_and_toggle() -> void:
	var settings := GameSettings.new()
	assert_true(settings.replies_enabled("reply_joins"))
	settings.reply_joins = false
	assert_false(settings.replies_enabled("reply_joins"))
	settings.reply_joins = true
	settings.chat_replies = false
	assert_false(settings.replies_enabled("reply_joins"))


func test_reset_restores_chat_toggles() -> void:
	var settings := GameSettings.new()
	settings.reply_shop = false
	settings.reset_to_defaults()
	assert_true(settings.reply_shop)


func test_every_chat_toggle_key_is_a_bool_property() -> void:
	var settings := GameSettings.new()
	for toggle: Dictionary in GameSettings.CHAT_TOGGLES:
		assert_typeof(settings.get(toggle["key"]), TYPE_BOOL, toggle["key"])
