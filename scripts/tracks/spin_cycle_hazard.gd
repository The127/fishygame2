class_name SpinCycleHazard
extends Hazard
## The spin cycle of the Washing Machine: the rings (its [WashDrum] children) whirl through a few
## whole turns, each by its own multiple and sometimes the other way round, and fling suds about,
## then settle back into their tumble exactly where they were. The door lamp flashes during the telegraph. It also carries the drum's
## race start and stop, since the drum turns whatever the hazard setting is.

## A burst of suds: what [method RaceFx.burst] was given, so the finish replay can play the same
## burst.
signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)

const SUDS_COLOR: Color = Color(0.9, 0.98, 1.0)
## Whole turns a burst makes, at least and at most.
const TURNS_MIN: int = 1
const TURNS_MAX: int = 2
## Chance that a burst turns the drum counterclockwise.
const REVERSE_CHANCE: float = 0.4

var _drums: Array[WashDrum] = []
## Signed whole turns of the running burst.
var _turns: float = 0.0


func _ready() -> void:
	for child: Node in get_children():
		if child is WashDrum:
			_drums.append(child as WashDrum)


## Starts the rings for a race ([method Track.seed_gimmicks] calls this). Each ring draws its own
## start delay from the seed.
func reseed(seed_value: int) -> void:
	for i: int in _drums.size():
		_drums[i].reseed(seed_value + i * 7919)


## Brings the rings back to rest ([method Track.stop_gimmicks] calls this).
func stop_gimmick() -> void:
	for drum: WashDrum in _drums:
		drum.stop()


## The rings, outermost first.
func get_drums() -> Array[WashDrum]:
	return _drums


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	_turns = float(rng.randi_range(TURNS_MIN, TURNS_MAX))
	if rng.randf() < REVERSE_CHANCE:
		_turns = -_turns


func _process_telegraph(_delta: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(clock * 16.0)
	for drum: WashDrum in _drums:
		drum.alarm = phase_progress() * (0.4 + 0.6 * pulse)


func _begin_active() -> void:
	if _drums.is_empty():
		return
	for drum: WashDrum in _drums:
		drum.alarm = 0.0
	var at: Vector2 = _drums[0].global_position
	RaceFx.burst(self, at, SUDS_COLOR, 40, 260.0, Vector2(0, 60))
	burst_played.emit(at, SUDS_COLOR, 40, 260.0, Vector2(0, 60))


func _process_active(_delta: float) -> void:
	for drum: WashDrum in _drums:
		drum.spin = (
			_turns * float(drum.spin_multiplier) * TAU * smoothstep(0.0, 1.0, phase_progress())
		)


func _end_event() -> void:
	for drum: WashDrum in _drums:
		# A whole number of turns, so dropping it back to zero leaves the ring where it is.
		drum.spin = 0.0
		drum.alarm = 0.0


func _reset() -> void:
	_end_event()
	_turns = 0.0
