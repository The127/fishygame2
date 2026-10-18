class_name BoardDice
extends Node2D
## The big die of Board Game. It rolls every few seconds on its own; chat spamming "#roll" fills a
## meter that rolls it sooner. A roll tumbles for a moment and then lands on a face, and
## [signal rolled] tells the board how many squares every fish hops.
##
## The faces come from the race seed in the order the rolls happen, so with no chat a seed replays
## the same race. Time advances only in physics frames (through [method tick]).

## The die landed on `value` (1 to 6).
signal rolled(value: int)
## The meter changed. Empty text hides it.
signal meter_changed(text: String)

## Group of the die on the map in play: the game calls [method press] on it for chat presses.
const CHAT_GROUP: StringName = &"chat_roll"
## Seconds a "#roll" counts for.
const WINDOW: float = 6.0
## Most presses of one viewer that count at once, so one person cannot roll the die alone.
const PER_VIEWER: int = 2
## Presses needed: a share of the joined viewers, within these limits.
const NEED_SHARE: float = 0.4
const NEED_MIN: int = 3
const NEED_MAX: int = 12
## Seconds the die tumbles before it lands.
const ROLL_SECONDS: float = 0.9
## Seconds after a roll starts before chat can roll again.
const COOLDOWN: float = 2.5
## Race second of the first roll, and seconds between rolls when chat stays quiet.
const FIRST_MIN: float = 2.5
const FIRST_MAX: float = 3.5
const AUTO_MIN: float = 3.5
const AUTO_MAX: float = 5.0
## Seconds between checks whether the meter text changed on its own (presses leaving the window).
const METER_INTERVAL: float = 0.25
## Side of the die in pixels.
const SIZE: float = 132.0
const FACE_COLOR: Color = Color(0.98, 0.95, 0.88)
const PIP_COLOR: Color = Color(0.12, 0.1, 0.14)
const GLOW_COLOR: Color = Color(1.0, 0.82, 0.3)
## Pip spots of each face, in units of a third of the die.
const PIPS: Array[Array] = [
	[Vector2(0, 0)],
	[Vector2(-1, -1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
]

## Seconds since the race started, advanced by [method tick].
var clock: float = 0.0
## Face shown now (1 to 6).
var face: int = 6

var _armed: bool = false
var _tumbling: bool = false
var _tumble_time: float = 0.0
var _value: int = 6
var _cooldown: float = 0.0
var _next_auto: float = 0.0
var _rolls: int = 0
## Seconds the landed face keeps glowing.
var _glow: float = 0.0
var _meter_in: float = 0.0
var _last_text: String = ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _press_times: PackedFloat32Array = PackedFloat32Array()
var _press_names: PackedStringArray = PackedStringArray()
var _need: int = NEED_MIN


func _ready() -> void:
	Replayable.join(self)
	add_to_group(CHAT_GROUP)


func _process(_delta: float) -> void:
	queue_redraw()


## Plans the rolls of a race from `seed_value` and arms the die.
func reseed(seed_value: int) -> void:
	stop()
	_rng.seed = seed_value
	_next_auto = _rng.randf_range(FIRST_MIN, FIRST_MAX)
	_armed = true
	_emit_meter()


## Stops everything and puts the die back to rest.
func stop() -> void:
	var was_armed: bool = _armed
	_armed = false
	clock = 0.0
	_tumbling = false
	_tumble_time = 0.0
	_cooldown = 0.0
	_next_auto = 0.0
	_rolls = 0
	_glow = 0.0
	_press_times = PackedFloat32Array()
	_press_names = PackedStringArray()
	_need = NEED_MIN
	_meter_in = 0.0
	_last_text = ""
	face = 6
	if was_armed:
		meter_changed.emit("")


## Ends the rolls for good, at the end of a race. [method stop] is what readies it again.
func freeze() -> void:
	if not _armed:
		return
	_armed = false
	_tumbling = false
	meter_changed.emit("")
	_last_text = ""


func is_armed() -> bool:
	return _armed


func is_tumbling() -> bool:
	return _tumbling


## How many rolls have started this race.
func roll_count() -> int:
	return _rolls


## Race second of the next roll if chat stays quiet.
func next_auto_time() -> float:
	return _next_auto


## Presses needed inside the window for `viewers` joined viewers.
static func presses_needed(viewers: int) -> int:
	return clampi(ceili(float(viewers) * NEED_SHARE), NEED_MIN, NEED_MAX)


## A viewer typed "#roll". `viewers` is how many have joined the race. Returns whether it rolled
## the die.
func press(who: String, viewers: int = 0) -> bool:
	if not _armed:
		return false
	_need = presses_needed(viewers)
	_press_times.append(clock)
	_press_names.append(who)
	_prune()
	var started: bool = false
	if _can_roll() and counted_presses() >= _need:
		_start_roll()
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
	_glow = maxf(_glow - delta, 0.0)
	if _tumbling:
		_tumble_time += delta
		face = 1 + int(_tumble_time * 15.0 + float(_rolls) * 2.0) % 6
		if _tumble_time >= ROLL_SECONDS:
			_land()
	elif clock >= _next_auto:
		_start_roll()
		_emit_meter()
	_meter_in -= delta
	if _meter_in <= 0.0:
		_meter_in = METER_INTERVAL
		_emit_meter()


## Text of the on-screen meter.
func meter_text() -> String:
	if _tumbling:
		return "ROLLING..."
	if _cooldown > 0.0 and _rolls > 0:
		return "ROLLED A %d!" % face
	return "DICE   #roll   %d / %d" % [mini(counted_presses(), _need), _need]


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array(
		[float(face), 1.0 if _tumbling else 0.0, _tumble_time, _glow, 1.0 if _armed else 0.0]
	)


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	face = int(Replayable.step(from, to, weight, 0))
	_tumbling = Replayable.step(from, to, weight, 1) > 0.5
	_tumble_time = Replayable.mix(from, to, weight, 2)
	_glow = Replayable.mix(from, to, weight, 3)
	_armed = Replayable.step(from, to, weight, 4) > 0.5


func _can_roll() -> bool:
	return not _tumbling and _cooldown <= 0.0


func _prune() -> void:
	while not _press_times.is_empty() and clock - _press_times[0] > WINDOW:
		_press_times.remove_at(0)
		_press_names.remove_at(0)


func _start_roll() -> void:
	_rolls += 1
	_tumbling = true
	_tumble_time = 0.0
	_value = _rng.randi_range(1, 6)
	_cooldown = COOLDOWN
	_next_auto = clock + ROLL_SECONDS + _rng.randf_range(AUTO_MIN, AUTO_MAX)
	_press_times = PackedFloat32Array()
	_press_names = PackedStringArray()


func _land() -> void:
	_tumbling = false
	_tumble_time = 0.0
	face = _value
	_glow = 1.2
	rolled.emit(_value)
	_emit_meter()


func _emit_meter() -> void:
	var text: String = meter_text()
	if text != _last_text:
		_last_text = text
		meter_changed.emit(text)


func _draw() -> void:
	var t: float = _tumble_time / ROLL_SECONDS if _tumbling else 0.0
	# A tumble: the die hops and spins, settling as it lands.
	var hop: float = -absf(sin(t * PI * 3.0)) * 40.0 * (1.0 - t)
	var spin: float = sin(t * PI * 2.0) * 0.6 * (1.0 - t)
	draw_set_transform(Vector2(0.0, hop), spin, Vector2.ONE)
	var half: float = SIZE * 0.5
	if _glow > 0.0:
		var glow_size: float = SIZE * 2.6
		draw_texture_rect(
			RaceFx.glow_texture(),
			Rect2(-Vector2.ONE * glow_size * 0.5, Vector2.ONE * glow_size),
			false,
			Color(GLOW_COLOR, 0.6 * minf(_glow, 1.0))
		)
	draw_rect(Rect2(-half + 8.0, -half + 10.0, SIZE, SIZE), Color(0.0, 0.0, 0.0, 0.35))
	_draw_rounded(Rect2(-half, -half, SIZE, SIZE), 20.0, FACE_COLOR)
	_draw_rounded(Rect2(-half + 6.0, -half + 6.0, SIZE - 12.0, SIZE - 12.0), 16.0, Color.WHITE)
	var spacing: float = SIZE * 0.27
	for pip: Vector2 in PIPS[clampi(face, 1, 6) - 1]:
		var color: Color = Color(0.85, 0.15, 0.2) if face == 1 else PIP_COLOR
		draw_circle(pip * spacing, SIZE * 0.085, color, true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_rounded(rect: Rect2, radius: float, color: Color) -> void:
	draw_rect(
		Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2.0, rect.size.y),
		color
	)
	draw_rect(
		Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - radius * 2.0),
		color
	)
	for corner: Vector2 in [
		rect.position + Vector2(radius, radius),
		Vector2(rect.end.x - radius, rect.position.y + radius),
		Vector2(rect.position.x + radius, rect.end.y - radius),
		rect.end - Vector2(radius, radius),
	]:
		draw_circle(corner, radius, color, true, -1.0, true)
