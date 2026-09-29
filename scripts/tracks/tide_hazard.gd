class_name TideHazard
extends Hazard
## A surge of tide sloshes the flip gates (its children), throwing each one to a random side
## a few times in a row. The telegraph makes every gate's arrow flash a warning.

## How many times the gates are thrown during one event.
const BURSTS: int = 3
const BUBBLE_COLOR: Color = Color(1.0, 0.8, 0.85)

var _gates: Array[FlipGate] = []
## One side (+1 or -1) per gate for each burst, drawn when the event begins.
var _sides: Array[int] = []
var _next_burst: int = 0


func _ready() -> void:
	for child: Node in get_children():
		if child is FlipGate:
			_gates.append(child as FlipGate)


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	_sides.clear()
	for i: int in BURSTS * _gates.size():
		_sides.append(1 if rng.randf() < 0.5 else -1)
	_next_burst = 0


func _process_telegraph(_delta: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(clock * 14.0)
	for gate: FlipGate in _gates:
		gate.set_alarm(phase_progress() * (0.5 + 0.5 * pulse))


func _process_active(_delta: float) -> void:
	var interval: float = active_seconds / float(BURSTS)
	while _next_burst < BURSTS and phase_time >= float(_next_burst) * interval:
		for i: int in _gates.size():
			var gate: FlipGate = _gates[i]
			var before: int = gate.state
			gate.set_state(_sides[_next_burst * _gates.size() + i])
			if gate.state != before:
				RaceFx.burst(self, gate.global_position, BUBBLE_COLOR, 10, 90.0)
		_next_burst += 1


func _end_event() -> void:
	for gate: FlipGate in _gates:
		gate.set_alarm(0.0)


func _reset() -> void:
	for gate: FlipGate in _gates:
		gate.reset()
	_sides.clear()
	_next_burst = 0
