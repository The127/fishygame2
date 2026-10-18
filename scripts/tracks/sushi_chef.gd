class_name SushiChef
extends Node2D
## The chef of Sushi Bar. He stands behind one belt with a big knife; chat typing "#chop" swings
## it. The knife comes down a moment after the press, so viewers time it to a fish riding under
## the blade. A fish under the blade when it lands is chopped: it is out of the race (DNF) and
## rides on down the belt as a piece of nigiri.
##
## Chat cannot wipe out the field: after each swing the knife needs [constant COOLDOWN] seconds
## before the next, one swing takes at most [constant PER_SWING] fish, and a race takes at most
## [constant FIELD_SHARE] of the field, counted over every chef that shares the [ChopTally]. With no chat the chef only taps his own board, so a race
## never depends on chat. The node sits at the point of the belt the blade lands on; its parent
## [SushiBelts] tells it how that belt moves. Time advances only in physics frames, and the knife
## and the nigiri are part of the finish replay.

## A swing chopped `marble`. `who` is the viewer whose "#chop" started the swing.
signal fish_chopped(marble: Marble, who: String)
## The chat meter changed. Empty text hides it.
signal meter_changed(text: String)
## A particle burst was let off, for the finish replay to play again.
signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)

enum Phase { READY, WINDUP, STRIKE, RECOVER }

## Group of the chef on the map in play: the game calls [method chop] on it for chat presses.
const CHAT_GROUP: StringName = &"chat_chop"
## Seconds from the press to the blade landing, how long it stays down, and seconds from the
## landing until the next swing can start.
const WINDUP: float = 0.55
const STRIKE: float = 0.18
const COOLDOWN: float = 4.0
## Most fish one swing chops, and the share of the field (rounded down) a race can lose.
const PER_SWING: int = 2
const FIELD_SHARE: float = 0.3
## Half the width of the blade along the belt, and how high above the belt it reaches a fish.
const BLADE_HALF: float = 46.0
const BLADE_REACH: float = 44.0
## Height of the raised blade over the belt.
const RAISED: float = 120.0
## Nigiri pieces kept at once, and the floats each takes in the replay state: x, y at the chop,
## time of the chop, and the color of the fish (r, g, b).
const MAX_NIGIRI: int = 8
const NIGIRI_FLOATS: int = 6
const NIGIRI_FADE: float = 0.5
const RICE: Color = Color(0.97, 0.95, 0.9)
const BLADE: Color = Color(0.85, 0.9, 0.95)
const SPLASH: Color = Color(1.0, 0.55, 0.45)
## Seconds between the meter's checks of the cooldown.
const METER_INTERVAL: float = 0.25

## Seconds since the race started, advanced by [method tick].
var clock: float = 0.0

var _armed: bool = false
var _phase: Phase = Phase.READY
var _phase_time: float = 0.0
var _cooldown: float = 0.0
var _chopped: int = 0
## Fish chopped this race by every chef of the map. A lone chef keeps his own.
var _tally: ChopTally = ChopTally.new()
var _field: int = 0
var _who: String = ""
var _swings: int = 0
## How the belt under the blade moves: 1 or -1, pixels per second, and the local x of its far end.
var _belt_direction: float = 1.0
var _belt_speed: float = 0.0
var _belt_end: float = 0.0
var _nigiri: PackedFloat32Array = PackedFloat32Array()
var _next_nigiri: int = 0
var _meter_in: float = 0.0
var _last_text: String = ""
var _time: float = 0.0


func _ready() -> void:
	Replayable.join(self)
	add_to_group(CHAT_GROUP)
	_clear_nigiri()


func _physics_process(delta: float) -> void:
	tick(delta)


## Called by the parent [SushiBelts]: the belt under the blade runs in `direction` at `speed`, and
## its far end is `end_x` (world x).
func set_belt(direction: float, speed: float, end_x: float) -> void:
	_belt_direction = direction
	_belt_speed = speed
	_belt_end = end_x - global_position.x


## Counts this chef's chops in `tally`, shared with the other chefs of the map.
func share_tally(tally: ChopTally) -> void:
	_tally = tally


## How many fish race, for the share of the field a race can lose.
func set_field_size(count: int) -> void:
	_field = count


## Arms the knife for a race.
func reseed(_seed_value: int) -> void:
	stop_gimmick()
	_armed = true
	_emit_meter()


## Puts the knife down and clears the belt of nigiri.
func stop_gimmick() -> void:
	var was_armed: bool = _armed
	_armed = false
	clock = 0.0
	_phase = Phase.READY
	_phase_time = 0.0
	_cooldown = 0.0
	_chopped = 0
	_tally.chopped = 0
	_swings = 0
	_who = ""
	_meter_in = 0.0
	_last_text = ""
	_clear_nigiri()
	if was_armed:
		meter_changed.emit("")


## Ends the swings for good at the end of a race; the nigiri stay where they are.
func freeze() -> void:
	if not _armed:
		return
	_armed = false
	_phase = Phase.READY
	_phase_time = 0.0
	meter_changed.emit("")
	_last_text = ""


func is_armed() -> bool:
	return _armed


func get_phase() -> Phase:
	return _phase


## How many fish this knife has chopped this race.
func chopped_count() -> int:
	return _chopped


## How many swings started this race.
func swing_count() -> int:
	return _swings


## Most fish a race of `field` fish can lose to the knife: a share of the field, at least one once
## two fish race, and never the last one.
static func chop_limit(field: int) -> int:
	if field < 2:
		return 0
	return clampi(floori(float(field) * FIELD_SHARE), 1, field - 1)


## Whether a "#chop" now would start a swing.
func can_swing() -> bool:
	return _armed and _phase == Phase.READY and _cooldown <= 0.0 and _tally.chopped < _limit()


## A viewer typed "#chop". Returns whether it started a swing.
func chop(who: String) -> bool:
	if not can_swing():
		return false
	_who = who
	_swings += 1
	_phase = Phase.WINDUP
	_phase_time = 0.0
	_emit_meter()
	return true


func tick(delta: float) -> void:
	if not _armed:
		return
	clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_phase_time += delta
	match _phase:
		Phase.WINDUP:
			if _phase_time >= WINDUP:
				_strike()
		Phase.STRIKE:
			if _phase_time >= STRIKE:
				_set_phase(Phase.RECOVER)
		Phase.RECOVER:
			if _cooldown <= 0.0:
				_set_phase(Phase.READY)
	_meter_in -= delta
	if _meter_in <= 0.0:
		_meter_in = METER_INTERVAL
		_emit_meter()


## Text of the on-screen meter.
func meter_text() -> String:
	if _tally.chopped >= _limit():
		return "THE CHEF IS FULL"
	match _phase:
		Phase.WINDUP, Phase.STRIKE:
			return "CHOP!"
		Phase.RECOVER:
			return "SHARPENING THE KNIFE"
	return "SUSHI CHEF   #chop"


func _limit() -> int:
	return chop_limit(_field if _field > 0 else get_tree().get_nodes_in_group(Marble.GROUP).size())


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0
	_emit_meter()


## The blade lands: up to [constant PER_SWING] fish under it are chopped, nearest first.
func _strike() -> void:
	_set_phase(Phase.STRIKE)
	_cooldown = COOLDOWN
	var victims: Array[Marble] = []
	for node: Node in get_tree().get_nodes_in_group(Marble.GROUP):
		var marble: Marble = node as Marble
		if marble.eaten or marble.has_finished or marble.freeze:
			continue
		var local: Vector2 = to_local(marble.global_position)
		if absf(local.x) <= BLADE_HALF and local.y <= 2.0 and local.y >= -BLADE_REACH:
			victims.append(marble)
	victims.sort_custom(
		func(a: Marble, b: Marble) -> bool:
			return absf(to_local(a.global_position).x) < absf(to_local(b.global_position).x)
	)
	var room: int = mini(PER_SWING, _limit() - _tally.chopped)
	for i: int in mini(room, victims.size()):
		_chop_fish(victims[i])
	RaceFx.burst(self, global_position, BLADE, 8, 120.0, Vector2(0.0, 200.0))
	burst_played.emit(global_position, BLADE, 8, 120.0, Vector2(0.0, 200.0))
	_emit_meter()


func _chop_fish(marble: Marble) -> void:
	var at: Vector2 = marble.global_position
	marble.chop()
	_chopped += 1
	_tally.chopped += 1
	var local: Vector2 = to_local(at)
	var base: int = _next_nigiri * NIGIRI_FLOATS
	_nigiri[base] = local.x
	_nigiri[base + 1] = -Marble.RADIUS * 0.4
	_nigiri[base + 2] = clock
	_nigiri[base + 3] = marble.color.r
	_nigiri[base + 4] = marble.color.g
	_nigiri[base + 5] = marble.color.b
	_next_nigiri = (_next_nigiri + 1) % MAX_NIGIRI
	RaceFx.burst(self, at, SPLASH, 18, 160.0, Vector2(0.0, 120.0))
	burst_played.emit(at, SPLASH, 18, 160.0, Vector2(0.0, 120.0))
	fish_chopped.emit(marble, _who)


func _clear_nigiri() -> void:
	_nigiri.resize(MAX_NIGIRI * NIGIRI_FLOATS)
	_nigiri.fill(0.0)
	for i: int in MAX_NIGIRI:
		_nigiri[i * NIGIRI_FLOATS + 2] = -1.0
	_next_nigiri = 0


func _emit_meter() -> void:
	var text: String = meter_text() if _armed else ""
	if text != _last_text:
		_last_text = text
		meter_changed.emit(text)


## Part of the finish replay ([Replayable]): the clock, the swing and every nigiri slot.
func replay_state() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array([clock, float(_phase), _phase_time])
	state.append_array(_nigiri)
	return state


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	clock = Replayable.mix(from, to, weight, 0)
	_phase = int(Replayable.step(from, to, weight, 1)) as Phase
	_phase_time = Replayable.step(from, to, weight, 2)
	for i: int in MAX_NIGIRI * NIGIRI_FLOATS:
		_nigiri[i] = Replayable.step(from, to, weight, 3 + i)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## How high the blade is over the belt now: 1 raised, 0 on the belt.
func _blade_height() -> float:
	match _phase:
		Phase.WINDUP:
			# Up high quickly, then a short hang before it drops.
			return minf(_phase_time / (WINDUP * 0.5), 1.0)
		Phase.STRIKE:
			return 0.0
		Phase.RECOVER:
			return minf(_phase_time / 0.6, 1.0) * 0.45
	# Ready: the chef taps his own board in a slow rhythm.
	return 0.45 + 0.06 * sin(_time * 5.0)


func _draw() -> void:
	_draw_chef()
	for i: int in MAX_NIGIRI:
		if _nigiri[i * NIGIRI_FLOATS + 2] >= 0.0:
			_draw_nigiri(i * NIGIRI_FLOATS)


## The chef behind the belt: a white jacket, a red headband, and his arm holding the knife over the
## blade's spot. Drawn round this node's origin, the point of the belt the blade lands on.
func _draw_chef() -> void:
	var side: float = -_belt_direction
	var torso: Vector2 = Vector2(110.0 * side, -70.0)
	var jacket: Color = Color(0.95, 0.94, 0.9)
	var bob: float = sin(_time * 2.0) * 2.0
	draw_rect(Rect2(torso + Vector2(-34.0, -40.0 + bob), Vector2(68.0, 70.0)), jacket)
	draw_line(
		torso + Vector2(0.0, -40.0 + bob),
		torso + Vector2(0.0, 30.0 + bob),
		Color(0.7, 0.7, 0.7),
		2.0
	)
	var head: Vector2 = torso + Vector2(0.0, -64.0 + bob)
	draw_circle(head, 22.0, Color(0.96, 0.8, 0.66))
	draw_rect(Rect2(head + Vector2(-23.0, -16.0), Vector2(46.0, 8.0)), Color(0.85, 0.12, 0.15))
	draw_circle(head + Vector2(-8.0 * side, -2.0), 2.5, Color(0.1, 0.08, 0.08))
	draw_circle(head + Vector2(-16.0 * side, -2.0), 2.5, Color(0.1, 0.08, 0.08))
	draw_line(
		head + Vector2(-14.0 * side, 9.0),
		head + Vector2(-4.0 * side, 9.0),
		Color(0.4, 0.2, 0.15),
		2.0
	)
	# The knife: the blade lies along the belt, edge down, its handle toward the chef.
	var height: float = _blade_height()
	var blade_y: float = -4.0 - RAISED * height
	var tilt: float = -0.35 * height * side
	var hand: Vector2 = Vector2((BLADE_HALF + 30.0) * side, blade_y - 6.0)
	var shoulder: Vector2 = torso + Vector2(-30.0 * side, -30.0 + bob)
	draw_line(shoulder, hand, jacket, 12.0, true)
	draw_circle(hand, 8.0, Color(0.96, 0.8, 0.66))
	var blade: PackedVector2Array = PackedVector2Array(
		[
			Vector2(-BLADE_HALF, -14.0),
			Vector2(BLADE_HALF, -14.0),
			Vector2(BLADE_HALF, 0.0),
			Vector2(-BLADE_HALF + 10.0, 0.0),
		]
	)
	var handle: Rect2 = Rect2(Vector2(BLADE_HALF, -11.0), Vector2(26.0, 9.0))
	var turn: Transform2D = Transform2D(tilt, Vector2(0.0, blade_y))
	if side < 0.0:
		turn = turn * Transform2D.FLIP_X
	draw_set_transform_matrix(turn)
	draw_colored_polygon(blade, BLADE)
	draw_line(Vector2(-BLADE_HALF + 10.0, 0.0), Vector2(BLADE_HALF, 0.0), Color.WHITE, 2.0, true)
	draw_rect(handle, Color(0.35, 0.2, 0.1))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if _phase == Phase.WINDUP:
		# The blade's shadow on the belt grows as it is about to drop.
		var warn: float = clampf(_phase_time / WINDUP, 0.0, 1.0)
		draw_rect(
			Rect2(Vector2(-BLADE_HALF, -3.0), Vector2(BLADE_HALF * 2.0, 3.0)),
			Color(1.0, 0.3, 0.2, 0.3 + 0.6 * warn)
		)


## One piece of nigiri: a ball of rice with a slice of the chopped fish on top, riding the belt
## to its far end and fading there.
func _draw_nigiri(base: int) -> void:
	var age: float = maxf(clock - _nigiri[base + 2], 0.0)
	var x: float = _nigiri[base] + _belt_direction * _belt_speed * age
	var past: float = (x - _belt_end) * _belt_direction
	var alpha: float = 1.0
	if past > 0.0:
		x = _belt_end
		alpha = 1.0 - clampf(past / (_belt_speed * NIGIRI_FADE + 0.001), 0.0, 1.0)
	if alpha <= 0.0:
		return
	var at: Vector2 = Vector2(x, _nigiri[base + 1])
	var topping: Color = Color(_nigiri[base + 3], _nigiri[base + 4], _nigiri[base + 5], alpha)
	draw_rect(Rect2(at + Vector2(-13.0, -2.0), Vector2(26.0, 8.0)), Color(RICE, alpha))
	draw_circle(at + Vector2(-13.0, 2.0), 4.0, Color(RICE, alpha))
	draw_circle(at + Vector2(13.0, 2.0), 4.0, Color(RICE, alpha))
	draw_rect(Rect2(at + Vector2(-15.0, -8.0), Vector2(30.0, 7.0)), topping)
	draw_line(
		at + Vector2(-10.0, -6.0),
		at + Vector2(-4.0, -3.0),
		Color(1.0, 1.0, 1.0, 0.5 * alpha),
		1.5,
		true
	)
	draw_line(
		at + Vector2(2.0, -6.0),
		at + Vector2(8.0, -3.0),
		Color(1.0, 1.0, 1.0, 0.5 * alpha),
		1.5,
		true
	)
	draw_rect(Rect2(at + Vector2(-3.0, -8.0), Vector2(6.0, 14.0)), Color(0.05, 0.12, 0.08, alpha))
