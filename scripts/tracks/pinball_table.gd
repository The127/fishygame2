class_name PinballTable
extends Node2D
## The moving parts of Pinball Reef: the plunger that launches the pack, the bumpers that pop
## fish away and the flippers chat fires with "#left" and "#right". Children: `PinballFlipper`s,
## `Plunger` (an Area2D over the bottom of the launch lane) and `Orbit` (an Area2D over its top,
## where a current carries fish out over the table). Bumpers are the `StaticBody2D`s
## of the track in the group "pinball_bumper", each with a circle `Collider`.
##
## Flippers fire on the side's cooldown, from chat ([method fire]) or by themselves: the
## schedule is drawn from the race seed in [method reseed], and skipped while chat has fired
## lately, so a quiet chat never stalls a race and a busy one is left alone. Time advances
## only in physics frames, so a seed with no chat replays the same race.

## A viewer's press changed the tally. Empty text hides it.
signal tally_changed(text: String)

const LEFT: int = -1
const RIGHT: int = 1
const BUMPER_GROUP: StringName = &"pinball_bumper"
## Group of the table on the map in play: the game calls [method fire] on it for chat presses.
const CHAT_GROUP: StringName = &"chat_flippers"

## Seconds before the same side can fire again.
const COOLDOWN: float = 0.6
## Seconds between automatic fires of one side, drawn per fire, and before the first one.
const AUTO_FIRST_MIN: float = 3.0
const AUTO_FIRST_MAX: float = 6.0
const AUTO_MIN: float = 3.5
const AUTO_MAX: float = 7.0
## Race seconds after which no more automatic fires are planned.
const HORIZON: float = 150.0
## Seconds after a chat press during which the automatic fires stay out of the way.
const CHAT_QUIET: float = 4.0
## Speed a bumper sends a fish away at, in pixels per second.
const POP_SPEED: float = 480.0
## How far beyond a bumper's rim a fish still sets it off.
const BUMPER_PAD: float = 5.0
const FLASH_SECONDS: float = 0.4
## Seconds before the plunger fires at the start, and between its later tries.
const LAUNCH_DELAY: float = 0.9
const RELAUNCH_SECONDS: float = 2.4
## Speed the plunger gives a resting fish, straight up the lane, in pixels per second.
const LAUNCH_SPEED: float = 1350.0
const LAUNCH_SPREAD: float = 0.04
const LAUNCH_SIDEWAYS: float = 40.0
## Push of the current at the top of the lane, in pixels per second squared.
const ORBIT_PUSH: float = 2400.0
## Names listed in the tally.
const NAMES_SHOWN: int = 3
const GLOW: Color = Color(1.0, 0.42, 0.55)
const SPRING_LENGTH: float = 54.0

## Seconds since the race started, advanced by [method tick].
var clock: float = 0.0

var _armed: bool = false
var _flippers: Array[PinballFlipper] = []
var _plunger: Area2D
var _orbit: Area2D
var _plunger_rect: Rect2 = Rect2()
var _bumper_centers: PackedVector2Array = PackedVector2Array()
var _bumper_radii: PackedFloat32Array = PackedFloat32Array()
var _flash: PackedFloat32Array = PackedFloat32Array()
## Seconds until each side (left, right) may fire again.
var _cooldown: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
## Planned automatic fire times per side (left, right) and the next one due.
var _auto_times: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
var _auto_next: PackedInt32Array = PackedInt32Array([0, 0])
var _last_chat: float = -1000.0
var _launch_in: float = LAUNCH_DELAY
var _launch_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 1 just after the plunger fires, fading to 0.
var _piston: float = 0.0
var _time: float = 0.0
var _presses: PackedInt32Array = PackedInt32Array([0, 0])
var _names: PackedStringArray = PackedStringArray()


func _ready() -> void:
	Replayable.join(self)
	add_to_group(CHAT_GROUP)
	z_index = 3
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	for child: Node in get_children():
		if child is PinballFlipper:
			_flippers.append(child as PinballFlipper)
	_plunger = get_node("Plunger") as Area2D
	_orbit = get_node("Orbit") as Area2D
	var zone: CollisionShape2D = _plunger.get_node("CollisionShape2D") as CollisionShape2D
	var size: Vector2 = (zone.shape as RectangleShape2D).size
	_plunger_rect = Rect2(to_local(zone.global_position) - size * 0.5, size)
	var parent: Node = get_parent()
	if parent != null:
		for sibling: Node in parent.get_children():
			if sibling.is_in_group(BUMPER_GROUP) and sibling is StaticBody2D:
				_add_bumper(sibling as StaticBody2D)


func _physics_process(delta: float) -> void:
	tick(delta)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Plans the automatic fires of a race from `seed_value`, puts every part back as it starts a
## race and arms the table.
func reseed(seed_value: int) -> void:
	disarm()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	_launch_rng.seed = rng.randi()
	for side: int in 2:
		var times: PackedFloat32Array = PackedFloat32Array()
		var at: float = rng.randf_range(AUTO_FIRST_MIN, AUTO_FIRST_MAX)
		while at < HORIZON:
			times.append(at)
			at += rng.randf_range(AUTO_MIN, AUTO_MAX)
		_auto_times[side] = times
	_armed = true
	_emit_tally()


## Stops everything and puts the parts back as they start a race.
func disarm() -> void:
	var was_armed: bool = _armed
	_armed = false
	clock = 0.0
	_last_chat = -1000.0
	_launch_in = LAUNCH_DELAY
	_piston = 0.0
	_cooldown = PackedFloat32Array([0.0, 0.0])
	_auto_times = [PackedFloat32Array(), PackedFloat32Array()]
	_auto_next = PackedInt32Array([0, 0])
	_presses = PackedInt32Array([0, 0])
	_names = PackedStringArray()
	_flash.fill(0.0)
	for flipper: PinballFlipper in _flippers:
		flipper.reset()
	queue_redraw()
	if was_armed:
		tally_changed.emit("")


func is_armed() -> bool:
	return _armed


## Fires the flippers of `side` (LEFT or RIGHT) for a viewer. Every press counts on the tally, but
## a side fires at most once per [constant COOLDOWN]. Returns whether the flippers fired.
func fire(side: int, who: String = "") -> bool:
	if not _armed:
		return false
	var index: int = _index(side)
	_presses[index] += 1
	_last_chat = clock
	if not who.is_empty():
		if _names.has(who):
			_names.remove_at(_names.find(who))
		_names.append(who)
		while _names.size() > NAMES_SHOWN:
			_names.remove_at(0)
	_emit_tally()
	return _fire_side(side)


func presses(side: int) -> int:
	return _presses[_index(side)]


func get_flippers() -> Array[PinballFlipper]:
	return _flippers


func bumper_count() -> int:
	return _bumper_centers.size()


## Race seconds of the planned automatic fires of `side`.
func get_schedule(side: int) -> PackedFloat32Array:
	return _auto_times[_index(side)]


## Text of the on-screen tally: presses per side and the latest viewers.
func tally_text() -> String:
	var text: String = "FLIPPERS   #left %d   #right %d" % [_presses[0], _presses[1]]
	if not _names.is_empty():
		text += "\n" + ", ".join(_names)
	return text


func tick(delta: float) -> void:
	if not _armed:
		return
	clock += delta
	for index: int in 2:
		_cooldown[index] = maxf(_cooldown[index] - delta, 0.0)
	_piston = maxf(_piston - delta * 3.0, 0.0)
	for i: int in _flash.size():
		_flash[i] = maxf(_flash[i] - delta / FLASH_SECONDS, 0.0)
	for body: Node2D in _orbit.get_overlapping_bodies():
		if body is Marble:
			(body as Marble).apply_central_force(Vector2(-ORBIT_PUSH, 0.0) * (body as Marble).mass)
	_launch_in -= delta
	if _launch_in <= 0.0:
		_launch_in = RELAUNCH_SECONDS
		launch()
	for index: int in 2:
		var times: PackedFloat32Array = _auto_times[index]
		while _auto_next[index] < times.size() and clock >= times[_auto_next[index]]:
			_auto_next[index] += 1
			if clock - _last_chat >= CHAT_QUIET:
				_fire_side(LEFT if index == 0 else RIGHT)


## Shoots every resting fish in the plunger lane up the lane. Returns how many it launched.
func launch() -> int:
	var launched: int = 0
	for body: Node2D in _plunger.get_overlapping_bodies():
		if not body is Marble:
			continue
		var marble: Marble = body as Marble
		# A fish already on its way up is left alone.
		if marble.linear_velocity.y < -LAUNCH_SPEED * 0.25:
			continue
		var wanted: Vector2 = Vector2(
			_launch_rng.randf_range(-LAUNCH_SIDEWAYS, LAUNCH_SIDEWAYS),
			-LAUNCH_SPEED * (1.0 + _launch_rng.randf_range(-LAUNCH_SPREAD, LAUNCH_SPREAD))
		)
		marble.sleeping = false
		marble.apply_central_impulse((wanted - marble.linear_velocity) * marble.mass)
		launched += 1
	if launched > 0:
		_piston = 1.0
	return launched


## Part of the finish replay ([Replayable]): the clocks and cooldowns, which automatic fires are
## due, the plunger and the glow of every bumper.
func replay_state() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array(
		[
			clock,
			_last_chat,
			_launch_in,
			_piston,
			_cooldown[0],
			_cooldown[1],
			float(_auto_next[0]),
			float(_auto_next[1]),
			1.0 if _armed else 0.0,
		]
	)
	state.append_array(_flash)
	return state


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	clock = Replayable.mix(from, to, weight, 0)
	_last_chat = Replayable.step(from, to, weight, 1)
	_launch_in = Replayable.mix(from, to, weight, 2)
	_piston = Replayable.mix(from, to, weight, 3)
	_cooldown[0] = Replayable.mix(from, to, weight, 4)
	_cooldown[1] = Replayable.mix(from, to, weight, 5)
	_auto_next[0] = int(Replayable.step(from, to, weight, 6))
	_auto_next[1] = int(Replayable.step(from, to, weight, 7))
	_armed = Replayable.step(from, to, weight, 8) > 0.5
	for i: int in _flash.size():
		_flash[i] = Replayable.mix(from, to, weight, 9 + i)
	queue_redraw()


func _index(side: int) -> int:
	return 0 if side < 0 else 1


func _fire_side(side: int) -> bool:
	var index: int = _index(side)
	if _cooldown[index] > 0.0:
		return false
	_cooldown[index] = COOLDOWN
	for flipper: PinballFlipper in _flippers:
		if flipper.side == side:
			flipper.fire()
	return true


func _emit_tally() -> void:
	tally_changed.emit(tally_text())


func _add_bumper(bumper: StaticBody2D) -> void:
	var collider: CollisionShape2D = bumper.get_node_or_null("Collider") as CollisionShape2D
	if collider == null or not collider.shape is CircleShape2D:
		return
	var radius: float = (collider.shape as CircleShape2D).radius
	var area: Area2D = Area2D.new()
	var zone: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius + BUMPER_PAD
	zone.shape = circle
	area.add_child(zone)
	area.position = to_local(collider.global_position)
	add_child(area)
	var index: int = _bumper_centers.size()
	_bumper_centers.append(area.position)
	_bumper_radii.append(radius)
	_flash.append(0.0)
	area.body_entered.connect(_on_bumper_entered.bind(index))


func _on_bumper_entered(body: Node2D, index: int) -> void:
	# Switched off while the finish replay plays, when the marbles only show the recording.
	if not _armed or not is_physics_processing() or not body is Marble:
		return
	var marble: Marble = body as Marble
	var away: Vector2 = marble.global_position - to_global(_bumper_centers[index])
	if away.length_squared() < 0.01:
		away = Vector2.UP
	var direction: Vector2 = away.normalized()
	# A fish already leaving fast is left alone; one arriving is sent back out at full speed.
	var gain: float = POP_SPEED - marble.linear_velocity.dot(direction)
	if gain > 0.0:
		marble.sleeping = false
		marble.apply_central_impulse(direction * gain * marble.mass)
	_flash[index] = 1.0


func _draw() -> void:
	for i: int in _flash.size():
		var glow: float = _flash[i]
		if glow <= 0.0:
			continue
		var center: Vector2 = _bumper_centers[i]
		var radius: float = _bumper_radii[i]
		draw_circle(center, radius + 6.0, Color(GLOW, glow * 0.45))
		draw_arc(
			center, radius + 8.0 + (1.0 - glow) * 26.0, 0.0, TAU, 36, Color(GLOW, glow), 4.0, true
		)
	_draw_plunger()


## The spring under the launch lane, squashed and glowing when the plunger fires, and chevrons
## in the lane that run upward.
func _draw_plunger() -> void:
	var x: float = _plunger_rect.get_center().x
	var floor_y: float = _plunger_rect.end.y
	var squash: float = SPRING_LENGTH * (1.0 - 0.45 * _piston)
	var points: PackedVector2Array = PackedVector2Array([Vector2(x, floor_y)])
	for step: int in 8:
		var zig: float = 16.0 if step % 2 == 0 else -16.0
		points.append(Vector2(x + zig, floor_y + 6.0 + squash * float(step + 1) / 9.0))
	points.append(Vector2(x, floor_y + squash))
	draw_polyline(points, Color(GLOW, 0.55 + 0.4 * _piston), 4.0, true)
	if _piston > 0.0:
		draw_rect(
			Rect2(_plunger_rect.position.x, floor_y - 60.0, _plunger_rect.size.x, 60.0),
			Color(GLOW, _piston * 0.35)
		)
	for row: int in 4:
		var phase: float = fposmod(_time * 0.8 - float(row) * 0.25, 1.0)
		var y: float = floor_y - 90.0 - float(row) * 110.0
		draw_polyline(
			PackedVector2Array(
				[Vector2(x - 22.0, y + 14.0), Vector2(x, y - 6.0), Vector2(x + 22.0, y + 14.0)]
			),
			Color(GLOW, 0.06 + 0.22 * phase),
			5.0,
			true
		)
