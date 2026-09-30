extends SceneTree
## Script cost of many fish drawn every frame, headless:
##   godot --headless --path . --script tools/bench_fish.gd
## Prints milliseconds per frame. The headless loop has a floor of about 7 ms per frame, so use
## enough fish to sit well above it and compare runs on the same machine.

const FISH: int = 400
const FRAMES: int = 600


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/marble.tscn")
	for i: int in FISH:
		var marble: Marble = scene.instantiate()
		marble.id = i
		marble.color = Color.from_hsv(float(i) / FISH, 0.8, 1.0)
		marble.pattern = i % 5
		marble.gravity_scale = 0.0
		marble.position = Vector2(100 + i * 4, 300)
		marble.linear_velocity = Vector2(120, 30 * (i % 3))
		root.add_child(marble)
	await process_frame
	await process_frame
	var total: int = 0
	for f: int in FRAMES:
		var t0: int = Time.get_ticks_usec()
		await process_frame
		total += Time.get_ticks_usec() - t0
	print("BENCH_FISH %d fish: %.3f ms/frame" % [FISH, float(total) / 1000.0 / FRAMES])
	quit()
