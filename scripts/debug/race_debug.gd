class_name RaceDebug
extends Node2D
### Headless: godot --headless --fixed-fps 60 res://scenes/debug/race_debug.tscn -- --autorun --seed=7 --map=pachinko --count=20

@export var seed_value: int = 1
@export var marble_count: int = 10
@export var map_id: String = "zigzag"

var _autorun: bool = false
var _track: Track

@onready var _race: Race = $Race


func _ready() -> void:
	_race.marble_finished.connect(_on_marble_finished)
	_race.race_finished.connect(_on_race_finished)
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--autorun":
			_autorun = true
		elif arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
		elif arg.begins_with("--count="):
			marble_count = maxi(1, int(arg.substr(8)))
		elif arg.begins_with("--map="):
			map_id = arg.substr(6)
	if not TrackCatalog.has_map(map_id):
		push_error("Unknown map '%s' (known: %s)" % [map_id, ", ".join(TrackCatalog.ids())])
		get_tree().quit(2)
		return
	_track = TrackCatalog.instantiate(map_id)
	add_child(_track)
	move_child(_track, 0)
	if _autorun:
		_start_race()
	else:
		print("Press Space to start a race (seed %d)." % seed_value)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		_start_race()
		if not _autorun:
			seed_value += 1


func _start_race() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	print("Race start: map %s, seed %d, %d marbles" % [map_id, seed_value, marble_count])
	_race.start(_track, marble_count, rng)


func _on_marble_finished(id: int, place: int) -> void:
	print("  place %d: marble %d (t=%.2fs)" % [place, id, _race.elapsed])


func _on_race_finished(results: Array[Dictionary]) -> void:
	var order: PackedStringArray = []
	for r: Dictionary in results:
		order.append("%d%s" % [r["id"], "" if r["finished"] else "*"])
	print("Finish order: %s (* = timeout ranked) total %.2fs" % [", ".join(order), _race.elapsed])
	if _autorun:
		var unfinished: int = (
			results.filter(func(r: Dictionary) -> bool: return not r["finished"]).size()
		)
		print(
			(
				"RESULT map=%s seed=%d time=%.2f unfinished=%d order=%s"
				% [map_id, seed_value, _race.elapsed, unfinished, ",".join(order)]
			)
		)
		get_tree().quit(1 if unfinished > 0 else 0)
