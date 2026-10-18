class_name Tesseract
extends RefCounted
## Maths of the fake "Fishy Marble Run 4D" track: a tesseract (4D cube) that turns in 4D and
## is projected to 3D the way a 3D cube is projected to a flat screen.

## Distance of the 4D eye from the center, along w. Larger is a flatter projection.
const EYE_W: float = 3.0
## Turning speeds in the xw, yw and zx planes, in radians per second.
const SPEED_XW: float = 0.55
const SPEED_YW: float = 0.31
const SPEED_ZX: float = 0.17


## The 16 corners, every combination of -1 and 1 in x, y, z and w.
static func vertices() -> Array[Vector4]:
	var result: Array[Vector4] = []
	for i: int in 16:
		result.append(
			Vector4(
				1.0 if i & 1 else -1.0,
				1.0 if i & 2 else -1.0,
				1.0 if i & 4 else -1.0,
				1.0 if i & 8 else -1.0
			)
		)
	return result


## The 32 edges as pairs of corner indices: corners that differ in exactly one axis.
static func edges() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i: int in 16:
		for bit: int in [1, 2, 4, 8]:
			if not i & bit:
				result.append(Vector2i(i, i | bit))
	return result


## [param p] turned by the tesseract's spin after [param time] seconds.
static func spin(p: Vector4, time: float) -> Vector4:
	p = _turn(p, 0, 3, time * SPEED_XW)
	p = _turn(p, 1, 3, time * SPEED_YW)
	return _turn(p, 2, 0, time * SPEED_ZX)


## [param p] seen from the 4D eye: nearer points in w come out bigger.
static func project(p: Vector4) -> Vector3:
	var factor: float = EYE_W / maxf(EYE_W - p.w, 0.2)
	return Vector3(p.x, p.y, p.z) * factor


## [param p] turned by [param angle] in the plane of axes [param a] and [param b].
static func _turn(p: Vector4, a: int, b: int, angle: float) -> Vector4:
	var c: float = cos(angle)
	var s: float = sin(angle)
	var pa: float = p[a]
	var pb: float = p[b]
	p[a] = pa * c - pb * s
	p[b] = pa * s + pb * c
	return p
