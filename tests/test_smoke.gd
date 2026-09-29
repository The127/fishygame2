extends GutTest
## Smoke test proving the GUT harness runs and the main scene loads.


func test_main_scene_instantiates() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	assert_not_null(main_scene, "main scene should load")
	var instance: Node = autofree(main_scene.instantiate())
	assert_not_null(instance, "main scene should instantiate")
