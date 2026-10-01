extends SceneTree
## Script and physics cost of one map with 20 fish, headless (no rendering, so only the GDScript
## and physics side shows):
##   godot --headless --path . --script tools/bench_map.gd -- garden
## Pass "empty" to leave the fish out (isolates the map's own cost). Pass "grown" after the map id to grow all the coral of the Coral Garden first. Prints
## the engine's own process and physics milliseconds per frame (the frame itself is padded to
## about 7 ms headless), so compare runs on the same machine.

const FISH: int = 20
const FRAMES: int = 600


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "garden"
	var track: Track = TrackCatalog.instantiate(id)
	root.add_child(track)
	await process_frame
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	track.plan_starts(FISH, rng)
	var scene: PackedScene = load("res://scenes/marble.tscn")
	var fish: int = 0 if args.has("empty") else FISH
	for i: int in fish:
		var marble: Marble = scene.instantiate()
		marble.id = i
		marble.color = Color.from_hsv(float(i) / FISH, 0.8, 1.0)
		marble.global_position = track.get_spawn_position(i)
		root.add_child(marble)
	if args.has("grown"):
		for hazard: Hazard in track.get_hazards():
			if hazard is CoralHazard:
				(hazard as CoralHazard).reseed(1)
				for bed: CoralBed in (hazard as CoralHazard).get_beds():
					bed.grow_now()
	for f: int in 900:
		await process_frame
	var process_ms: float = 0.0
	var physics_ms: float = 0.0
	for f: int in FRAMES:
		await process_frame
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	print(
		(
			"BENCH %s %s: process %.3f ms, physics %.3f ms per frame"
			% [id, " ".join(args.slice(1)), process_ms / FRAMES, physics_ms / FRAMES]
		)
	)
	quit()
