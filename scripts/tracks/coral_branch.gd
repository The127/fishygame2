class_name CoralBranch
extends Node2D
## One forking branch that hangs from a [CoralBed]'s tongue. The branch is laid out once, from its
## seed, at full size; growing it only scales that drawing, and the sway is the node's own
## rotation, so a grown branch costs nothing per frame (it is only drawn again while it grows).

## How many times the branch forks.
const FORK_DEPTH: int = 3

var _color: Color = Color.WHITE
var _base_color: Color = Color.WHITE
## The line segments (start, end, start, end...) at full size, by how many forks are left.
var _lines: Array[PackedVector2Array] = []
## The ends of the last twigs at full size.
var _tips: PackedVector2Array = PackedVector2Array()
## How much of the branch has grown, 0 to 1.
var _own: float = 0.0


## Lays out the branch: `length` pixels to the first fork, `color` at the twigs and `base_color`
## where it leaves the tongue, forking from the random numbers of `seed_value`.
func setup(length: float, color: Color, base_color: Color, seed_value: int) -> void:
	_color = color
	_base_color = base_color
	_lines.clear()
	for i: int in FORK_DEPTH + 1:
		_lines.append(PackedVector2Array())
	_tips.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	_lay_out(Vector2.ZERO, Vector2(0.0, 1.0), length, FORK_DEPTH, rng)
	queue_redraw()


## Draws the branch `own` of the way grown (0 to 1). Does nothing when the size is the same.
func grow_to(own: float) -> void:
	if own == _own:
		return
	_own = own
	queue_redraw()


func _lay_out(
	from: Vector2, direction: Vector2, length: float, depth: int, rng: RandomNumberGenerator
) -> void:
	var to: Vector2 = from + direction * length
	_lines[depth].append(from)
	_lines[depth].append(to)
	if depth == 0:
		_tips.append(to)
		return
	var spread: float = rng.randf_range(0.35, 0.6)
	var shrink: float = rng.randf_range(0.62, 0.78)
	_lay_out(to, direction.rotated(-spread), length * shrink, depth - 1, rng)
	_lay_out(to, direction.rotated(spread * 0.9), length * shrink, depth - 1, rng)


func _draw() -> void:
	if _own <= 0.0:
		return
	var scale_by: Transform2D = Transform2D(Vector2(_own, 0.0), Vector2(0.0, _own), Vector2.ZERO)
	for depth: int in range(FORK_DEPTH, -1, -1):
		var color: Color = _base_color.lerp(_color, 0.25 * float(FORK_DEPTH - depth))
		draw_multiline(scale_by * _lines[depth], color, 2.0 + float(depth) * 1.6, true)
	for tip: Vector2 in scale_by * _tips:
		draw_circle(tip, 3.4 * _own + 0.6, _color)
		draw_circle(tip, 6.0 * _own, Color(_color, 0.22))
