class_name HomeFishSchool
extends RefCounted
## Loose school of fish wandering a box of water. Pure simulation (no nodes):
## each fish cruises toward a random waypoint and keeps a little distance from its neighbours.

const BOUNDS: AABB = AABB(Vector3(-15.0, -1.5, -9.0), Vector3(30.0, 8.5, 13.0))
const MIN_CRUISE: float = 0.9
const MAX_CRUISE: float = 2.2
const SEPARATION_RADIUS: float = 1.8
const SEPARATION_WEIGHT: float = 1.6
## How fast the velocity follows the wanted velocity (per second).
const AGILITY: float = 1.6
## How fast the drawn heading follows the velocity (per second).
const TURN_RATE: float = 4.0
const SCARE_SPEED: float = 7.0
## How close a click ray must pass to a fish's center to hit it, in world units per fish size.
const HIT_RADIUS: float = 0.6

var count: int = 0
var positions: PackedVector3Array = PackedVector3Array()
var velocities: PackedVector3Array = PackedVector3Array()
var sizes: PackedFloat32Array = PackedFloat32Array()

var _headings: PackedVector3Array = PackedVector3Array()
var _cruise: PackedFloat32Array = PackedFloat32Array()
var _targets: PackedVector3Array = PackedVector3Array()
var _retarget_in: PackedFloat32Array = PackedFloat32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(fish_count: int, rng_seed: int = 0) -> void:
	count = fish_count
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed
	for i: int in count:
		var pos: Vector3 = _random_point()
		var dir: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, _rng.randf() * TAU)
		positions.append(pos)
		velocities.append(dir * _rng.randf_range(MIN_CRUISE, MAX_CRUISE))
		_headings.append(dir)
		sizes.append(_rng.randf_range(0.5, 1.2))
		_cruise.append(_rng.randf_range(MIN_CRUISE, MAX_CRUISE))
		_targets.append(_random_point())
		_retarget_in.append(_rng.randf_range(2.0, 6.0))


func step(delta: float) -> void:
	var follow: float = 1.0 - exp(-delta * AGILITY)
	var turn: float = 1.0 - exp(-delta * TURN_RATE)
	for i: int in count:
		_retarget_in[i] -= delta
		var to_target: Vector3 = _targets[i] - positions[i]
		if _retarget_in[i] <= 0.0 or to_target.length() < 1.0 or not BOUNDS.has_point(positions[i]):
			_targets[i] = _random_point()
			_retarget_in[i] = _rng.randf_range(3.0, 8.0)
			to_target = _targets[i] - positions[i]
		var wanted: Vector3 = to_target.normalized() * _cruise[i]
		wanted.y *= 0.4
		wanted += _separation(i) * SEPARATION_WEIGHT
		velocities[i] = velocities[i].lerp(wanted, follow)
		positions[i] += velocities[i] * delta
		var dir: Vector3 = velocities[i].normalized()
		var blended: Vector3 = _headings[i].lerp(dir, turn)
		_headings[i] = blended.normalized() if blended.length() > 0.001 else dir


## Frightens every fish within [param radius] of the ray, away from its closest point.
func scare(ray_origin: Vector3, ray_dir: Vector3, radius: float) -> void:
	var dir: Vector3 = ray_dir.normalized()
	for i: int in count:
		var along: float = maxf((positions[i] - ray_origin).dot(dir), 0.0)
		var offset: Vector3 = positions[i] - (ray_origin + dir * along)
		var dist: float = offset.length()
		if dist >= radius:
			continue
		var away: Vector3 = offset / dist if dist > 0.001 else Vector3.UP
		var strength: float = SCARE_SPEED * (1.0 - dist / radius)
		velocities[i] += (away + dir * 0.5).normalized() * strength


## The front-most fish the ray passes through, or -1. Bigger fish are easier to hit.
func fish_at(ray_origin: Vector3, ray_dir: Vector3) -> int:
	var dir: Vector3 = ray_dir.normalized()
	var best: int = -1
	var best_along: float = INF
	for i: int in count:
		var along: float = (positions[i] - ray_origin).dot(dir)
		if along <= 0.0 or along >= best_along:
			continue
		var dist: float = (positions[i] - (ray_origin + dir * along)).length()
		if dist < HIT_RADIUS * sizes[i]:
			best = i
			best_along = along
	return best


## Fish nose points along +X; the body stays upright while it turns.
func fish_transform(index: int) -> Transform3D:
	var forward: Vector3 = _headings[index]
	var side: Vector3 = forward.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.001 else Vector3.FORWARD
	# Right-handed basis: x forward, y up, z to the side (forward cross up).
	var basis: Basis = Basis(forward, side.cross(forward), side).scaled_local(
		Vector3.ONE * sizes[index]
	)
	return Transform3D(basis, positions[index])


func _separation(index: int) -> Vector3:
	var push: Vector3 = Vector3.ZERO
	for j: int in count:
		if j == index:
			continue
		var offset: Vector3 = positions[index] - positions[j]
		var dist: float = offset.length()
		if dist < SEPARATION_RADIUS and dist > 0.001:
			push += offset / dist * (1.0 - dist / SEPARATION_RADIUS)
	return push


func _random_point() -> Vector3:
	return (
		BOUNDS.position
		+ Vector3(
			_rng.randf() * BOUNDS.size.x, _rng.randf() * BOUNDS.size.y, _rng.randf() * BOUNDS.size.z
		)
	)
