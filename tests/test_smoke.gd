extends GutTest
## Smoke test proving the GUT harness runs and the main scene loads.


func test_main_scene_instantiates() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	assert_not_null(main_scene, "main scene should load")
	var instance: Node = autofree(main_scene.instantiate())
	assert_not_null(instance, "main scene should instantiate")


func test_home_scene_is_main_scene() -> void:
	assert_eq(
		ProjectSettings.get_setting("application/run/main_scene"),
		"res://scenes/ui/home_screen.tscn",
		"home screen should be the starting scene"
	)
	var home_scene: PackedScene = load("res://scenes/ui/home_screen.tscn")
	assert_not_null(home_scene, "home scene should load")
	var instance: Node = autofree(home_scene.instantiate())
	assert_not_null(instance, "home scene should instantiate")
