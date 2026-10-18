# gdlint: disable=max-public-methods
class_name ClawMachine
extends Node2D
## The claw of the Claw Machine map, and the prize shelf under the fish. The claw hangs from a
## rail along the top of the cabinet. It moves sideways, drops, closes on a random fish under it,
## lifts it and carries it to the prize chute on the left, past `pit_left`, where it lets go. On
## the way it sometimes loses its grip and the fish falls back on the pile, like every real claw
## machine. Chat steers it with "#left" and "#right" and drops it with "#grab" ([method steer],
## [method grab]); a claw nobody drops goes down by itself after [constant MAX_HOVER] seconds,
## and when chat has been quiet for [constant CHAT_QUIET] seconds it picks a fish and goes for it.
##
## The claw does not decide when the race ends. The `Lift` child (an AnimatableBody2D, the shelf
## the fish lie on, tilted down toward the chute) rises steadily from the start of the race until
## its low end is above the chute wall, so every fish left on it rolls over into the chute. A race
## always finishes, with or without chat; the claw only picks who gets there early.
##
## Time advances only in physics frames and every random draw comes from the race seed, so a seed
## with no chat replays the same race.

## A viewer's press changed the tally. Empty text hides it.
signal tally_changed(text: String)
## The claw let a fish drop before the chute.
signal fish_slipped(marble: Marble)

enum State { IDLE, DROP, CLOSE, LIFT, CARRY, OPEN }

## Group of the claw on the map in play: the game calls [method steer] and [method grab] on it
## for chat presses.
const CHAT_GROUP: StringName = &"chat_claw"

## How far one "#left" or "#right" moves the claw, in pixels.
const STEP: float = 150.0
## Speeds in pixels per second.
const MOVE_SPEED: float = 760.0
const DROP_SPEED: float = 1100.0
const LIFT_SPEED: float = 760.0
const CARRY_SPEED: float = 900.0
## Seconds the jaws take to close, and to open over the chute.
const CLOSE_SECONDS: float = 0.35
const OPEN_SECONDS: float = 0.4
## Seconds the claw hovers over its fish before an automatic drop.
const AIM_PAUSE: float = 0.25
## Seconds the claw waits for "#grab" before it drops by itself.
const MAX_HOVER: float = 6.0
## Seconds after a chat press during which the claw leaves the aiming to chat.
const CHAT_QUIET: float = 4.0
## Chance that the claw loses its fish on the way, and the share of the way (lift and carry)
## between which it happens.
const SLIP_CHANCE: float = 0.35
const SLIP_FROM: float = 0.15
const SLIP_TO: float = 0.85
## A fish this close to the jaw tip stops the drop; one this close when the jaws shut is grabbed.
const TOUCH_RADIUS: float = 34.0
const GRAB_RADIUS: float = 50.0
## A held fish knocked this far from the jaws is lost.
const LOSE_DISTANCE: float = 90.0
## Fastest a held fish is pulled after the jaws, in pixels per second.
const HOLD_SPEED: float = 2400.0
## How far below the jaw tip the held fish hangs.
const GRIP_OFFSET: float = 14.0
## How far above the shelf the jaw tip stops at the lowest.
const FLOOR_CLEARANCE: float = 18.0
## Names listed in the tally.
const NAMES_SHOWN: int = 3
const METAL: Color = Color(0.78, 0.82, 0.9)
const METAL_DARK: Color = Color(0.32, 0.36, 0.46)
const GLOW: Color = Color(1.0, 0.5, 0.85)
const PRIZE_GLOW: Color = Color(1.0, 0.85, 0.3)
const SLIP_GLOW: Color = Color(1.0, 0.35, 0.3)

## World y of the rail the claw hangs from, and of the jaw tip at the top of its cable.
@export var rail_y: float = 70.0
@export var rest_y: float = 210.0
## World x of the chute wall: the claw lets go left of it, and only fish right of it are grabbed.
@export var pit_left: float = 340.0
@export var pit_right: float = 1880.0
## World x the claw lets go at, over the chute.
@export var chute_x: float = 170.0
## World y of the top of the chute wall. The shelf rises until its low end is above it.
@export var wall_top: float = 545.0
## Seconds after the start before the shelf moves, and seconds it takes to rise all the way.
@export var lift_delay: float = 4.0
@export var lift_seconds: float = 36.0
## How far the shelf rises, in pixels.
@export var lift_rise: float = 520.0
## How much higher the shelf's far (right) end is than its chute end, in pixels.
@export var tilt: float = 170.0

## Seconds since the race started, advanced by [method tick].
var clock: float = 0.0
var state: State = State.IDLE
## World x of the claw and world y of its jaw tip.
var claw_x: float = 0.0
var claw_y: float = 0.0
## Where the claw is heading while it is idle.
var target_x: float = 0.0
## 0 for open jaws, 1 for shut.
var jaw: float = 0.0
## Fish the claw delivered to the chute, and fish it lost on the way, this race.
var prizes: int = 0
var slips: int = 0

var _armed: bool = false
var _lift: AnimatableBody2D
var _lift_start_y: float = 0.0
## Local y of the shelf. Kept here as well, as the body itself only takes it in a physics frame.
var _lift_y: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _held: Marble = null
## The fish the claw is going for on its own, or null while chat aims.
var _aim: Marble = null
var _state_time: float = 0.0
var _hover: float = 0.0
var _last_chat: float = -1000.0
## Share of the way (lift and carry) at which the held fish slips, or above 1 when it holds on.
var _slip_at: float = 2.0
var _carry_from_x: float = 0.0
## 1 just after a prize or a slip, fading to 0.
var _prize_flash: float = 0.0
var _slip_flash: float = 0.0
var _time: float = 0.0
## Presses of "#left", "#right" and "#grab".
var _presses: PackedInt32Array = PackedInt32Array([0, 0, 0])
var _names: PackedStringArray = PackedStringArray()


func _ready() -> void:
	Replayable.join(self)
	add_to_group(CHAT_GROUP)
	z_index = 4
	_lift = get_node("Lift") as AnimatableBody2D
	_lift_start_y = _lift.position.y
	_lift_y = _lift_start_y
	claw_x = chute_x
	claw_y = rest_y
	target_x = chute_x


func _physics_process(delta: float) -> void:
	tick(delta)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Called by [method Track.seed_gimmicks]: puts the claw over the chute and the shelf down, and
## arms the machine for a race.
func reseed(seed_value: int) -> void:
	stop_gimmick()
	_rng.seed = seed_value
	_armed = true
	_emit_tally()


## Called by [method Track.stop_gimmicks].
func stop_gimmick() -> void:
	var was_armed: bool = _armed
	_armed = false
	_let_go()
	_aim = null
	clock = 0.0
	state = State.IDLE
	_state_time = 0.0
	_hover = 0.0
	_last_chat = -1000.0
	_slip_at = 2.0
	claw_x = chute_x
	claw_y = rest_y
	target_x = chute_x
	jaw = 0.0
	prizes = 0
	slips = 0
	_prize_flash = 0.0
	_slip_flash = 0.0
	_presses = PackedInt32Array([0, 0, 0])
	_names = PackedStringArray()
	_set_lift(_lift_start_y)
	queue_redraw()
	if was_armed:
		tally_changed.emit("")


func is_armed() -> bool:
	return _armed


## The fish in the claw right now, or null.
func get_held() -> Marble:
	return _held


func get_lift() -> AnimatableBody2D:
	return _lift


## Share (0 to 1) of its rise the shelf has made.
func lift_fraction() -> float:
	return clampf((_lift_start_y - _lift_y) / lift_rise, 0.0, 1.0)


## World y of the top of the shelf at world x `x`.
func shelf_y(x: float) -> float:
	var along: float = clampf((x - pit_left) / (pit_right - pit_left), 0.0, 1.0)
	return to_global(Vector2(0.0, _lift_y)).y - tilt * along


## A viewer pressed "#left" (`side` -1) or "#right" (1). The claw only moves while it waits over
## the cabinet, but every press counts on the tally.
func steer(side: int, who: String = "") -> bool:
	if not _armed:
		return false
	_count(0 if side < 0 else 1, who)
	if state != State.IDLE:
		return false
	_aim = null
	target_x = clampf(target_x + STEP * float(signi(side)), _low_x(), _high_x())
	return true


## A viewer pressed "#grab": the claw drops where it is, if it is waiting over the pit.
func grab(who: String = "") -> bool:
	if not _armed:
		return false
	_count(2, who)
	if state != State.IDLE or claw_x < pit_left + Marble.RADIUS:
		return false
	_aim = null
	_drop()
	return true


func presses(index: int) -> int:
	return _presses[index]


## Text of the on-screen tally: presses per command and the latest viewers.
func tally_text() -> String:
	var text: String = (
		"CLAW   #left %d   #right %d   #grab %d" % [_presses[0], _presses[1], _presses[2]]
	)
	if not _names.is_empty():
		text += "\n" + ", ".join(_names)
	return text


## Race progress of a fish at `global_pos` while it is in the cabinet (right of the chute wall),
## or -1 elsewhere so the centerline measures it. A fish on the shelf scores by how near the
## chute it lies and by how far the shelf has risen; the held fish by how far the claw has
## carried it. All of it stays below the progress at the top of the chute.
func progress_at(global_pos: Vector2) -> float:
	var at: Vector2 = to_local(global_pos)
	if at.x < pit_left:
		return -1.0
	if _held != null and at.distance_to(_grip()) < LOSE_DISTANCE:
		return 0.5 + 0.28 * _journey()
	var near_chute: float = clampf((pit_right - at.x) / (pit_right - pit_left), 0.0, 1.0)
	return 0.02 + 0.45 * (0.4 * near_chute + 0.6 * lift_fraction())


func tick(delta: float) -> void:
	if not _armed:
		return
	clock += delta
	_state_time += delta
	_prize_flash = maxf(_prize_flash - delta * 1.5, 0.0)
	_slip_flash = maxf(_slip_flash - delta * 1.5, 0.0)
	var rise: float = clampf((clock - lift_delay) / lift_seconds, 0.0, 1.0)
	_set_lift(_lift_start_y - lift_rise * rise)
	match state:
		State.IDLE:
			_tick_idle(delta)
		State.DROP:
			claw_y += DROP_SPEED * delta
			var bottom: float = to_local(Vector2(0.0, shelf_y(claw_x))).y - FLOOR_CLEARANCE
			if claw_y >= bottom or _touching():
				claw_y = minf(claw_y, bottom)
				_enter(State.CLOSE)
		State.CLOSE:
			jaw = minf(_state_time / CLOSE_SECONDS, 1.0)
			if _state_time >= CLOSE_SECONDS:
				_close_on(_pick_fish())
				_enter(State.LIFT)
		State.LIFT:
			claw_y = maxf(claw_y - LIFT_SPEED * delta, rest_y)
			if claw_y <= rest_y:
				_carry_from_x = claw_x
				_enter(State.CARRY)
		State.CARRY:
			claw_x = move_toward(claw_x, chute_x, CARRY_SPEED * delta)
			if is_equal_approx(claw_x, chute_x):
				_enter(State.OPEN)
				if _held != null:
					prizes += 1
					_prize_flash = 1.0
					_let_go()
		State.OPEN:
			jaw = maxf(1.0 - _state_time / OPEN_SECONDS, 0.0)
			if _state_time >= OPEN_SECONDS:
				target_x = claw_x
				_hover = 0.0
				_enter(State.IDLE)
	_hold_fish(delta)


## Part of the finish replay ([Replayable]): the claw, its jaws, the shelf and the lights.
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array(
		[
			clock,
			float(state),
			claw_x,
			claw_y,
			jaw,
			_lift_y,
			_prize_flash,
			_slip_flash,
			1.0 if _armed else 0.0,
		]
	)


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	clock = Replayable.mix(from, to, weight, 0)
	state = int(Replayable.step(from, to, weight, 1)) as State
	claw_x = Replayable.mix(from, to, weight, 2)
	claw_y = Replayable.mix(from, to, weight, 3)
	jaw = Replayable.mix(from, to, weight, 4)
	_set_lift(Replayable.mix(from, to, weight, 5))
	_prize_flash = Replayable.mix(from, to, weight, 6)
	_slip_flash = Replayable.mix(from, to, weight, 7)
	_armed = Replayable.step(from, to, weight, 8) > 0.5
	queue_redraw()


func _tick_idle(delta: float) -> void:
	_hover += delta
	var quiet: bool = clock - _last_chat >= CHAT_QUIET
	if quiet or (_hover >= MAX_HOVER and claw_x < pit_left + Marble.RADIUS):
		if _aim == null or not _grabbable(_aim):
			_aim = _choose_aim()
		if _aim != null:
			target_x = clampf(to_local(_aim.global_position).x, _low_x(), _high_x())
	claw_x = move_toward(claw_x, target_x, MOVE_SPEED * delta)
	var arrived: bool = absf(claw_x - target_x) < 1.0
	if _aim != null and arrived and _hover >= AIM_PAUSE:
		_drop()
	elif _hover >= MAX_HOVER and claw_x >= pit_left + Marble.RADIUS:
		_drop()


func _drop() -> void:
	_enter(State.DROP)


func _enter(next: State) -> void:
	state = next
	_state_time = 0.0


## A random fish in the pit for the claw to go for, or null when none is left.
func _choose_aim() -> Marble:
	var candidates: Array[Marble] = []
	for node: Node in get_tree().get_nodes_in_group(Marble.GROUP):
		var marble: Marble = node as Marble
		if marble != null and _grabbable(marble):
			candidates.append(marble)
	if candidates.is_empty():
		return null
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


## Whether the claw may take `marble`: still racing and in the pit, right of the chute wall.
func _grabbable(marble: Marble) -> bool:
	if marble.eaten or marble.has_finished or marble.is_out() or marble.replaying:
		return false
	return to_local(marble.global_position).x > pit_left + Marble.RADIUS


func _touching() -> bool:
	var tip: Vector2 = Vector2(claw_x, claw_y)
	for node: Node in get_tree().get_nodes_in_group(Marble.GROUP):
		var marble: Marble = node as Marble
		if marble != null and _grabbable(marble):
			if to_local(marble.global_position).distance_to(tip) < TOUCH_RADIUS:
				return true
	return false


## A random fish within reach of the shut jaws, or null.
func _pick_fish() -> Marble:
	var tip: Vector2 = Vector2(claw_x, claw_y + GRIP_OFFSET)
	var reach: Array[Marble] = []
	for node: Node in get_tree().get_nodes_in_group(Marble.GROUP):
		var marble: Marble = node as Marble
		if marble != null and _grabbable(marble):
			if to_local(marble.global_position).distance_to(tip) < GRAB_RADIUS:
				reach.append(marble)
	if reach.is_empty():
		return null
	return reach[_rng.randi_range(0, reach.size() - 1)]


## Takes hold of `marble` (or comes up empty for null) and rolls whether it will slip.
func _close_on(marble: Marble) -> void:
	_held = marble
	_aim = null
	_slip_at = 2.0
	if marble == null:
		return
	# Drawn for every grab, so the draws stay in step whatever happens to the fish.
	var roll: float = _rng.randf()
	var at: float = _rng.randf_range(SLIP_FROM, SLIP_TO)
	if roll < SLIP_CHANCE:
		_slip_at = at


## Share (0 to 1) of the way from the pile to the chute the claw has come: the lift is the first
## half, the carry the second.
func _journey() -> float:
	match state:
		State.LIFT:
			return 0.0
		State.CARRY:
			var span: float = maxf(_carry_from_x - chute_x, 1.0)
			return clampf((_carry_from_x - claw_x) / span, 0.0, 1.0)
		State.OPEN:
			return 1.0
	return 0.0


## Pulls the held fish after the jaws, and lets it slip when its time has come.
func _hold_fish(delta: float) -> void:
	if _held == null:
		return
	if _held.eaten or _held.is_out() or _held.has_finished:
		_let_go()
		return
	var grip: Vector2 = to_global(_grip())
	var off: Vector2 = grip - _held.global_position
	var share: float = _share_of_way()
	var over_pit: bool = claw_x > pit_left + Marble.RADIUS * 2.0
	if off.length() > LOSE_DISTANCE or (over_pit and share >= _slip_at):
		_slip()
		return
	_held.sleeping = false
	_held.linear_velocity = (off / maxf(delta, 0.001)).limit_length(HOLD_SPEED)
	_held.angular_velocity *= 0.5


## Share of the whole way, lift and carry together, for the slip roll.
func _share_of_way() -> float:
	if state == State.LIFT:
		var drop_depth: float = maxf(_lift_bottom() - rest_y, 1.0)
		return 0.5 * clampf(1.0 - (claw_y - rest_y) / drop_depth, 0.0, 1.0)
	if state == State.CARRY:
		return 0.5 + 0.5 * _journey()
	return 0.0


func _lift_bottom() -> float:
	return to_local(Vector2(0.0, shelf_y(claw_x))).y - FLOOR_CLEARANCE


func _slip() -> void:
	var lost: Marble = _held
	_let_go()
	slips += 1
	_slip_flash = 1.0
	jaw = 0.4
	fish_slipped.emit(lost)


func _let_go() -> void:
	if _held != null:
		_held.linear_velocity = _held.linear_velocity.limit_length(220.0)
	_held = null


func _set_lift(y: float) -> void:
	_lift_y = y
	_lift.position.y = y


func _grip() -> Vector2:
	return Vector2(claw_x, claw_y + GRIP_OFFSET)


func _low_x() -> float:
	return chute_x


func _high_x() -> float:
	return pit_right - 60.0


func _count(index: int, who: String) -> void:
	_presses[index] += 1
	_last_chat = clock
	if not who.is_empty():
		if _names.has(who):
			_names.remove_at(_names.find(who))
		_names.append(who)
		while _names.size() > NAMES_SHOWN:
			_names.remove_at(0)
	_emit_tally()


func _emit_tally() -> void:
	tally_changed.emit(tally_text())


func _draw() -> void:
	_draw_lift()
	_draw_chute_sign()
	_draw_claw()


## A neon rim along the top of the shelf and scissor arms under it, so it reads as a lift.
func _draw_lift() -> void:
	var low: Vector2 = Vector2(pit_left + 2.0, _lift_y)
	var high: Vector2 = Vector2(pit_right - 2.0, _lift_y - tilt)
	draw_line(low, high, Color(GLOW, 0.8), 4.0, true)
	for i: int in 16:
		var dot: Vector2 = low.lerp(high, (float(i) + 0.5) / 16.0) + Vector2(0.0, 22.0)
		var chase: float = fposmod(-_time * 1.5 + float(i) * 0.12, 1.0)
		draw_circle(dot, 4.0, Color(PRIZE_GLOW, 0.2 + 0.6 * chase))
	var top: float = _lift_y + 60.0
	var base: float = 1060.0
	if base - top < 8.0:
		return
	var color: Color = Color(METAL_DARK, 0.85)
	var pairs: int = 4
	for i: int in pairs:
		var x0: float = lerpf(pit_left + 80.0, pit_right - 80.0, float(i) / float(pairs - 1))
		var half: float = 90.0
		draw_line(Vector2(x0 - half, top), Vector2(x0 + half, base), color, 6.0, true)
		draw_line(Vector2(x0 + half, top), Vector2(x0 - half, base), color, 6.0, true)
		draw_circle(Vector2(x0, (top + base) * 0.5), 6.0, METAL)


## The glowing PRIZE sign over the chute.
func _draw_chute_sign() -> void:
	var font: Font = ThemeDB.fallback_font
	var pulse: float = 0.55 + 0.25 * sin(_time * 3.0) + 0.45 * _prize_flash
	var color: Color = Color(PRIZE_GLOW, clampf(pulse, 0.0, 1.0))
	draw_string(
		font,
		Vector2(chute_x - 90.0, wall_top - 70.0),
		"PRIZE",
		HORIZONTAL_ALIGNMENT_CENTER,
		180.0,
		40,
		color
	)
	for i: int in 3:
		var y: float = wall_top - 40.0 + float(i) * 22.0
		var phase: float = fposmod(_time * 1.6 - float(i) * 0.3, 1.0)
		draw_polyline(
			PackedVector2Array(
				[Vector2(chute_x - 24.0, y), Vector2(chute_x, y + 14.0), Vector2(chute_x + 24.0, y)]
			),
			Color(PRIZE_GLOW, 0.15 + 0.5 * phase),
			4.0,
			true
		)


## The rail, the carriage, the cable and the three-pronged claw.
func _draw_claw() -> void:
	draw_line(Vector2(chute_x - 120.0, rail_y), Vector2(pit_right - 10.0, rail_y), METAL_DARK, 10.0)
	draw_line(
		Vector2(chute_x - 120.0, rail_y - 4.0), Vector2(pit_right - 10.0, rail_y - 4.0), METAL, 2.0
	)
	# Marquee bulbs along the rail, chasing toward the chute.
	var bulbs: int = 28
	for i: int in bulbs:
		var x: float = lerpf(chute_x - 100.0, pit_right - 30.0, float(i) / float(bulbs - 1))
		var chase: float = fposmod(_time * 2.0 + float(i) * 0.25, 1.0)
		var bulb: Color = PRIZE_GLOW if i % 2 == 0 else GLOW
		draw_circle(Vector2(x, rail_y - 22.0), 4.0, Color(bulb, 0.25 + 0.6 * chase))
	var carriage: Rect2 = Rect2(claw_x - 34.0, rail_y - 16.0, 68.0, 30.0)
	draw_rect(carriage, METAL_DARK)
	draw_rect(carriage, METAL, false, 2.0)
	var head: Vector2 = Vector2(claw_x, claw_y - 40.0)
	draw_line(Vector2(claw_x, rail_y + 14.0), head, METAL, 3.0, true)
	var lit: Color = GLOW.lerp(SLIP_GLOW, _slip_flash).lerp(PRIZE_GLOW, _prize_flash)
	draw_circle(head, 24.0, METAL_DARK)
	draw_arc(head, 24.0, 0.0, TAU, 28, lit, 4.0, true)
	# Open jaws spread to 40 degrees out, shut ones curl in under the fish.
	var spread: float = lerpf(deg_to_rad(40.0), deg_to_rad(8.0), jaw)
	for side: int in [-1, 1]:
		var upper: Vector2 = head + Vector2(float(side) * 16.0, 8.0)
		var elbow: Vector2 = upper + Vector2(float(side) * sin(spread) * 46.0, cos(spread) * 46.0)
		var tip_angle: float = spread - lerpf(deg_to_rad(10.0), deg_to_rad(70.0), jaw)
		var tip: Vector2 = (
			elbow + Vector2(float(side) * sin(tip_angle) * 30.0, cos(tip_angle) * 30.0)
		)
		draw_polyline(PackedVector2Array([upper, elbow, tip]), METAL, 8.0, true)
		draw_circle(tip, 5.0, lit)
	draw_line(
		head + Vector2(0.0, 16.0), head + Vector2(0.0, 40.0 + 24.0 * (1.0 - jaw)), METAL, 6.0, true
	)
