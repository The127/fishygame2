class_name RacePowers
extends RefCounted
## The marble-targeting actions of a [Race]: boost, curse, cheer, hook, net and blast.
## Owned by the Race, which hands it the live-marble lookup and the recording hook.

## Impulse per unit of mass with which the streamer's hook yanks a fish back up the track.
const HOOK_IMPULSE: float = 650.0
## Fraction of its speed a hooked fish keeps before it is pulled back.
const HOOK_KEEP_SPEED: float = 0.2
## Impulse per unit of mass a bubble blast gives a fish at its centre, fading to the edge.
const BLAST_IMPULSE: float = 600.0
## Drag per second on a fish inside a net, in units of its own velocity.
const NET_DRAG: float = 14.0

## The track of the race in progress. Set by the Race on start.
var track: Track
var nets: Array[NetZone] = []

var _host: Node2D
var _marbles: Dictionary
## Callable(id: int) -> Marble, null when the fish is not racing.
var _live_marble: Callable
## Callable(kind: ReplayRecorder.Kind, marble: Marble) -> void.
var _record_event: Callable


func _init(
	host: Node2D, marbles: Dictionary, live_marble: Callable, record_event: Callable
) -> void:
	_host = host
	_marbles = marbles
	_live_marble = live_marble
	_record_event = record_event


## Removes every net.
func clear() -> void:
	for net: NetZone in nets:
		if is_instance_valid(net):
			_host.remove_child(net)
			net.queue_free()
	nets.clear()


func boost(id: int) -> bool:
	var marble: Marble = _live_marble.call(id)
	if marble == null:
		return false
	_record_event.call(ReplayRecorder.Kind.BOOST, marble)
	marble.boost(track.get_forward(marble.global_position))
	return true


func curse(id: int) -> bool:
	var marble: Marble = _live_marble.call(id)
	if marble == null:
		return false
	_record_event.call(ReplayRecorder.Kind.CURSE, marble)
	marble.curse(track.get_forward(marble.global_position))
	return true


func cheer(id: int, strength: float) -> bool:
	var marble: Marble = _live_marble.call(id)
	if marble == null:
		return false
	marble.cheer(track.get_forward(marble.global_position), strength)
	return true


## Drops a hook at `pos` and yanks the nearest fish within `radius`. Returns its id or -1.
func hook_near(pos: Vector2, radius: float) -> int:
	var hook: HookFx = HookFx.new()
	_host.add_child(hook)
	hook.global_position = pos
	var marble: Marble = _nearest_live(pos, radius)
	if marble == null:
		return -1
	marble.linear_velocity *= HOOK_KEEP_SPEED
	marble.apply_central_impulse(
		-track.get_forward(marble.global_position) * HOOK_IMPULSE * marble.mass
	)
	RaceFx.burst(marble, marble.global_position, RaceFx.SPLASH_COLOR, 12, 100.0, Vector2(0, -60))
	return marble.id


## Drops a net; returns how many fish are inside it now.
func place_net(pos: Vector2, radius: float, seconds: float) -> int:
	var net: NetZone = NetZone.new()
	net.radius = radius
	net.life = seconds
	_host.add_child(net)
	net.global_position = pos
	nets.append(net)
	return live_in(pos, radius).size()


## Shoves every fish within `radius` away from `pos`; returns how many it hit.
func blast(pos: Vector2, radius: float) -> int:
	var hit: Array[Marble] = live_in(pos, radius)
	for marble: Marble in hit:
		var away: Vector2 = marble.global_position - pos
		var direction: Vector2 = away.normalized() if away.length() > 0.001 else Vector2.UP
		var falloff: float = 1.0 - clampf(away.length() / radius, 0.0, 1.0) * 0.6
		marble.apply_central_impulse(direction * BLAST_IMPULSE * falloff * marble.mass)
	RaceFx.burst(_host, pos, RaceFx.BOOST_COLOR, 28, radius, Vector2.ZERO)
	return hit.size()


## Slows every fish inside a net. Called once per physics step.
func hold_in_nets() -> void:
	nets = nets.filter(func(net: NetZone) -> bool: return is_instance_valid(net))
	for net: NetZone in nets:
		for marble: Marble in live_in(net.global_position, net.radius):
			marble.apply_central_force(
				-marble.linear_velocity * NET_DRAG * marble.mass * net.strength()
			)


## Every racing fish within `radius` of `pos`.
func live_in(pos: Vector2, radius: float) -> Array[Marble]:
	var found: Array[Marble] = []
	for id: int in _marbles:
		var marble: Marble = _live_marble.call(id)
		if marble != null and marble.global_position.distance_to(pos) <= radius:
			found.append(marble)
	return found


func _nearest_live(pos: Vector2, radius: float) -> Marble:
	var best: Marble = null
	var best_distance: float = radius
	for marble: Marble in live_in(pos, radius):
		var distance: float = marble.global_position.distance_to(pos)
		if best == null or distance < best_distance:
			best = marble
			best_distance = distance
	return best
