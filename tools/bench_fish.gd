extends SceneTree
## Script cost of 20 fish, headless: godot --headless --path . --script tools/bench_fish.gd
## Prints milliseconds per frame (fish _process plus the canvas redraw callbacks).

const FISH: int = 400
const FRAMES: int = 600


func _initialize() -> void:
	Engine.max_fps = 0
	var marbles: Array[Marble] = []
	for i: int in FISH:
		var marble: Marble = load("res://scenes/marble.tscn").instantiate()
		marble.id = i
		marble.color = Color.from_hsv(float(i) / FISH, 0.8, 1.0)
		marble.pattern = i % 5
		marble.gravity_scale = 0.0
		marble.position = Vector2(100 + i * 40, 300)
		marble.linear_velocity = Vector2(120, 30 * (i % 3))
		root.add_child(marble)
		marbles.append(marble)
	await process_frame
	await process_frame
	var drop: String = OS.get_environment("DROP")
	for marble: Marble in marbles:
		for part: String in drop.split(","):
			if part == "trail":
				(marble.get("_trail") as CPUParticles2D).set_process(false)
				(marble.get("_trail") as CPUParticles2D).set_physics_process(false)
				(marble.get("_trail") as CPUParticles2D).visible = false
			elif part == "fish":
				(marble.get("_fish") as FishVisual).set_process(false)
			elif part == "fishhide":
				(marble.get("_fish") as FishVisual).visible = false
			elif part == "label":
				(marble.get("_label") as Label).visible = false
	var total: int = 0
	for f: int in FRAMES:
		var t0: int = Time.get_ticks_usec()
		await process_frame
		total += Time.get_ticks_usec() - t0
	print("BENCH_FISH %.3f ms/frame" % (float(total) / 1000.0 / FRAMES))
	quit()
