class_name FishTrail
extends RefCounted
## The cosmetic trails a viewer can buy for their fish (see [ShopCatalog.TRAIL_NAMES]): a small
## world-space particle emitter that replaces the plain bubble trail while the fish moves.
## Kept to a dozen or two particles and no shaders so 20 fish stay light in the web export.

## Order matches [constant ShopCatalog.TRAIL_NAMES] after NONE.
enum Kind { NONE, RAINBOW, STARS, BUBBLES, DUST, EMBERS, HEARTS }

const TEXTURE_SIZE: int = 32

static var _star_texture: ImageTexture = null
static var _ring_texture: ImageTexture = null
static var _heart_texture: ImageTexture = null


## An emitter for [param kind], set up like [method RaceFx.make_trail]: particles stay in world
## space, so the caller keeps it top level and moves it with the fish. NONE gives the plain
## bubble trail every fish has.
static func make(kind: int) -> CPUParticles2D:
	var trail: CPUParticles2D = RaceFx.make_trail()
	match kind:
		Kind.RAINBOW:
			_rainbow(trail)
		Kind.STARS:
			_stars(trail)
		Kind.BUBBLES:
			_bubbles(trail)
		Kind.DUST:
			_dust(trail)
		Kind.EMBERS:
			_embers(trail)
		Kind.HEARTS:
			_hearts(trail)
	return trail


## Seven colors across the life of each particle, so the streak behind the fish is banded.
static func _rainbow(trail: CPUParticles2D) -> void:
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.17, 0.34, 0.5, 0.67, 0.84, 1.0])
	ramp.colors = PackedColorArray(
		[
			Color(1.0, 0.25, 0.25, 0.9),
			Color(1.0, 0.6, 0.15, 0.85),
			Color(1.0, 0.95, 0.25, 0.8),
			Color(0.35, 0.95, 0.4, 0.7),
			Color(0.3, 0.75, 1.0, 0.55),
			Color(0.65, 0.4, 1.0, 0.3),
			Color(0.65, 0.4, 1.0, 0.0),
		]
	)
	trail.amount = 24
	trail.lifetime = 0.9
	trail.spread = 10.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 4.0
	trail.scale_amount_min = 0.2
	trail.scale_amount_max = 0.2
	trail.color = Color.WHITE
	trail.color_ramp = ramp


static func _stars(trail: CPUParticles2D) -> void:
	trail.texture = _star()
	trail.amount = 12
	trail.lifetime = 1.0
	trail.spread = 180.0
	trail.gravity = Vector2(0, 10)
	trail.initial_velocity_min = 8.0
	trail.initial_velocity_max = 35.0
	trail.angle_min = -180.0
	trail.angle_max = 180.0
	trail.angular_velocity_min = -120.0
	trail.angular_velocity_max = 120.0
	trail.scale_amount_min = 0.35
	trail.scale_amount_max = 0.7
	trail.color = Color(1.0, 0.92, 0.45, 0.9)


static func _bubbles(trail: CPUParticles2D) -> void:
	trail.texture = _ring()
	trail.amount = 12
	trail.lifetime = 1.3
	trail.spread = 35.0
	trail.gravity = Vector2(0, -45)
	trail.initial_velocity_min = 5.0
	trail.initial_velocity_max = 20.0
	trail.scale_amount_min = 0.25
	trail.scale_amount_max = 0.6
	trail.color = Color(0.75, 0.93, 1.0, 0.8)


static func _dust(trail: CPUParticles2D) -> void:
	trail.amount = 16
	trail.lifetime = 1.1
	trail.spread = 180.0
	trail.gravity = Vector2(0, 8)
	trail.initial_velocity_min = 6.0
	trail.initial_velocity_max = 28.0
	trail.scale_amount_min = 0.12
	trail.scale_amount_max = 0.3
	trail.color = Color(0.8, 0.66, 0.45, 0.4)


static func _embers(trail: CPUParticles2D) -> void:
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray(
		[Color(1.0, 0.9, 0.4, 1.0), Color(1.0, 0.4, 0.1, 0.8), Color(0.6, 0.05, 0.05, 0.0)]
	)
	trail.amount = 16
	trail.lifetime = 0.8
	trail.spread = 60.0
	trail.gravity = Vector2(0, -60)
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 40.0
	trail.scale_amount_min = 0.08
	trail.scale_amount_max = 0.2
	trail.color = Color.WHITE
	trail.color_ramp = ramp


static func _hearts(trail: CPUParticles2D) -> void:
	trail.texture = _heart()
	trail.amount = 8
	trail.lifetime = 1.2
	trail.spread = 40.0
	trail.gravity = Vector2(0, -35)
	trail.initial_velocity_min = 5.0
	trail.initial_velocity_max = 20.0
	trail.scale_amount_min = 0.4
	trail.scale_amount_max = 0.7
	trail.color = Color(1.0, 0.45, 0.65, 0.9)


## A five-pointed star, white on clear.
static func _star() -> ImageTexture:
	if _star_texture == null:
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in 10:
			var radius: float = 0.48 if i % 2 == 0 else 0.2
			var angle: float = -PI / 2.0 + TAU * float(i) / 10.0
			points.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * radius)
		_star_texture = _paint(func(p: Vector2) -> float: return _inside(points, p))
	return _star_texture


## A soft ring, white on clear.
static func _ring() -> ImageTexture:
	if _ring_texture == null:
		_ring_texture = _paint(
			func(p: Vector2) -> float:
				var d: float = p.distance_to(Vector2(0.5, 0.5))
				return clampf(1.0 - absf(d - 0.38) / 0.09, 0.0, 1.0) + (0.12 if d < 0.38 else 0.0)
		)
	return _ring_texture


## A heart, white on clear.
static func _heart() -> ImageTexture:
	if _heart_texture == null:
		_heart_texture = _paint(
			func(p: Vector2) -> float:
				var x: float = (p.x - 0.5) * 2.6
				var y: float = (0.45 - p.y) * 2.6
				return 1.0 if pow(x * x + y * y - 1.0, 3.0) - x * x * y * y * y <= 0.0 else 0.0
		)
	return _heart_texture


## A square texture whose alpha is [param shape] at each pixel (0 to 1 in both axes).
static func _paint(shape: Callable) -> ImageTexture:
	var image: Image = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y: int in TEXTURE_SIZE:
		for x: int in TEXTURE_SIZE:
			var p: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) / float(TEXTURE_SIZE)
			image.set_pixel(x, y, Color(1, 1, 1, clampf(float(shape.call(p)), 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


static func _inside(polygon: PackedVector2Array, p: Vector2) -> float:
	return 1.0 if Geometry2D.is_point_in_polygon(p, polygon) else 0.0
