class_name CoralHazard
extends Hazard
## The Coral Garden's living coral. Its children are [CoralBed]s, one per opening in a lane that
## coral can grow shut. The first fish into a bed's trigger zone wakes it: the polyps glow, then the
## coral grows across the opening and stays there until the race is over. So the lane the leader
## used closes behind it, and the fish further back have to find another way down. Every bed is
## an opening beside a lane that stays open at its end, so the field is never shut in.
##
## The growth belongs to the map and runs whatever the hazard setting is, like geysers do. The
## hazard itself is the overgrowth: now and then a bed that is still asleep wakes without any
## fish and grows shut on its own, after a warning that makes its polyps glow.

signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)

const KIND: String = "overgrowth"
## Most seconds a bed hesitates on top of its warning, drawn from the race seed per bed.
const HESITATION: float = 0.6

var _beds: Array[CoralBed] = []
## Whether a race has started (see [method reseed]), so fish wake the coral.
var _running: bool = false
## The bed an overgrowth event is about, or -1.
var _target: int = -1
## Set when the plugs must be posed again: a physics body only takes a new transform inside a
## physics frame, and the coral is put back from anywhere (a race ending, the end of a replay).
var _repose: bool = true


func _ready() -> void:
	for child: Node in get_children():
		if child is CoralBed:
			var bed: CoralBed = child as CoralBed
			_beds.append(bed)
			bed.burst_played.connect(burst_played.emit)


## Starts the growth for a race ([method Track.seed_gimmicks] calls this): each bed hesitates a
## little differently from the seed.
func reseed(seed_value: int) -> void:
	stop_gimmick()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for bed: CoralBed in _beds:
		bed.hesitation = rng.randf_range(0.0, HESITATION)
	_running = true


## Puts every bed back to sleep ([method Track.stop_gimmicks] calls this).
func stop_gimmick() -> void:
	_running = false
	_target = -1
	for bed: CoralBed in _beds:
		bed.reset()
	_repose = true


func tick(delta: float) -> void:
	if not _running and not _armed:
		return
	if _armed:
		super(delta)
	else:
		clock += delta
	for bed: CoralBed in _beds:
		if (
			_running
			and bed.stage == CoralBed.Stage.DORMANT
			and bed.fish_in_trigger()
			and bed.wake()
		):
			telegraph_started.emit(KIND)
		var before: CoralBed.Stage = bed.stage
		bed.advance(delta, clock)
		if before != CoralBed.Stage.GROWING and bed.stage == CoralBed.Stage.GROWING:
			active_started.emit(KIND)


func _physics_process(delta: float) -> void:
	super(delta)
	if _repose:
		_repose = false
		for bed: CoralBed in _beds:
			bed.pose(true)


## Part of the finish replay: the plugs are synced to physics again, so pose them in the next frame.
func replay_end() -> void:
	_repose = true


# An overgrowth event: a bed that still sleeps is picked when the telegraph begins.
func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	# Always drawn, so the later events of the race do not depend on how many beds still sleep.
	var roll: int = rng.randi()
	var asleep: Array[int] = []
	for i: int in _beds.size():
		if _beds[i].stage == CoralBed.Stage.DORMANT:
			asleep.append(i)
	_target = asleep[roll % asleep.size()] if not asleep.is_empty() else -1


func _process_telegraph(_delta: float) -> void:
	if _target < 0:
		return
	var pulse: float = 0.5 + 0.5 * sin(clock * 16.0)
	_beds[_target].glow = phase_progress() * (0.55 + 0.45 * pulse)


func _begin_active() -> void:
	if _target >= 0:
		_beds[_target].grow_now()


func _end_event() -> void:
	_target = -1


## The beds keep what has grown until [method stop_gimmick]: only the event is cleared.
func _reset() -> void:
	_target = -1


func _replay_extra() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array()
	for bed: CoralBed in _beds:
		state.append_array(bed.replay_values())
	return state


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	for i: int in _beds.size():
		_beds[i].apply_replay(from, to, weight, REPLAY_BASE + i * 3, clock)


func bed_count() -> int:
	return _beds.size()


func get_beds() -> Array[CoralBed]:
	return _beds


## Whether bed `index` still lets fish through.
func is_open(index: int) -> bool:
	return _beds[index].is_open()


## Number of beds the coral has grown shut.
func closed_count() -> int:
	var count: int = 0
	for bed: CoralBed in _beds:
		if not bed.is_open():
			count += 1
	return count
