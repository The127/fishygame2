class_name KrakenLurkers
extends Node2D
## The kraken's idle tentacles: dim arms that curl and probe up from below the frame between
## sweeps, so the lair is never still. Purely visual. A tentacle that is about to sweep (see
## [KrakenHazard]) fades out here while the hazard draws it, and fades back in afterwards.

const SEGMENTS: int = 14
const BASE_WIDTH: float = 54.0
const TIP_WIDTH: float = 5.0
## Seconds between redraws. The motion is slow, so this is plenty.
const REDRAW_STEP: float = 1.0 / 30.0
## How fast a tentacle fades out or in when it starts or ends a sweep, per second.
const FADE: float = 5.0

var _roots: PackedVector2Array = PackedVector2Array()
var _reach: float = 900.0
var _skin: Color = Color(0.2, 0.08, 0.3)
var _glow: Color = Color(0.55, 1.0, 0.4)
var _time: float = 0.0
## Per tentacle, how much of it is hidden because the hazard is sweeping it: 0 shown, 1 hidden.
var _hidden: PackedFloat32Array = PackedFloat32Array()
var _busy: PackedInt32Array = PackedInt32Array()
var _since_redraw: float = 0.0


## Where the tentacles are rooted and how they look, from the hazard that owns them.
func setup(roots: PackedVector2Array, reach: float, skin: Color, glow: Color) -> void:
	_roots = roots
	_reach = reach
	_skin = skin
	_glow = glow
	_hidden.resize(roots.size())
	_hidden.fill(0.0)
	queue_redraw()


## Which tentacles the hazard is using right now (indices into the roots).
func set_busy(indices: Array[int]) -> void:
	_busy = PackedInt32Array(indices)


func _ready() -> void:
	Replayable.join(self)


## Replay: the clock the motion is drawn from, then how hidden each tentacle is.
func replay_state() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array([_time])
	state.append_array(_hidden)
	return state


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_time = Replayable.mix(from, to, weight, 0)
	for i: int in _hidden.size():
		_hidden[i] = Replayable.mix(from, to, weight, 1 + i)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	for i: int in _hidden.size():
		var goal: float = 1.0 if _busy.has(i) else 0.0
		_hidden[i] = move_toward(_hidden[i], goal, FADE * delta)
	_since_redraw += delta
	if _since_redraw >= REDRAW_STEP:
		_since_redraw = 0.0
		queue_redraw()


func _draw() -> void:
	for i: int in _roots.size():
		var shown: float = 1.0 - _hidden[i]
		if shown > 0.01:
			_draw_lurker(i, shown)


func _draw_lurker(index: int, shown: float) -> void:
	var seed_phase: float = float(index)
	# Every few seconds one of them reaches up to probe, then sinks back.
	var probe: float = pow(maxf(sin(_time * 0.23 + seed_phase * 2.4), 0.0), 3.0)
	var length: float = _reach * (0.27 + 0.1 * sin(_time * 0.45 + seed_phase * 1.7) + 0.24 * probe)
	var heading: float = -PI * 0.5 + 0.3 * sin(_time * 0.37 + seed_phase * 1.1)
	var curl: float = 1.1 * sin(_time * 0.5 + seed_phase * 0.8)
	var points: PackedVector2Array = PackedVector2Array([_roots[index]])
	var step: float = length / float(SEGMENTS)
	var at: Vector2 = _roots[index]
	for i: int in SEGMENTS:
		var s: float = float(i + 1) / float(SEGMENTS)
		var wave: float = sin(_time * 1.3 - s * 4.0 + seed_phase) * 0.12 * s
		at += Vector2.from_angle(heading + curl * s * s * (0.6 + 0.4 * probe) + wave) * step
		points.append(at)
	var alpha: float = 0.6 * shown
	for i: int in SEGMENTS:
		var s: float = float(i) / float(SEGMENTS)
		var width: float = lerpf(BASE_WIDTH, TIP_WIDTH, pow(s, 0.85))
		draw_line(points[i], points[i + 1], Color(_glow, 0.1 * alpha), width + 10.0, true)
		draw_line(points[i], points[i + 1], Color(_skin, alpha), width, true)
		var side: Vector2 = (points[i + 1] - points[i]).orthogonal().normalized()
		var lit: Vector2 = side * width * 0.32
		draw_line(points[i] + lit, points[i + 1] + lit, Color(_glow, 0.35 * alpha), 2.0, true)
		if i % 2 == 1 and s > 0.3:
			var sucker: Vector2 = points[i] - side * width * 0.2
			draw_circle(sucker, maxf(width * 0.12, 1.8), Color(_glow, 0.3 * alpha))
