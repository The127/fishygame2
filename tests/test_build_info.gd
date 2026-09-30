extends GutTest
## The build tag: semver plus commit and time for stamped builds, "dev" otherwise.


func test_stamped_build_shows_commit_and_time() -> void:
	assert_eq(
		BuildInfo.compose("0.9.0", "a1b2c3d", "2026-09-30 16:40 UTC"),
		"v0.9.0 · a1b2c3d · 2026-09-30 16:40 UTC"
	)


func test_unstamped_build_reads_dev() -> void:
	assert_eq(BuildInfo.compose("0.9.0", "", ""), "v0.9.0 · dev")


func test_label_uses_the_project_version() -> void:
	assert_true(BuildInfo.label().begins_with("v%s" % BuildInfo.version()))
	assert_true(BuildInfo.version().split(".").size() == 3, "semver has three parts")


func test_control_panel_and_home_show_the_tag() -> void:
	var panel: ControlPanel = (
		(load("res://scenes/ui/control_panel.tscn") as PackedScene).instantiate() as ControlPanel
	)
	add_child_autofree(panel)
	assert_eq((panel.get_node("Panel/Box/Version") as Label).text, BuildInfo.label())
	var home: HomeScreen = (
		(load("res://scenes/ui/home_screen.tscn") as PackedScene).instantiate() as HomeScreen
	)
	add_child_autofree(home)
	assert_eq((home.get_node("Version") as Label).text, BuildInfo.label())
