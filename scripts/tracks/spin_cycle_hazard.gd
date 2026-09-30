class_name SpinCycleHazard
extends Hazard
## The spin cycle of the Washing Machine: the drum (its child) whirls through a few whole turns,
## sometimes the other way round, and flings suds about, then settles back into its tumble
## exactly where it was. The door lamp flashes during the telegraph. It also carries the drum's
## race start and stop, since the drum turns whatever the hazard setting is.

const SUDS_COLOR: Color = Color(0.9, 0.98, 1.0)
## Whole turns a burst makes, at least and at most.
const TURNS_MIN: int = 1
const TURNS_MAX: int = 2
## Chance that a burst turns the drum counterclockwise.
const REVERSE_CHANCE: float = 0.4

var _drum: WashDrum
## Signed whole turns of the running burst.
var _turns: float = 0.0


func _ready() -> void:
	for child: Node in get_children():
		if child is WashDrum:
			_drum = child as WashDrum


## Starts the drum for a race ([method Track.seed_gimmicks] calls this).
func reseed(seed_value: int) -> void:
	if _drum != null:
		_drum.reseed(seed_value)


## Brings the drum back to rest ([method Track.stop_gimmicks] calls this).
func stop_gimmick() -> void:
	if _drum != null:
		_drum.stop()


func get_drum() -> WashDrum:
	return _drum


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	_turns = float(rng.randi_range(TURNS_MIN, TURNS_MAX))
	if rng.randf() < REVERSE_CHANCE:
		_turns = -_turns


func _process_telegraph(_delta: float) -> void:
	if _drum != null:
		var pulse: float = 0.5 + 0.5 * sin(clock * 16.0)
		_drum.alarm = phase_progress() * (0.4 + 0.6 * pulse)


func _begin_active() -> void:
	if _drum == null:
		return
	_drum.alarm = 0.0
	RaceFx.burst(self, _drum.global_position, SUDS_COLOR, 40, 260.0, Vector2(0, 60))


func _process_active(_delta: float) -> void:
	if _drum != null:
		_drum.spin = _turns * TAU * smoothstep(0.0, 1.0, phase_progress())


func _end_event() -> void:
	if _drum != null:
		# A whole number of turns, so dropping it back to zero leaves the drum where it is.
		_drum.spin = 0.0
		_drum.alarm = 0.0


func _reset() -> void:
	_end_event()
	_turns = 0.0
