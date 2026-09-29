class_name RaceDebug
extends Node2D
## Headless: godot --headless --fixed-fps 60 res://scenes/debug/race_debug.tscn -- --autorun --seed=7

const MARBLE_COUNT: int = 10

@export var seed_value: int = 1

var _autorun: bool = false

@onready var _race: Race = $Race
@onready var _track: Track = $Track


func _ready() -> void:
	_race.marble_finished.connect(_on_marble_finished)
	_race.race_finished.connect(_on_race_finished)
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--autorun":
			_autorun = true
		elif arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
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
	print("Race start: seed %d, %d marbles" % [seed_value, MARBLE_COUNT])
	_race.start(_track, MARBLE_COUNT, rng)


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
				"RESULT seed=%d time=%.2f unfinished=%d order=%s"
				% [seed_value, _race.elapsed, unfinished, ",".join(order)]
			)
		)
		get_tree().quit(1 if unfinished > 0 else 0)
