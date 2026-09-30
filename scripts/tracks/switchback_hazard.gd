class_name SwitchbackHazard
extends Hazard
## Backwash: a surge of water tips one ramp (a [SwitchbackRamp] child) against its slope for a
## few seconds without any fish touching its trigger. The telegraph makes that ramp shudder and
## glow. The hazard also owns the map's permanent gimmick: it plans every ramp's trigger for
## the race in [method reseed], whatever the hazard setting is.

var _ramps: Array[SwitchbackRamp] = []
var _chosen: int = -1


func _ready() -> void:
	for child: Node in get_children():
		if child is SwitchbackRamp:
			_ramps.append(child as SwitchbackRamp)


## Plans the triggers of every ramp from `seed_value`. Called by the track before each race.
func reseed(seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for ramp: SwitchbackRamp in _ramps:
		ramp.arm(rng.randi())


## Puts every ramp back at its resting slope.
func stop_gimmick() -> void:
	for ramp: SwitchbackRamp in _ramps:
		ramp.disarm()


func get_ramps() -> Array[SwitchbackRamp]:
	return _ramps


## Index of the ramp the running event targets, -1 when idle.
func chosen_index() -> int:
	return _chosen


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	if _ramps.is_empty():
		return
	_chosen = rng.randi_range(0, _ramps.size() - 1)


func _process_telegraph(_delta: float) -> void:
	if _chosen >= 0:
		_ramps[_chosen].set_alarm(phase_progress())


func _begin_active() -> void:
	if _chosen >= 0:
		_ramps[_chosen].set_alarm(0.0)
		_ramps[_chosen].set_forced(true)


func _end_event() -> void:
	_release()


func _reset() -> void:
	_release()


func _release() -> void:
	if _chosen >= 0:
		_ramps[_chosen].set_alarm(0.0)
		_ramps[_chosen].set_forced(false)
	_chosen = -1


func _replay_extra() -> PackedFloat32Array:
	return PackedFloat32Array([float(_chosen)])


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_chosen = int(Replayable.step(from, to, weight, REPLAY_BASE))
