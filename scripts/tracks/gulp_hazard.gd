class_name GulpHazard
extends Hazard
## The whale gulps. The telegraph is the mouth in the background yawning wide; then a rush of
## water drags sea junk (barrels, crates, planks) in through the top of the map, and it tumbles
## down the throat behind the fish as real bodies that bump them. Junk that falls into an acid
## pit dissolves, and anything else fizzles out after a few seconds, so nothing can clog the map.
##
## The junk is a small pool of [GulpDebris] bodies created once, so a gulp never allocates in a
## race. Everything is drawn from the race seed and the pool is part of the finish replay.

signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)
## How wide the whale yawns, 0 to 1. The mouth in the background listens.
signal yawn_changed(amount: float)

const KIND: String = "gulp"
const POOL_SIZE: int = 6
## Seconds a piece of junk stays in the race before it fizzles away.
const LIFETIME: float = 10.0
## Pieces a gulp brings, at least and at most.
const MIN_PIECES: int = 3
const MAX_PIECES: int = 5
## Seconds it takes the mouth to open and to close again.
const YAWN_IN: float = 1.2
const YAWN_OUT: float = 1.0
## Floats per pool slot in the replay state: active, x, y, angle, kind, age.
const SLOT_FLOATS: int = 6
const FIZZLE_COLOR: Color = Color(0.85, 0.7, 0.45)

## Where the junk comes in: a box (world rectangle) above the start of the throat.
@export var entry: Rect2 = Rect2(70.0, -150.0, 150.0, 40.0)
## Velocity the water gives the junk as it comes in.
@export var rush: Vector2 = Vector2(260.0, 90.0)

var _pool: Array[GulpDebris] = []
var _yawn: float = 0.0
## Race seconds (of the active phase) at which each planned piece comes in, and what it is.
var _arrivals: Array[float] = []
var _kinds: Array[int] = []
var _spots: Array[Vector2] = []
var _next_arrival: int = 0
var _ages: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_ages.resize(POOL_SIZE)
	for i: int in POOL_SIZE:
		var piece: GulpDebris = GulpDebris.new()
		piece.name = "Debris%d" % (i + 1)
		add_child(piece)
		_pool.append(piece)


## How many pieces of junk are in the race right now.
func active_count() -> int:
	var count: int = 0
	for piece: GulpDebris in _pool:
		if piece.is_active:
			count += 1
	return count


func get_pool() -> Array[GulpDebris]:
	return _pool


func _physics_process(delta: float) -> void:
	super(delta)
	_update_yawn(delta)
	_update_debris(delta)


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	_arrivals.clear()
	_kinds.clear()
	_spots.clear()
	_next_arrival = 0
	var count: int = rng.randi_range(MIN_PIECES, MAX_PIECES)
	for i: int in count:
		_arrivals.append(rng.randf_range(0.0, active_seconds * 0.7))
		_kinds.append(rng.randi_range(0, GulpDebris.Kind.size() - 1))
		_spots.append(
			entry.position + Vector2(rng.randf() * entry.size.x, rng.randf() * entry.size.y)
		)
	_arrivals.sort()


func _process_active(_delta: float) -> void:
	while _next_arrival < _arrivals.size() and phase_time >= _arrivals[_next_arrival]:
		_bring_in(_kinds[_next_arrival], _spots[_next_arrival])
		_next_arrival += 1


func _reset() -> void:
	_arrivals.clear()
	_kinds.clear()
	_spots.clear()
	_next_arrival = 0
	_yawn = 0.0
	yawn_changed.emit(_yawn)
	for piece: GulpDebris in _pool:
		piece.deactivate()
	_ages.fill(0.0)


func _bring_in(piece_kind: int, spot: Vector2) -> void:
	for i: int in _pool.size():
		var piece: GulpDebris = _pool[i]
		if piece.is_active:
			continue
		# The junk comes in turning, a little differently every time.
		var angle: float = float(piece_kind) * 0.9 + spot.x * 0.05
		piece.activate(piece_kind as GulpDebris.Kind, spot, rush, angle)
		piece.angular_velocity = 3.0 if int(spot.x) % 2 == 0 else -3.0
		_ages[i] = 0.0
		return


func _update_yawn(delta: float) -> void:
	var target: float = 1.0 if phase != Phase.IDLE else 0.0
	var rate: float = delta / (YAWN_IN if target > _yawn else YAWN_OUT)
	var next: float = move_toward(_yawn, target, rate)
	if next != _yawn:
		_yawn = next
		yawn_changed.emit(_yawn)


func _update_debris(delta: float) -> void:
	for i: int in _pool.size():
		var piece: GulpDebris = _pool[i]
		if not piece.is_active:
			continue
		_ages[i] += delta
		var out_of_bounds: bool = piece.global_position.y > 1400.0
		if piece.fizzling or _ages[i] >= LIFETIME or out_of_bounds:
			_fizzle(piece)


func _fizzle(piece: GulpDebris) -> void:
	var at: Vector2 = piece.global_position
	piece.deactivate()
	RaceFx.burst(self, at, FIZZLE_COLOR, 14, 110.0, Vector2(0.0, 30.0))
	burst_played.emit(at, FIZZLE_COLOR, 14, 110.0, Vector2(0.0, 30.0))


## Replay: the yawn and every pool slot. A slot that is off holds only zeros, so its state does not
## depend on where the switched-off body happens to sit.
func _replay_extra() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array([_yawn])
	for i: int in _pool.size():
		var piece: GulpDebris = _pool[i]
		if not piece.is_active:
			state.append_array(PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0]))
			continue
		state.append_array(
			PackedFloat32Array(
				[
					1.0,
					piece.global_position.x,
					piece.global_position.y,
					piece.rotation,
					float(piece.kind),
					_ages[i]
				]
			)
		)
	return state


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_yawn = Replayable.mix(from, to, weight, REPLAY_BASE)
	for i: int in _pool.size():
		var piece: GulpDebris = _pool[i]
		var base: int = REPLAY_BASE + 1 + i * SLOT_FLOATS
		var on: bool = Replayable.step(from, to, weight, base) > 0.5
		piece.is_active = on
		piece.visible = on
		if not on:
			continue
		var shown: GulpDebris.Kind = (
			int(Replayable.step(from, to, weight, base + 4)) as GulpDebris.Kind
		)
		if piece.kind != shown:
			piece.show_as(shown)
		piece.global_position = Replayable.mix_vector(from, to, weight, base + 1)
		piece.rotation = lerp_angle(from[base + 3], to[base + 3], weight)
		_ages[i] = Replayable.mix(from, to, weight, base + 5)


## Replay: the live bodies stand still while the clip plays.
func replay_begin() -> void:
	for piece: GulpDebris in _pool:
		piece.freeze = true
		piece.collision_layer = 0
		piece.collision_mask = 0


## Replay over: the pool goes back to what the race left (nothing, it is cleared then).
func replay_end() -> void:
	for piece: GulpDebris in _pool:
		if not piece.is_active:
			piece.deactivate()
