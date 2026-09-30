class_name BubbleBurst
extends RefCounted
## A handful of drifting bubble outlines, for UI sparkle. Holds at most [constant MAX_BUBBLES]
## so it stays cheap in the web export. Step it every frame and draw it on any CanvasItem.

const MAX_BUBBLES: int = 24
const DRAG: float = 2.0
const BUOYANCY: float = 40.0

var _pos: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _radius: PackedFloat32Array = PackedFloat32Array()


func count() -> int:
	return _pos.size()


## Adds one bubble. Ignored when the cap is reached.
func emit(origin: Vector2, velocity: Vector2, life: float, radius: float) -> void:
	if _pos.size() >= MAX_BUBBLES:
		return
	_pos.append(origin)
	_vel.append(velocity)
	_age.append(0.0)
	_life.append(maxf(life, 0.01))
	_radius.append(radius)


## Sends [param amount] bubbles outwards from [param origin] in all directions.
func burst(origin: Vector2, amount: int, speed: float, life: float, radius: float) -> void:
	for i: int in amount:
		var angle: float = TAU * (float(i) + randf()) / float(maxi(amount, 1))
		var velocity: Vector2 = Vector2.from_angle(angle) * speed * randf_range(0.6, 1.0)
		emit(origin, velocity, life * randf_range(0.7, 1.0), radius * randf_range(0.6, 1.2))


func step(delta: float) -> void:
	var i: int = _pos.size() - 1
	while i >= 0:
		_age[i] += delta
		if _age[i] >= _life[i]:
			_pos.remove_at(i)
			_vel.remove_at(i)
			_age.remove_at(i)
			_life.remove_at(i)
			_radius.remove_at(i)
		else:
			_vel[i] *= maxf(0.0, 1.0 - DRAG * delta)
			_vel[i].y -= BUOYANCY * delta
			_pos[i] += _vel[i] * delta
		i -= 1


func draw(canvas: CanvasItem, color: Color) -> void:
	for i: int in _pos.size():
		var fade: float = 1.0 - _age[i] / _life[i]
		canvas.draw_arc(_pos[i], _radius[i], 0.0, TAU, 12, Color(color, color.a * fade), 1.5)
