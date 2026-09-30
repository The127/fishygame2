class_name StreamerPowers
extends Node
## Things the streamer can do to a race by hand: drop a fishing rod, cast a net or set off
## a bubble blast at a spot of their choosing. They cost nothing; a shared cooldown and a
## cap per race keep them from deciding the race.
##
## The node only applies the rules and emits [signal power_used] for the race to act on.
## Streamer input makes a race non-reproducible from its seed. No rng is used here, so seed
## only races (the debug race scene and the CI seed sweeps) are unaffected.

signal power_used(kind: Kind, pos: Vector2)
signal power_rejected(kind: Kind, reason: String)

enum Kind { ROD, NET, BLAST }

## Radius in world pixels each power reaches around the clicked spot.
const ROD_RADIUS: float = 150.0
const NET_RADIUS: float = 170.0
const BLAST_RADIUS: float = 200.0

@export var enabled: bool = true
## Seconds between any two powers.
@export var cooldown: float = 8.0
## Most powers per race.
@export var max_per_race: int = 6

var _racing: bool = false
var _clock: float = 0.0
var _ready_at: float = 0.0
var _uses: int = 0


func _process(delta: float) -> void:
	tick(delta)


## Advances the cooldown clock. Called every frame; tests call it directly.
func tick(delta: float) -> void:
	if _racing:
		_clock += delta


static func radius_of(kind: Kind) -> float:
	match kind:
		Kind.ROD:
			return ROD_RADIUS
		Kind.NET:
			return NET_RADIUS
	return BLAST_RADIUS


static func name_of(kind: Kind) -> String:
	return String(Kind.keys()[kind]).capitalize()


## Uses a power at a world position. Returns true if it fired; otherwise emits
## [signal power_rejected] with "off", "closed", "cooldown" or "cap".
func use(kind: Kind, pos: Vector2) -> bool:
	var reason: String = _check()
	if not reason.is_empty():
		power_rejected.emit(kind, reason)
		return false
	_uses += 1
	_ready_at = _clock + cooldown
	power_used.emit(kind, pos)
	return true


func uses_left() -> int:
	return maxi(0, max_per_race - _uses)


## Seconds until the next power may be used, 0 when ready.
func cooldown_left() -> float:
	return maxf(0.0, _ready_at - _clock)


## Feed it GameFlow.state_changed.
func on_state_changed(new_state: GameFlow.State, _old_state: GameFlow.State) -> void:
	_racing = new_state == GameFlow.State.RACING
	if _racing:
		_clock = 0.0
		_ready_at = 0.0
		_uses = 0


## Feed it Race.race_finished. Closes the powers at once, before the state changes.
func on_race_finished(_results: Array[Dictionary]) -> void:
	_racing = false


func _check() -> String:
	if not enabled:
		return "off"
	if not _racing:
		return "closed"
	if _uses >= max_per_race:
		return "cap"
	if _clock < _ready_at:
		return "cooldown"
	return ""
