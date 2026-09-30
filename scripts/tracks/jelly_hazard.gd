class_name JellyHazard
extends Hazard
## The swarm of jellyfish on the jellyfish map. Every jellyfish drifts along its own path all
## the time; the hazard event is a surge that makes them flare up, speed up and kick harder.
## The paths are chosen from the race seed in [method reseed].

## Drift speed multiplier at the height of a surge.
const SURGE_SPEED: float = 2.4
const SURGE_KICK: float = 1.5
## Seconds a surge takes to build and to fade.
const FADE: float = 0.6

var _jellies: Array[Jellyfish] = []
var _level: float = 0.0


func _ready() -> void:
	for child: Node in get_children():
		if child is Jellyfish:
			_jellies.append(child as Jellyfish)
	reseed(1)


func get_jellies() -> Array[Jellyfish]:
	return _jellies


## Gives every jellyfish a new drift path from `seed_value` and restarts the drift.
func reseed(seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for jelly: Jellyfish in _jellies:
		jelly.configure(rng)


## 0 to 1, how strongly a surge is running right now.
func surge_level() -> float:
	return _level


func _physics_process(delta: float) -> void:
	super(delta)
	var glow: float = 0.0
	_level = 0.0
	match phase:
		Phase.TELEGRAPH:
			glow = phase_progress()
		Phase.ACTIVE:
			_level = clampf(minf(phase_time, active_seconds - phase_time) / FADE, 0.0, 1.0)
			glow = 1.0
	for jelly: Jellyfish in _jellies:
		jelly.excite = glow
		jelly.kick_scale = lerpf(1.0, SURGE_KICK, _level)
		jelly.advance(delta, lerpf(1.0, SURGE_SPEED, _level))


func _replay_extra() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array([_level])
	for jelly: Jellyfish in _jellies:
		state.append_array(jelly.snapshot())
	return state


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_level = Replayable.mix(from, to, weight, REPLAY_BASE)
	for i: int in _jellies.size():
		var start: int = REPLAY_BASE + 1 + i * Jellyfish.SNAPSHOT_FLOATS
		_jellies[i].show_snapshot(
			Replayable.blend(from, to, weight, start, Jellyfish.SNAPSHOT_FLOATS)
		)
		_jellies[i].kick_scale = lerpf(1.0, SURGE_KICK, _level)


func _reset() -> void:
	_level = 0.0
	for jelly: Jellyfish in _jellies:
		jelly.excite = 0.0
		jelly.kick_scale = 1.0
