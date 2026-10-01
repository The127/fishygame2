class_name RingCurrent
extends Area2D
## The river of Riptide Rounds. A zone over the whole ring with no gravity in it, so nothing rolls
## anywhere: every fish inside is carried round the loop by the current alone. The current runs
## fastest down the middle of the channel and slower along the walls, and it breathes: slow
## crests travel against the flow, so a fish is sped up and held back in turn. Each fish also has
## its own small knack with the water, drawn from the race seed. Streaks of light drift along the
## channel to show which way the water runs.
## Set up by [RingChannel], which owns the loop.

## Speed in pixels per second the water carries a fish at in the middle of the channel.
const SPEED: float = 600.0
## How much slower the water runs at the wall than in the middle, as a fraction.
const WALL_DRAG: float = 0.3
## How fast a fish's speed catches up with the water's, per second.
const GAIN: float = 3.2
## Damping of the sideways motion, per second.
const SIDE_DAMP: float = 1.6
## Size of the crests, as a fraction of [constant SPEED], how many run round the loop and how
## fast they travel against the flow, in loops per second.
const GUST_SIZE: float = 0.2
const GUST_CRESTS: float = 3.0
const GUST_DRIFT: float = 0.45
## Largest difference in a fish's knack with the water, as a fraction of [constant SPEED].
const KNACK_SIZE: float = 0.06
const STREAKS: int = 64
const STREAK_COLOR: Color = Color(0.55, 0.95, 1.0)

var clock: float = 0.0
var running: bool = false

var _curve: Curve2D = null
var _length: float = 1.0
var _half_width: float = 95.0
var _salt: float = 0.0
## How far the streaks have drifted, in loops.
var _flow: float = 0.0


## Gives the current the loop it runs round and covers `bounds` with its zone.
func setup(curve: Curve2D, half_width: float, bounds: Rect2) -> void:
	_curve = curve
	_length = maxf(curve.get_baked_length(), 1.0)
	_half_width = half_width
	gravity_space_override = Area2D.SPACE_OVERRIDE_REPLACE
	gravity = 0.0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = bounds.size
	shape.shape = box
	shape.position = bounds.get_center()
	add_child(shape)
	z_index = -2
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	Replayable.join(self)


## Starts a race's current. The seed decides where the crests lie and each fish's knack.
func reseed(seed_value: int) -> void:
	_salt = float(seed_value % 10007) * 0.0137
	clock = 0.0
	running = true


## Stops the current and leaves the streaks still.
func stop_gimmick() -> void:
	running = false
	clock = 0.0


## The speed the water carries `marble` at right now, in pixels per second: the middle of the
## channel at the crest of a gust is the fastest.
func water_speed(offset: float, lateral: float, marble_id: int) -> float:
	var wall: float = clampf(absf(lateral) / _half_width, 0.0, 1.0)
	var gust: float = (
		1.0 + GUST_SIZE * sin(TAU * (GUST_CRESTS * offset / _length + GUST_DRIFT * clock + _salt))
	)
	return SPEED * (1.0 - WALL_DRAG * wall * wall) * gust * (1.0 + knack(marble_id))


## How much better (or worse) than the others a fish swims in the water, from -KNACK_SIZE to +KNACK_SIZE.
func knack(marble_id: int) -> float:
	var mix: float = fposmod(sin(float(marble_id) * 12.9898 + _salt * 78.233) * 43758.5453, 1.0)
	return (mix * 2.0 - 1.0) * KNACK_SIZE


func _physics_process(delta: float) -> void:
	if not running or _curve == null:
		return
	clock += delta
	for body: Node2D in get_overlapping_bodies():
		if body is Marble and not (body as Marble).is_out():
			_carry(body as Marble)


func _process(delta: float) -> void:
	_flow = fposmod(_flow + delta * SPEED * 0.85 / _length, 1.0)
	queue_redraw()


## Accelerates one fish toward the speed of the water where it is.
func _carry(marble: Marble) -> void:
	var local: Vector2 = to_local(marble.global_position)
	var offset: float = _curve.get_closest_offset(local)
	var lane: Vector2 = _curve.sample_baked(offset)
	var tangent: Vector2 = _tangent(offset)
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	var lateral: float = (local - lane).dot(normal)
	var along: float = marble.linear_velocity.dot(tangent)
	var side: float = marble.linear_velocity.dot(normal)
	var accel: Vector2 = tangent * (water_speed(offset, lateral, marble.id) - along) * GAIN
	accel -= normal * side * SIDE_DAMP
	marble.sleeping = false
	marble.apply_central_force(accel * marble.mass)


func _tangent(offset: float) -> Vector2:
	var ahead: Vector2 = _curve.sample_baked(minf(offset + 8.0, _length))
	var behind: Vector2 = _curve.sample_baked(maxf(offset - 8.0, 0.0))
	var direction: Vector2 = ahead - behind
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT


## The finish replay records how far the streaks have drifted (see [Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([_flow])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	# A drift that wrapped round the loop between two samples is blended the short way.
	var a: float = from[0]
	var b: float = to[0]
	if b < a:
		b += 1.0
	_flow = fposmod(lerpf(a, b, weight), 1.0)
	queue_redraw()


func _draw() -> void:
	if _curve == null:
		return
	for i: int in STREAKS:
		var lane_share: float = fposmod(float(i) * 0.61803, 1.0)
		var lateral: float = (lane_share * 2.0 - 1.0) * _half_width * 0.86
		var pace: float = 0.75 + 0.5 * fposmod(float(i) * 0.37, 1.0)
		var head: float = fposmod(float(i) * 0.137 + _flow * pace, 1.0) * _length
		var tail_length: float = 70.0 + 90.0 * fposmod(float(i) * 0.71, 1.0)
		var alpha: float = 0.05 + 0.08 * fposmod(float(i) * 0.53, 1.0)
		var points: PackedVector2Array = PackedVector2Array()
		for step: int in 4:
			var at: float = head - tail_length * float(step) / 3.0
			if at < 0.0:
				at += _length
			var normal: Vector2 = _tangent(at).orthogonal()
			points.append(_curve.sample_baked(at) + normal * lateral)
		# A streak that wraps the start of the loop would be drawn straight across it.
		if points[0].distance_to(points[3]) > tail_length * 1.5:
			continue
		draw_polyline(points, Color(STREAK_COLOR, alpha), 2.5, true)
