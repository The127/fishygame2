class_name QuakeFault
extends Node2D
## The quakes of Earthquake Fault. Chat spamming "#shake" fills a meter; when enough viewers
## have shaken inside a short window the seafloor quakes: the view shakes, the fish are thrown
## about and one [FaultCrack] splits open. A quake has a cooldown. If chat stays quiet, one
## quake still happens at a time drawn from the race seed, so a race always changes shape.
##
## Which crack opens is a seeded order (the first one the pack has not passed yet), so with no
## chat a seed replays the same race. Time advances only in physics frames. Children: the
## `FaultCrack`s.

## The meter changed. Empty text hides it.
signal meter_changed(text: String)
## The view should shake: `strength` is in pixels.
signal quake_shaken(strength: float)
## A crack let off a cloud of dust and glowing grit.
signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)

enum Phase { CALM, RUMBLE }

## Group of the fault on the map in play: the game calls [method shake] on it for chat presses.
const CHAT_GROUP: StringName = &"chat_shake"
## Seconds a "#shake" counts for.
const WINDOW: float = 8.0
## Most presses of one viewer that count at once, so one person cannot quake the sea alone.
const PER_VIEWER: int = 2
## Presses needed: a share of the joined viewers, within these limits.
const NEED_SHARE: float = 0.4
const NEED_MIN: int = 3
const NEED_MAX: int = 12
## Seconds the ground rumbles before the crack opens.
const RUMBLE_SECONDS: float = 1.4
## Seconds after a quake starts before chat can start the next one.
const COOLDOWN: float = 12.0
## Race seconds of the quake that happens even in a quiet chat.
const AUTO_MIN: float = 6.0
const AUTO_MAX: float = 11.0
## Speed of the shove every fish gets when the crack opens, in pixels per second.
const SCATTER_SIDEWAYS: float = 140.0
const SCATTER_UP: float = 220.0
## Strength of the view shake while the ground rumbles (growing) and when the crack opens.
const RUMBLE_SHAKE_MIN: float = 2.0
const RUMBLE_SHAKE_MAX: float = 9.0
const OPEN_SHAKE: float = 24.0
const SHAKE_INTERVAL: float = 0.1
## Seconds between checks whether the meter text changed on its own (presses leaving the window).
const METER_INTERVAL: float = 0.25
const DUST_COLOR: Color = Color(1.0, 0.62, 0.3)

## Seconds since the race started, advanced by [method tick].
var clock: float = 0.0

var _cracks: Array[FaultCrack] = []
var _armed: bool = false
var _phase: Phase = Phase.CALM
var _phase_time: float = 0.0
var _shake_in: float = 0.0
var _meter_in: float = 0.0
var _last_text: String = ""
var _cooldown: float = 0.0
var _auto_time: float = 0.0
## Cracks in the order the seed wants them opened.
var _order: Array[int] = []
var _target: int = -1
var _quakes: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _press_times: PackedFloat32Array = PackedFloat32Array()
var _press_names: PackedStringArray = PackedStringArray()
var _need: int = NEED_MIN


func _ready() -> void:
	Replayable.join(self)
	add_to_group(CHAT_GROUP)
	for child: Node in get_children():
		if child is FaultCrack:
			_cracks.append(child as FaultCrack)


func _physics_process(delta: float) -> void:
	tick(delta)


## Plans the quakes of a race from `seed_value`, puts every crack back and arms the fault.
func reseed(seed_value: int) -> void:
	stop_gimmick()
	_rng.seed = seed_value
	_auto_time = _rng.randf_range(AUTO_MIN, AUTO_MAX)
	_order.clear()
	for i: int in _cracks.size():
		_order.append(i)
	# A seeded shuffle: the order the cracks are offered in.
	for i: int in range(_order.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: int = _order[i]
		_order[i] = _order[j]
		_order[j] = swap
	_armed = true
	_emit_meter()


## Stops everything and shuts every crack.
func stop_gimmick() -> void:
	var was_armed: bool = _armed
	_armed = false
	clock = 0.0
	_phase = Phase.CALM
	_phase_time = 0.0
	_shake_in = 0.0
	_cooldown = 0.0
	_target = -1
	_quakes = 0
	_press_times = PackedFloat32Array()
	_press_names = PackedStringArray()
	_need = NEED_MIN
	_meter_in = 0.0
	_last_text = ""
	for crack: FaultCrack in _cracks:
		crack.close()
	if was_armed:
		meter_changed.emit("")


func is_armed() -> bool:
	return _armed


func get_cracks() -> Array[FaultCrack]:
	return _cracks


## How many quakes have started this race.
func quake_count() -> int:
	return _quakes


func get_phase() -> Phase:
	return _phase


## Race second of the quake that happens even if chat stays quiet.
func auto_time() -> float:
	return _auto_time


## Presses needed inside the window for `viewers` joined viewers.
static func presses_needed(viewers: int) -> int:
	return clampi(ceili(float(viewers) * NEED_SHARE), NEED_MIN, NEED_MAX)


## A viewer typed "#shake". `viewers` is how many have joined the race. Returns whether it
## started a quake.
func shake(who: String, viewers: int = 0) -> bool:
	if not _armed:
		return false
	_need = presses_needed(viewers)
	_press_times.append(clock)
	_press_names.append(who)
	_prune()
	var started: bool = false
	if _can_quake() and counted_presses() >= _need:
		_start_quake()
		started = true
	_emit_meter()
	return started


## Presses inside the window that count: at most [constant PER_VIEWER] of one viewer.
func counted_presses() -> int:
	_prune()
	var per: Dictionary = {}
	var total: int = 0
	for who: String in _press_names:
		var seen: int = int(per.get(who, 0))
		if seen < PER_VIEWER:
			per[who] = seen + 1
			total += 1
	return total


func tick(delta: float) -> void:
	if not _armed:
		return
	clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _phase == Phase.RUMBLE:
		_tick_rumble(delta)
	elif _quakes == 0 and clock >= _auto_time:
		_start_quake()
		_emit_meter()
	_meter_in -= delta
	if _meter_in <= 0.0:
		_meter_in = METER_INTERVAL
		_emit_meter()
	for crack: FaultCrack in _cracks:
		crack.tick(delta)


## Text of the on-screen meter.
func meter_text() -> String:
	if _phase == Phase.RUMBLE:
		return "EARTHQUAKE!"
	if _quakes >= _cracks.size():
		return "THE SEAFLOOR IS BROKEN"
	if _cooldown > 0.0:
		return "FAULT RECOVERING"
	return "SEISMOGRAPH   #shake   %d / %d" % [mini(counted_presses(), _need), _need]


## Part of the finish replay ([Replayable]). The cracks record themselves.
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([clock, 1.0 if _armed else 0.0])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	clock = Replayable.mix(from, to, weight, 0)
	_armed = Replayable.step(from, to, weight, 1) > 0.5


func _can_quake() -> bool:
	return _phase == Phase.CALM and _cooldown <= 0.0 and _quakes < _cracks.size()


func _prune() -> void:
	while not _press_times.is_empty() and clock - _press_times[0] > WINDOW:
		_press_times.remove_at(0)
		_press_names.remove_at(0)


## Picks the crack to open: the first in the seeded order that the pack has not passed yet, else
## the first one still shut.
func _pick_crack() -> int:
	var lead: float = _lead_y()
	var fallback: int = -1
	for index: int in _order:
		if _cracks[index].is_open():
			continue
		if fallback < 0:
			fallback = index
		if _cracks[index].center().y > lead:
			return index
	return fallback


## World y of the fish furthest down the map, or -infinity when there are none.
func _lead_y() -> float:
	var lead: float = -INF
	for marble: Marble in _marbles():
		lead = maxf(lead, marble.global_position.y)
	return lead


func _marbles() -> Array[Marble]:
	var found: Array[Marble] = []
	for node: Node in get_tree().root.find_children("*", "Marble", true, false):
		found.append(node as Marble)
	return found


func _start_quake() -> void:
	var index: int = _pick_crack()
	if index < 0:
		return
	_target = index
	_quakes += 1
	_phase = Phase.RUMBLE
	_phase_time = 0.0
	_shake_in = 0.0
	_cooldown = COOLDOWN
	_press_times = PackedFloat32Array()
	_press_names = PackedStringArray()


func _tick_rumble(delta: float) -> void:
	_phase_time += delta
	var progress: float = clampf(_phase_time / RUMBLE_SECONDS, 0.0, 1.0)
	_cracks[_target].set_alert(progress)
	_shake_in -= delta
	if _shake_in <= 0.0:
		_shake_in = SHAKE_INTERVAL
		quake_shaken.emit(lerpf(RUMBLE_SHAKE_MIN, RUMBLE_SHAKE_MAX, progress))
	if _phase_time >= RUMBLE_SECONDS:
		_open_target()


## The ground gives way: the crack opens, the view jolts and every fish is thrown about.
func _open_target() -> void:
	var crack: FaultCrack = _cracks[_target]
	crack.set_alert(0.0)
	crack.open()
	_phase = Phase.CALM
	_phase_time = 0.0
	_target = -1
	quake_shaken.emit(OPEN_SHAKE)
	for marble: Marble in _marbles():
		marble.sleeping = false
		var shove: Vector2 = Vector2(
			_rng.randf_range(-SCATTER_SIDEWAYS, SCATTER_SIDEWAYS),
			-_rng.randf_range(SCATTER_UP * 0.3, SCATTER_UP)
		)
		marble.apply_central_impulse(shove * marble.mass)
	burst_played.emit(crack.center(), DUST_COLOR, 24, 160.0, Vector2(0.0, 220.0))
	_emit_meter()


func _emit_meter() -> void:
	var text: String = meter_text()
	if text != _last_text:
		_last_text = text
		meter_changed.emit(text)
