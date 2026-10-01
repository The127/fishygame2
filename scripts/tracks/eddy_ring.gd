class_name EddyRing
extends Hazard
## The still lagoon in the middle of Riptide Rounds, where the fish cut from the race wait as
## ghosts, and the eddies they send back out. A cut fish is flushed out of the channel into the
## lagoon and bobs there. On request (see [method drop]) its ghost flies out to a spot on the
## course, where it spins for a few seconds as an eddy: a small whirlpool that catches the fish
## passing through, slows them and flings them about. Then it drifts home. Only a few eddies can
## spin at once.
##
## The map's hazard is the restless ghost: now and then one ghost starts to tremble and glow, and
## then breaks loose and spins up an eddy on its own (see [signal restless]), so the course is
## haunted even when chat is quiet. Hazard settings turn it off or change how often it happens.
##
## The ghosts are the cut fish themselves (frozen [Marble]s this node moves), so the finish
## replay shows them from the fish samples. The swirls are drawn from state this node records.

## A ghost broke loose. The race decides where its eddy lands.
signal restless(marble: Marble)

## How many eddies can spin at the same time.
const MAX_EDDIES: int = 3
## Seconds an eddy spins, and how wide it reaches.
const EDDY_SECONDS: float = 5.0
const EDDY_RADIUS: float = 82.0
## Seconds a ghost needs to fly out to the course, to come home and to be drained from the channel.
const FLIGHT_SECONDS: float = 0.9
const HOME_SECONDS: float = 1.4
const DRAIN_SECONDS: float = 1.1
## Seconds an eddy takes to swell and to die away.
const SWELL_SECONDS: float = 0.5
const FADE_SECONDS: float = 0.9
## Strength of the swirl: the speed it spins a fish up to, how fast a fish follows it, the pull
## toward the middle and the damping of motion in and out.
const SWIRL_SPEED: float = 330.0
const SWIRL_GAIN: float = 6.5
const PULL: float = 520.0
const RADIAL_DAMP: float = 1.4
const COLOR: Color = Color(0.55, 0.9, 1.0)
## Where an idle eddy's area waits, far from any fish.
const PARKED: Vector2 = Vector2(-9000.0, -9000.0)
## Floats the replay records for each eddy, and before them (after [constant Hazard.REPLAY_BASE]).
const EDDY_FLOATS: int = 4
const HEADER_FLOATS: int = 2
## How hard a restless ghost trembles at the end of its warning, in pixels.
const TREMBLE: float = 7.0

## Where the ghosts wait, in this node's space. Set by the map.
@export var lagoon: Rect2 = Rect2(460.0, 290.0, 1000.0, 500.0)
@export var hint_font_size: int = 46

var _ghosts: Array[LagoonGhost] = []
var _zones: Array[Area2D] = []
var _eddy_ghost: Array[LagoonGhost] = []
var _eddy_pos: PackedVector2Array = PackedVector2Array()
var _eddy_env: PackedFloat32Array = PackedFloat32Array()
var _eddy_turn: PackedFloat32Array = PackedFloat32Array()
var _eddy_spin: PackedFloat32Array = PackedFloat32Array()
var _drops: int = 0
var _clock: float = 0.0
## The ghost that is about to break loose, or null.
var _restless: LagoonGhost = null
## Ghosts to show the hint for while a replay plays.
var _shown_ghosts: int = 0


func _ready() -> void:
	z_index = -1
	# The finish replay records the swirls too; the hazard joins it already.
	for i: int in MAX_EDDIES:
		var zone: Area2D = Area2D.new()
		var shape: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = EDDY_RADIUS
		shape.shape = circle
		zone.add_child(shape)
		zone.position = PARKED
		add_child(zone)
		_zones.append(zone)
		_eddy_ghost.append(null)
		_eddy_pos.append(PARKED)
		_eddy_env.append(0.0)
		_eddy_turn.append(0.0)
		_eddy_spin.append(1.0)


## Takes in a fish that has left the course (see [method Marble.eliminate] and
## [method Marble.retire]): it is drained from where it lies into the lagoon. A `victor` finished
## the race: it waits there too but has no eddy to send.
func add_ghost(marble: Marble, victor: bool = false) -> void:
	var ghost: LagoonGhost = LagoonGhost.new()
	ghost.marble = marble
	ghost.victor = victor
	ghost.home = _home_of(_ghosts.size())
	ghost.phase = float(marble.id) * 1.7
	ghost.from = marble.global_position
	_ghosts.append(ghost)


## Cut fish waiting in the lagoon.
func ghost_count() -> int:
	var count: int = 0
	for ghost: LagoonGhost in _ghosts:
		if not ghost.victor:
			count += 1
	return count


## Eddies that are out on the course, flying there or spinning.
func eddy_count() -> int:
	var count: int = 0
	for ghost: LagoonGhost in _eddy_ghost:
		if ghost != null:
			count += 1
	return count


## Why `marble`'s ghost cannot send out an eddy now: "no_ghost" (the fish was not cut), "busy"
## (its ghost is already out) or "full" (enough eddies are out). Empty when it can.
func blocker(marble: Marble) -> String:
	var ghost: LagoonGhost = _ghost_of(marble)
	if ghost == null or ghost.victor:
		return "no_ghost"
	if ghost.mode == LagoonGhost.Mode.FLIGHT or ghost.mode == LagoonGhost.Mode.SPIN:
		return "busy"
	if eddy_count() >= MAX_EDDIES:
		return "full"
	return ""


## The ghost of `marble` flies out to `at` (global) and spins there as an eddy. Returns false
## when it cannot (see [method blocker]).
func drop(marble: Marble, at: Vector2) -> bool:
	if blocker(marble) != "":
		return false
	var ghost: LagoonGhost = _ghost_of(marble)
	var slot: int = _eddy_ghost.find(null)
	_drops += 1
	ghost.eddy = slot
	ghost.mode = LagoonGhost.Mode.FLIGHT
	ghost.time = 0.0
	ghost.from = marble.global_position
	ghost.to = at
	_eddy_ghost[slot] = ghost
	_eddy_pos[slot] = at
	_eddy_spin[slot] = 1.0 if _drops % 2 == 1 else -1.0
	return true


## Ends every eddy and sends the ghosts home. The race calls it when it is over.
func settle() -> void:
	for ghost: LagoonGhost in _ghosts:
		if ghost.mode == LagoonGhost.Mode.FLIGHT or ghost.mode == LagoonGhost.Mode.SPIN:
			_go_home(ghost)


## Forgets every ghost and eddy, for the next race.
func stop_gimmick() -> void:
	_restless = null
	_ghosts.clear()
	_drops = 0
	_clock = 0.0
	for i: int in MAX_EDDIES:
		_eddy_ghost[i] = null
		_eddy_pos[i] = PARKED
		_eddy_env[i] = 0.0
		_eddy_turn[i] = 0.0
		_zones[i].position = PARKED
	queue_redraw()


func _physics_process(delta: float) -> void:
	super(delta)
	_clock += delta
	for ghost: LagoonGhost in _ghosts:
		_move(ghost, delta)
	for i: int in MAX_EDDIES:
		_update_eddy(i, delta)


func _process(_delta: float) -> void:
	# The finish replay switches physics off and sets the shown count itself.
	if is_physics_processing():
		_shown_ghosts = ghost_count()
	queue_redraw()


func _ghost_of(marble: Marble) -> LagoonGhost:
	for ghost: LagoonGhost in _ghosts:
		if ghost.marble == marble:
			return ghost
	return null


## Resting place number `index`: rows across the lagoon, every other row shifted half a cell.
## Past the last slot, fish share one and only differ in where they bob.
func _home_of(index: int) -> Vector2:
	var columns: int = 6
	var rows: int = 3
	var slot: int = index % (columns * rows)
	var row: int = slot / columns
	var column: int = slot % columns
	var cell_width: float = lagoon.size.x / (float(columns) + 0.5)
	var shift: float = 0.5 if row % 2 == 1 else 0.0
	var x: float = lagoon.position.x + cell_width * (float(column) + 0.5 + shift)
	var y: float = lagoon.position.y + lagoon.size.y * (float(row) + 0.5) / float(rows)
	return to_global(Vector2(x, y))


func _hover(ghost: LagoonGhost) -> Vector2:
	var t: float = _clock
	var at: Vector2 = (
		ghost.home
		+ Vector2(sin(t * 0.8 + ghost.phase) * 16.0, sin(t * 1.2 + ghost.phase * 1.7) * 10.0)
	)
	if ghost == _restless and phase == Phase.TELEGRAPH:
		var shake: float = TREMBLE * phase_progress()
		at += Vector2(sin(t * 53.0), cos(t * 47.0)) * shake
	return at


func _move(ghost: LagoonGhost, delta: float) -> void:
	ghost.time += delta
	var marble: Marble = ghost.marble
	var pos: Vector2 = marble.global_position
	match ghost.mode:
		LagoonGhost.Mode.DRAIN:
			var t: float = clampf(ghost.time / DRAIN_SECONDS, 0.0, 1.0)
			pos = _arc(ghost.from, _hover(ghost), _ease(t), 70.0)
			if t >= 1.0:
				ghost.mode = LagoonGhost.Mode.IDLE
		LagoonGhost.Mode.IDLE:
			pos = _hover(ghost)
		LagoonGhost.Mode.FLIGHT:
			var t: float = clampf(ghost.time / FLIGHT_SECONDS, 0.0, 1.0)
			pos = _arc(ghost.from, ghost.to, _ease(t), 60.0)
			if t >= 1.0:
				ghost.mode = LagoonGhost.Mode.SPIN
				ghost.time = 0.0
		LagoonGhost.Mode.SPIN:
			pos = ghost.to + Vector2.from_angle(_clock * 7.0 * _eddy_spin[ghost.eddy]) * 11.0
			if ghost.time >= EDDY_SECONDS:
				_go_home(ghost)
		LagoonGhost.Mode.HOME:
			var t: float = clampf(ghost.time / HOME_SECONDS, 0.0, 1.0)
			pos = _arc(ghost.from, _hover(ghost), _ease(t), 50.0)
			if t >= 1.0:
				ghost.mode = LagoonGhost.Mode.IDLE
	if delta > 0.0:
		marble.linear_velocity = (pos - marble.global_position) / delta
	marble.global_position = pos


func _go_home(ghost: LagoonGhost) -> void:
	if ghost.eddy >= 0:
		_eddy_ghost[ghost.eddy] = null
		ghost.eddy = -1
	ghost.mode = LagoonGhost.Mode.HOME
	ghost.time = 0.0
	ghost.from = ghost.marble.global_position


func _update_eddy(index: int, delta: float) -> void:
	var ghost: LagoonGhost = _eddy_ghost[index]
	if ghost == null:
		_eddy_env[index] = maxf(_eddy_env[index] - delta / FADE_SECONDS, 0.0)
		if _eddy_env[index] <= 0.0:
			_zones[index].global_position = PARKED
		return
	var env: float = 0.0
	if ghost.mode == LagoonGhost.Mode.FLIGHT:
		# A faint ring on the spot the ghost is heading for.
		env = 0.25 * clampf(ghost.time / FLIGHT_SECONDS, 0.0, 1.0)
		_zones[index].global_position = PARKED
	else:
		var t: float = ghost.time
		env = minf(0.25 + 0.75 * t / SWELL_SECONDS, minf(1.0, (EDDY_SECONDS - t) / FADE_SECONDS))
		env = clampf(env, 0.0, 1.0)
		_zones[index].global_position = _eddy_pos[index]
		for body: Node2D in _zones[index].get_overlapping_bodies():
			if body is Marble and not (body as Marble).is_out():
				_stir(body as Marble, _eddy_pos[index], _eddy_spin[index], env)
	_eddy_env[index] = env
	_eddy_turn[index] += delta * _eddy_spin[index] * (1.5 + 4.0 * env)


func _stir(marble: Marble, center: Vector2, spin: float, env: float) -> void:
	var offset: Vector2 = marble.global_position - center
	var distance: float = maxf(offset.length(), 1.0)
	var outward: Vector2 = offset / distance
	var around: Vector2 = Vector2(-outward.y, outward.x) * spin
	var reach: float = clampf(distance / EDDY_RADIUS, 0.25, 1.0)
	var accel: Vector2 = -outward * PULL * reach * env
	var speed_around: float = marble.linear_velocity.dot(around)
	accel += around * (SWIRL_SPEED * env - speed_around) * SWIRL_GAIN * env
	accel -= outward * marble.linear_velocity.dot(outward) * RADIAL_DAMP * env
	marble.sleeping = false
	marble.apply_central_force(accel * marble.mass)


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## A point `t` of the way from `a` to `b`, bowed sideways by up to `bow` pixels.
static func _arc(a: Vector2, b: Vector2, t: float, bow: float) -> Vector2:
	var side: Vector2 = (b - a).orthogonal().normalized()
	return a.lerp(b, t) + side * sin(PI * t) * bow


## The ghost that is warning of a break-out picks itself when the telegraph begins.
func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	var calm: Array[LagoonGhost] = []
	for ghost: LagoonGhost in _ghosts:
		if not ghost.victor and ghost.mode == LagoonGhost.Mode.IDLE:
			calm.append(ghost)
	_restless = calm[rng.randi_range(0, calm.size() - 1)] if not calm.is_empty() else null


func _process_telegraph(_delta: float) -> void:
	if _restless != null and is_instance_valid(_restless.marble):
		# A quickening flicker, so the eye goes to it.
		var pulse: float = 0.5 + 0.5 * sin(_clock * (12.0 + 18.0 * phase_progress()))
		_restless.marble.modulate.a = lerpf(Marble.GHOST_ALPHA, 1.0, pulse * phase_progress())


func _begin_active() -> void:
	var ghost: LagoonGhost = _restless
	_restless = null
	if ghost != null and ghost.mode == LagoonGhost.Mode.IDLE:
		ghost.marble.modulate.a = Marble.GHOST_ALPHA
		restless.emit(ghost.marble)


func _end_event() -> void:
	_calm_restless()


func _reset() -> void:
	_calm_restless()


func _calm_restless() -> void:
	if _restless != null and is_instance_valid(_restless.marble):
		_restless.marble.modulate.a = Marble.GHOST_ALPHA
	_restless = null


## Records the clock, how many ghosts wait and each eddy's strength, place and turn.
func _replay_extra() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array([_clock, float(_shown_ghosts)])
	for i: int in MAX_EDDIES:
		state.append_array(
			PackedFloat32Array([_eddy_env[i], _eddy_pos[i].x, _eddy_pos[i].y, _eddy_turn[i]])
		)
	return state


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_clock = Replayable.mix(from, to, weight, REPLAY_BASE)
	_shown_ghosts = int(Replayable.step(from, to, weight, REPLAY_BASE + 1))
	for i: int in MAX_EDDIES:
		var base: int = REPLAY_BASE + HEADER_FLOATS + i * EDDY_FLOATS
		_eddy_env[i] = Replayable.mix(from, to, weight, base)
		_eddy_pos[i] = Vector2(
			Replayable.step(from, to, weight, base + 1), Replayable.step(from, to, weight, base + 2)
		)
		_eddy_turn[i] = Replayable.mix(from, to, weight, base + 3)


func _draw() -> void:
	_draw_lagoon()
	for i: int in MAX_EDDIES:
		if _eddy_env[i] > 0.01:
			_draw_eddy(to_local(_eddy_pos[i]), _eddy_env[i], _eddy_turn[i])


func _draw_lagoon() -> void:
	var box: Rect2 = lagoon
	var pulse: float = 0.5 + 0.5 * sin(_clock * 0.9)
	# A pool of pale light under the ghosts: stacked ellipses, each a little smaller.
	for layer: int in 5:
		var shrink: float = float(layer) * 0.14
		var size: Vector2 = box.size * (1.0 - shrink)
		_ellipse(
			box.get_center(), size * 0.5, Color(COLOR, 0.025 + 0.012 * float(layer) + 0.01 * pulse)
		)
	if _shown_ghosts > 0:
		var font: Font = ThemeDB.fallback_font
		var width: float = box.size.x
		var top: Vector2 = Vector2(box.position.x, box.get_center().y - 6.0)
		draw_string(
			font,
			top,
			"#eddy",
			HORIZONTAL_ALIGNMENT_CENTER,
			width,
			hint_font_size,
			Color(COLOR, 0.18 + 0.1 * pulse)
		)


func _ellipse(at: Vector2, radius: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 48:
		var angle: float = TAU * float(i) / 48.0
		points.append(at + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)


## One eddy: a soft disc, rings and spiral arms that turn, all growing with `env`.
func _draw_eddy(at: Vector2, env: float, turn: float) -> void:
	var radius: float = EDDY_RADIUS * (0.4 + 0.6 * env)
	draw_circle(at, radius, Color(COLOR, 0.07 * env))
	for ring: int in 3:
		var r: float = radius * (0.35 + 0.3 * float(ring))
		draw_arc(at, r, 0.0, TAU, 48, Color(COLOR, 0.25 * env), 2.0, true)
	for arm: int in 3:
		var base: float = turn + TAU * float(arm) / 3.0
		var points: PackedVector2Array = PackedVector2Array()
		for step: int in 18:
			var t: float = float(step) / 17.0
			var r: float = lerpf(radius, radius * 0.12, t)
			points.append(at + Vector2.from_angle(base - t * 2.4) * r)
		draw_polyline(points, Color(COLOR, 0.55 * env), 3.0, true)
	draw_circle(at, 7.0 + 5.0 * env, Color(1.0, 1.0, 1.0, 0.4 * env))
