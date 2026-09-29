extends GutTest
## First-run flag and step navigation of the onboarding screen.

const PATH: String = "user://test_onboarding.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(PATH)


func after_all() -> void:
	DirAccess.remove_absolute(PATH)


func _make_screen() -> OnboardingScreen:
	var screen := OnboardingScreen.new()
	screen.store = OnboardingStore.new(PATH)
	add_child_autofree(screen)
	return screen


func test_first_run_is_not_done() -> void:
	assert_false(OnboardingStore.new(PATH).is_done())


func test_done_flag_persists() -> void:
	assert_true(OnboardingStore.new(PATH).set_done(true))
	assert_true(OnboardingStore.new(PATH).is_done(), "a new store reads the saved flag")


func test_done_flag_can_be_cleared() -> void:
	var store := OnboardingStore.new(PATH)
	store.set_done(true)
	store.set_done(false)
	assert_false(OnboardingStore.new(PATH).is_done())


func test_corrupt_file_counts_as_not_done() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("not a config [[[")
	file.close()
	assert_false(OnboardingStore.new(PATH).is_done())


func test_steps_and_texts_match() -> void:
	assert_eq(OnboardingScreen.STEP_TITLES.size(), OnboardingScreen.STEP_TEXTS.size())


func test_navigation_stays_in_range() -> void:
	var screen := _make_screen()
	var last: int = OnboardingScreen.STEP_TITLES.size() - 1
	screen.go_back()
	assert_false(screen.is_last_step())
	for i: int in last:
		screen.go_next()
	assert_true(screen.is_last_step())
	assert_eq(screen._next.text, "FINISH")
	screen.go_back()
	assert_false(screen.is_last_step())
	assert_eq(screen._next.text, "NEXT")


func test_redirect_url_falls_back_to_placeholder_outside_web() -> void:
	if OS.has_feature("web"):
		pending("desktop only")
		return
	assert_eq(OnboardingScreen.redirect_url(), OnboardingScreen.REDIRECT_PLACEHOLDER)
