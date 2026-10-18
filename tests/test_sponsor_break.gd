extends GutTest
## The mid-race fake ad: when it shows, how long, and that it stays away from the finish.

const PATH: String = "user://test_settings_sponsor.cfg"

var _ad: SponsorBreak


func before_each() -> void:
	_ad = autofree(SponsorBreak.new())
	add_child(_ad)
	_ad.set_seed(7)


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_setting_is_on_by_default_and_survives_save_load_and_reset() -> void:
	assert_true(GameSettings.new().sponsor_break)
	var settings := GameSettings.new(PATH)
	settings.sponsor_break = false
	assert_true(settings.save())
	var loaded := GameSettings.new(PATH)
	loaded.load_settings()
	assert_false(loaded.sponsor_break)
	loaded.reset_to_defaults()
	assert_true(loaded.sponsor_break)


func test_nothing_shows_until_armed() -> void:
	_ad.update(0.1, 0.45)
	assert_false(_ad.is_showing())
	assert_false(_ad.visible)


func test_shows_mid_race_for_about_two_seconds_then_leaves() -> void:
	_ad.arm()
	_ad.update(0.1, 0.2)
	assert_false(_ad.is_showing(), "too early in the race")
	_ad.update(0.1, SponsorBreak.TRIGGER_MAX)
	assert_true(_ad.is_showing())
	assert_true(_ad.visible)
	assert_ne(_ad.get_brand(), "")
	_ad.update(SponsorBreak.HOLD_SECONDS, 0.55)
	assert_true(_ad.is_showing(), "still up after the hold")
	_ad.update(2.0 * SponsorBreak.SLIDE_SECONDS, 0.6)
	assert_false(_ad.is_showing())
	assert_false(_ad.visible)
	_ad.update(0.1, 0.5)
	assert_false(_ad.is_showing(), "only one ad per race")


func test_no_ad_once_the_leader_is_close_to_the_finish() -> void:
	_ad.arm()
	_ad.update(0.1, SponsorBreak.LATEST + 0.01)
	assert_false(_ad.is_showing())
	assert_false(_ad.is_due())


func test_ad_leaves_when_the_leader_nears_the_finish_or_a_fish_finishes() -> void:
	_ad.arm()
	_ad.update(0.1, 0.5)
	assert_true(_ad.is_showing())
	_ad.update(0.1, SponsorBreak.LATEST + 0.01)
	assert_false(_ad.is_showing())
	_ad.arm()
	_ad.update(0.1, 0.5)
	assert_true(_ad.is_showing())
	_ad.cut_short(0, 1)
	assert_false(_ad.visible)


func test_every_ad_runs_once_before_any_repeats() -> void:
	var seen: Dictionary = {}
	for i: int in SponsorBreak.ADS.size():
		_ad.arm()
		_ad.update(0.1, 0.5)
		seen[_ad.get_brand()] = true
		_ad.stop()
	assert_eq(seen.size(), SponsorBreak.ADS.size())
	assert_has(seen, "KELP")


func test_covers_one_half_of_the_screen() -> void:
	var sides: Dictionary = {}
	for i: int in 20:
		_ad.arm()
		_ad.update(0.1, 0.5)
		_ad.update(SponsorBreak.SLIDE_SECONDS, 0.5)
		var half: Control = _ad.get_node("Frame/Half")
		assert_eq(half.anchor_right - half.anchor_left, 0.5)
		assert_almost_eq(half.offset_left, 0.0, 0.01, "fully slid in")
		sides[_ad.is_on_left()] = true
		_ad.stop()
	assert_eq(sides.size(), 2, "both sides come up")


func test_no_race_running_takes_the_ad_down() -> void:
	_ad.arm()
	_ad.update(0.1, 0.5)
	assert_true(_ad.is_showing())
	_ad.update(0.1, -1.0)
	assert_false(_ad.is_showing())
	assert_false(_ad.is_due())


func test_arming_off_shows_nothing() -> void:
	_ad.arm(false)
	_ad.update(0.1, 0.5)
	assert_false(_ad.is_showing())


func test_a_finish_that_stays_on_screen_keeps_its_half_clear() -> void:
	var middle: float = _ad.get_node("Frame").get_global_rect().get_center().x
	for i: int in 10:
		_ad.arm(true, middle + 100.0)
		_ad.update(0.1, 0.5)
		assert_true(_ad.is_on_left(), "finish on the right, ad on the left")
		_ad.stop()
		_ad.arm(true, middle - 100.0)
		_ad.update(0.1, 0.5)
		assert_false(_ad.is_on_left(), "finish on the left, ad on the right")
		_ad.stop()


func test_brand_shrinks_to_fit_a_narrow_half() -> void:
	_ad.set_play_fraction(Rect2(0.3, 0.0, 0.4, 1.0))
	await get_tree().process_frame
	var frame: Control = _ad.get_node("Frame")
	assert_lt(frame.size.x, 1000.0, "the frame shrank to the play area")
	_ad._bag = [
		SponsorBreak.ADS.find_custom(
			func(ad: Dictionary) -> bool: return ad["brand"] == "BARNACLES"
		)
	]
	_ad.arm()
	_ad.update(0.1, 0.5)
	assert_eq(_ad.get_brand(), "BARNACLES")
	var brand: Label = _ad._brand
	var width: float = (
		brand
		. label_settings
		. font
		. get_string_size(brand.text, HORIZONTAL_ALIGNMENT_LEFT, -1, brand.label_settings.font_size)
		. x
	)
	assert_lt(width, frame.size.x * 0.5 - 128.0)
