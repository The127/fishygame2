class_name Race
extends Node2D
## Spawns marbles on a track, tracks the finish order and emits results.

signal marble_finished(id: int, place: int)
signal race_finished(results: Array[Dictionary])
## The winner just crossed with `chaser_id` about to follow. Visual cue only.
signal photo_finish(winner_id: int, chaser_id: int)

const SPAWN_JITTER: float = 3.0
## Impulse per unit of mass with which the streamer's hook yanks a fish back up the track.
const HOOK_IMPULSE: float = 650.0
## Fraction of its speed a hooked fish keeps before it is pulled back.
const HOOK_KEEP_SPEED: float = 0.2
## Impulse per unit of mass a bubble blast gives a fish at its centre, fading to the edge.
const BLAST_IMPULSE: float = 600.0
## Drag per second on a fish inside a net, in units of its own velocity.
const NET_DRAG: float = 14.0

@export var marble_scene: PackedScene
@export var timeout_seconds: float = 90.0

var elapsed: float = 0.0
var running: bool = false

var _track: Track
var _ranking: RaceRanking
var _marbles: Dictionary = {}
var _nets: Array[NetZone] = []


## Clears any previous race and spawns `count` marbles. Every random draw comes
## from the given rng. `hazard_frequency` (1 to 5) turns on the map's hazard events, 0 leaves them off.
func start(track: Track, count: int, rng: RandomNumberGenerator, hazard_frequency: int = 0) -> void:
	assert(marble_scene != null and count > 0, "Race needs a marble_scene and count > 0")
	clear()
	_track = track
	_track.marble_reached_finish.connect(_on_marble_reached_finish)
	var ids: Array[int] = []
	for i: int in count:
		ids.append(i)
		var marble: Marble = marble_scene.instantiate() as Marble
		marble.id = i
		var jitter: Vector2 = Vector2(
			rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER),
			rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER)
		)
		marble.glow_boost = _track.fish_glow
		add_child(marble)
		marble.global_position = _track.get_spawn_position(i) + jitter
		_marbles[i] = marble
	_ranking = RaceRanking.new(ids)
	_track.seed_gimmicks(rng)
	_track.arm_hazards(rng, hazard_frequency)
	elapsed = 0.0
	running = true


func clear() -> void:
	running = false
	if _track != null:
		_track.stop_hazards()
		_track.stop_gimmicks()
	if _track != null and _track.marble_reached_finish.is_connected(_on_marble_reached_finish):
		_track.marble_reached_finish.disconnect(_on_marble_reached_finish)
	_track = null
	_ranking = null
	for net: NetZone in _nets:
		if is_instance_valid(net):
			remove_child(net)
			net.queue_free()
	_nets.clear()
	for marble: Marble in _marbles.values():
		# Leave the tree now so a stale marble can't trigger the finish area this frame.
		remove_child(marble)
		marble.queue_free()
	_marbles.clear()


func get_marbles() -> Array[Marble]:
	var result: Array[Marble] = []
	for marble: Marble in _marbles.values():
		result.append(marble)
	return result


## Pushes a marble toward the finish. Returns false if the race is not running or the id is unknown.
func boost_marble(id: int) -> bool:
	var marble: Marble = _live_marble(id)
	if marble == null:
		return false
	marble.boost(_track.get_forward(marble.global_position))
	return true


## Knocks a marble back and slows it. Returns false if the race is not running or the id is unknown.
func curse_marble(id: int) -> bool:
	var marble: Marble = _live_marble(id)
	if marble == null:
		return false
	marble.curse(_track.get_forward(marble.global_position))
	return true


## Gives a marble a small cheering nudge toward the finish. `strength` is in emote units.
## Returns false if the race is not running or the id is unknown.
func cheer_marble(id: int, strength: float) -> bool:
	var marble: Marble = _live_marble(id)
	if marble == null:
		return false
	marble.cheer(_track.get_forward(marble.global_position), strength)
	return true


## Makes a marble meow, purely for show. Returns false if the race is not running or the id is unknown.
func meow_marble(id: int) -> bool:
	if not running or not _marbles.has(id):
		return false
	(_marbles[id] as Marble).meow()
	return true


## The streamer's fishing rod: drops a hook at `pos` and yanks the nearest fish within
## `radius` back up the track. Returns that fish's id, or -1 if the race is not running
## or no fish is in reach (the hook still drops).
func hook_near(pos: Vector2, radius: float) -> int:
	if not running:
		return -1
	var hook: HookFx = HookFx.new()
	add_child(hook)
	hook.global_position = pos
	var marble: Marble = _nearest_live(pos, radius)
	if marble == null:
		return -1
	marble.linear_velocity *= HOOK_KEEP_SPEED
	marble.apply_central_impulse(
		-_track.get_forward(marble.global_position) * HOOK_IMPULSE * marble.mass
	)
	RaceFx.burst(marble, marble.global_position, RaceFx.SPLASH_COLOR, 12, 100.0, Vector2(0, -60))
	return marble.id


## The streamer's net: holds fish inside the area for `seconds`. Returns how many fish are in
## it now (fish that swim in later are held too). Does nothing if the race is not running.
func place_net(pos: Vector2, radius: float, seconds: float) -> int:
	if not running:
		return 0
	var net: NetZone = NetZone.new()
	net.radius = radius
	net.life = seconds
	add_child(net)
	net.global_position = pos
	_nets.append(net)
	return _live_in(pos, radius).size()


## The streamer's bubble blast: shoves every fish within `radius` away from `pos`, hardest
## at the centre. Returns how many fish it hit.
func blast(pos: Vector2, radius: float) -> int:
	if not running:
		return 0
	var hit: Array[Marble] = _live_in(pos, radius)
	for marble: Marble in hit:
		var away: Vector2 = marble.global_position - pos
		var direction: Vector2 = away.normalized() if away.length() > 0.001 else Vector2.UP
		var falloff: float = 1.0 - clampf(away.length() / radius, 0.0, 1.0) * 0.6
		marble.apply_central_impulse(direction * BLAST_IMPULSE * falloff * marble.mass)
	RaceFx.burst(self, pos, RaceFx.BOOST_COLOR, 28, radius, Vector2.ZERO)
	return hit.size()


## Current global position of every marble still racing, id -> Vector2.
func get_position_map() -> Dictionary:
	var positions: Dictionary = {}
	for id: int in _marbles:
		if _ranking != null and _ranking.is_finished(id):
			continue
		var marble: Marble = _marbles[id]
		positions[id] = marble.global_position
	return positions


func get_progress_map() -> Dictionary:
	var progress: Dictionary = {}
	for id: int in _marbles:
		var marble: Marble = _marbles[id]
		progress[id] = _track.get_progress(marble.global_position)
	return progress


## The marble with this id if it is still racing (not yet finished), else null.
func _live_marble(id: int) -> Marble:
	if not running or _ranking == null or not _marbles.has(id):
		return null
	if _ranking.is_finished(id):
		return null
	return _marbles[id]


func _nearest_live(pos: Vector2, radius: float) -> Marble:
	var best: Marble = null
	var best_distance: float = radius
	for marble: Marble in _live_in(pos, radius):
		var distance: float = marble.global_position.distance_to(pos)
		if best == null or distance < best_distance:
			best = marble
			best_distance = distance
	return best


func _live_in(pos: Vector2, radius: float) -> Array[Marble]:
	var found: Array[Marble] = []
	for id: int in _marbles:
		var marble: Marble = _live_marble(id)
		if marble != null and marble.global_position.distance_to(pos) <= radius:
			found.append(marble)
	return found


func _hold_in_nets() -> void:
	_nets = _nets.filter(func(net: NetZone) -> bool: return is_instance_valid(net))
	for net: NetZone in _nets:
		for marble: Marble in _live_in(net.global_position, net.radius):
			marble.apply_central_force(
				-marble.linear_velocity * NET_DRAG * marble.mass * net.strength()
			)


func _physics_process(delta: float) -> void:
	if not running:
		return
	_hold_in_nets()
	elapsed += delta
	if elapsed >= timeout_seconds:
		_finish_race()


func _on_marble_reached_finish(body: Node2D) -> void:
	if not running or _ranking == null or not body is Marble:
		return
	var marble: Marble = body as Marble
	if _marbles.get(marble.id) != marble:
		return
	var place: int = _ranking.record_finish(marble.id, elapsed)
	if place == 0:
		return
	marble.splash()
	if place == 1:
		marble.celebrate()
	marble_finished.emit(marble.id, place)
	if place == 1:
		_check_photo_finish(marble.id)
	if _ranking.all_finished():
		_finish_race()


## Emits photo_finish when another marble is about to cross right behind the winner.
## Reads state only, so it cannot change the outcome.
func _check_photo_finish(winner_id: int) -> void:
	var finish: Vector2 = _track.get_finish_position()
	var chaser_id: int = -1
	var best_eta: float = INF
	for id: int in _marbles:
		if id == winner_id or _ranking.is_finished(id):
			continue
		var marble: Marble = _marbles[id]
		var distance: float = marble.global_position.distance_to(finish)
		var to_finish: Vector2 = finish - marble.global_position
		# Only the speed toward the gate counts, not sideways or backwards motion.
		var speed: float = maxf(0.0, marble.linear_velocity.dot(to_finish.normalized()))
		if PhotoFinish.is_close(distance, speed) and PhotoFinish.eta(distance, speed) < best_eta:
			best_eta = PhotoFinish.eta(distance, speed)
			chaser_id = id
	if chaser_id >= 0:
		photo_finish.emit(winner_id, chaser_id)


func _finish_race() -> void:
	running = false
	_track.stop_hazards()
	for marble: Marble in _marbles.values():
		marble.set_deferred("freeze", true)
	var results: Array[Dictionary] = _ranking.get_results(get_progress_map())
	race_finished.emit(results)
