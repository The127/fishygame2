class_name RaceDebug
extends Node2D
## Headless: godot --headless --fixed-fps 60 res://scenes/debug/race_debug.tscn -- --autorun --seed=7 --map=pachinko --count=20 --hazards=3
## --hazards is the hazard frequency (0 turns hazard events off). --limit is the race time limit in
## seconds (default 0, none): fish still racing then are DNF, which does not fail an autorun.
## --eddies=<seconds> makes the cut fish of a round race send out an eddy that often (default 2, 0 for none), standing in for chat.
## --event=<id> runs the race under a RaceEvent (low_gravity, double_hazards, lights_out, bouncy, thanos_snap).
## --shake has made-up viewers spam "#shake" the whole race, for the quakes of a map with a fault.

## Seconds between the "#shake" presses of --shake, and the viewers taking turns.
const SHAKE_EVERY: float = 0.4
const SHAKE_VIEWERS: int = 12

@export var seed_value: int = 1
@export var marble_count: int = 10
@export var map_id: String = "zigzag"
@export var hazard_frequency: int = 3
@export var time_limit: float = 0.0
@export var event_id: String = RaceEvent.NOTHING

var _autorun: bool = false
var _shake: bool = false
var _shake_in: float = 0.0
var _shake_count: int = 0
var _track: Track
var _hazard_events: PackedStringArray = []
var _treasures_found: int = 0
var _treasures_total: int = 0
var _stranded: int = 0
var _dissolved: int = 0
var _cut: int = 0
var _eddies: int = 0
var _eddy_every: float = 2.0
var _eddy_clock: float = 0.0
var _eddy_rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _race: Race = $Race


func _ready() -> void:
	_race.marble_finished.connect(_on_marble_finished)
	_race.fish_snapped.connect(_on_fish_snapped)
	_race.fish_stranded.connect(_on_fish_stranded)
	_race.fish_dissolved.connect(_on_fish_dissolved)
	_race.round_cut.connect(_on_round_cut)
	_race.eddy_dropped.connect(_on_eddy_dropped)
	_race.race_finished.connect(_on_race_finished)
	_race.treasure_collected.connect(_on_treasure_collected)
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--autorun":
			_autorun = true
		elif arg == "--shake":
			_shake = true
		elif arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
		elif arg.begins_with("--count="):
			marble_count = maxi(1, int(arg.substr(8)))
		elif arg.begins_with("--map="):
			map_id = arg.substr(6)
		elif arg.begins_with("--limit="):
			time_limit = maxf(0.0, float(arg.substr(8)))
		elif arg.begins_with("--event="):
			event_id = arg.substr(8)
		elif arg.begins_with("--eddies="):
			_eddy_every = maxf(0.0, float(arg.substr(9)))
		elif arg.begins_with("--hazards="):
			hazard_frequency = clampi(int(arg.substr(10)), 0, 5)
	if event_id != RaceEvent.NOTHING and not RaceEvent.is_event(event_id):
		push_error(
			"Unknown event '%s' (known: %s)" % [event_id, ", ".join(RaceEvent.EVENTS.keys())]
		)
		get_tree().quit(2)
		return
	if not TrackCatalog.has_map(map_id):
		push_error("Unknown map '%s' (known: %s)" % [map_id, ", ".join(TrackCatalog.ids())])
		get_tree().quit(2)
		return
	_track = TrackCatalog.instantiate(map_id)
	add_child(_track)
	move_child(_track, 0)
	_track.hazard_started.connect(_on_hazard_started)
	_track.fish_eaten.connect(_on_fish_eaten)
	if _autorun:
		_start_race()
	else:
		print("Press Space to start a race (seed %d)." % seed_value)


func _physics_process(delta: float) -> void:
	_send_eddies(delta)
	_spam_shake(delta)


func _spam_shake(delta: float) -> void:
	if not _shake:
		return
	_shake_in -= delta
	if _shake_in <= 0.0:
		_shake_in = SHAKE_EVERY
		_shake_count += 1
		get_tree().call_group(
			QuakeFault.CHAT_GROUP,
			"shake",
			"viewer%d" % (_shake_count % SHAKE_VIEWERS),
			SHAKE_VIEWERS
		)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		_start_race()
		if not _autorun:
			seed_value += 1


func _start_race() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	print(
		(
			"Race start: map %s, seed %d, %d marbles, hazards %d, event '%s'"
			% [map_id, seed_value, marble_count, hazard_frequency, event_id]
		)
	)
	_hazard_events.clear()
	_stranded = 0
	_dissolved = 0
	_cut = 0
	_eddies = 0
	_eddy_clock = 0.0
	_eddy_rng.seed = seed_value
	_race.time_limit = time_limit
	_treasures_found = 0
	_race.start(_track, marble_count, rng, hazard_frequency, event_id)
	_treasures_total = _race.treasures_left()


func _send_eddies(delta: float) -> void:
	# Cut fish stand in for chat: a random one of them sends out an eddy every so often.
	if _eddy_every <= 0.0 or not _race.running:
		return
	_eddy_clock += delta
	if _eddy_clock < _eddy_every:
		return
	_eddy_clock = 0.0
	var cut: Array[int] = []
	for marble: Marble in _race.get_marbles():
		if marble.eliminated:
			cut.append(marble.id)
	if not cut.is_empty():
		_race.drop_eddy(cut[_eddy_rng.randi_range(0, cut.size() - 1)])


func _on_round_cut(round_number: int, ids: Array[int]) -> void:
	_cut += ids.size()
	print("  cut: marbles %s after lap %d at t=%.2fs" % [ids, round_number, _race.elapsed])


func _on_eddy_dropped(id: int) -> void:
	_eddies += 1
	print("  eddy: marble %d at t=%.2fs" % [id, _race.elapsed])


func _on_hazard_started(kind: String) -> void:
	_hazard_events.append("%s@%.1f" % [kind, _race.elapsed])
	print("  hazard: %s at t=%.2fs" % [kind, _race.elapsed])


func _on_fish_snapped(ids: Array[int]) -> void:
	print("  snap: marbles %s at t=%.2fs" % [ids, _race.elapsed])


func _on_fish_stranded(id: int) -> void:
	_stranded += 1
	print("  stranded: marble %d at t=%.2fs" % [id, _race.elapsed])


func _on_fish_dissolved(id: int) -> void:
	_dissolved += 1
	var at: Vector2 = _race.get_marbles()[id].global_position
	print("  dissolved: marble %d at t=%.2fs (%.0f, %.0f)" % [id, _race.elapsed, at.x, at.y])


func _on_fish_eaten(marble: Marble) -> void:
	print("  eaten: marble %d at t=%.2fs" % [marble.id, _race.elapsed])


func _on_treasure_collected(id: int, kind: int, value: int) -> void:
	_treasures_found += 1
	print(
		(
			"  treasure: marble %d took a %s (+%d)"
			% [id, Treasure.name_of(kind as Treasure.Kind), value]
		)
	)


func _on_marble_finished(id: int, place: int) -> void:
	print("  place %d: marble %d (t=%.2fs)" % [place, id, _race.elapsed])


func _on_race_finished(results: Array[Dictionary]) -> void:
	var order: PackedStringArray = []
	for r: Dictionary in results:
		order.append("%d%s" % [r["id"], "" if r["finished"] else "*"])
	print("Finish order: %s (* = timeout ranked) total %.2fs" % [", ".join(order), _race.elapsed])
	var positions: Dictionary = _race.get_position_map()
	for r: Dictionary in results:
		if not r["finished"] and positions.has(r["id"]):
			var at: Vector2 = positions[r["id"]]
			print("  unfinished: marble %d at (%.0f, %.0f)" % [r["id"], at.x, at.y])
	if _autorun:
		var unfinished: int = 0
		for r: Dictionary in results:
			var id: int = int(r["id"])
			if (
				not r["finished"]
				and not _race.is_snapped(id)
				and not _race.is_stranded(id)
				and not _race.is_dissolved(id)
				and not _race.is_eliminated(id)
			):
				unfinished += 1
		var starts: String = ""
		if _track.get_start_count() > 1:
			var by_marble: PackedStringArray = []
			for i: int in marble_count:
				by_marble.append(str(_track.get_start_of(i)))
			starts = " starts=%s" % ",".join(by_marble)
		print(
			(
				"RESULT map=%s seed=%d time=%.2f unfinished=%d stranded=%d dissolved=%d cut=%d eddies=%d hazards=%d treasures=%d/%d order=%s%s"
				% [
					map_id,
					seed_value,
					_race.elapsed,
					unfinished,
					_stranded,
					_dissolved,
					_cut,
					_eddies,
					_hazard_events.size(),
					_treasures_found,
					_treasures_total,
					",".join(order),
					starts
				]
			)
		)
		get_tree().quit(1 if unfinished > 0 and time_limit <= 0.0 else 0)
