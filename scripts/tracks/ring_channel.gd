class_name RingChannel
extends Path2D
## The loop of Riptide Rounds: a stadium-shaped channel round a still lagoon. This node is the
## map's `Centerline`: it builds the closed lane from the exports below, the walls with their
## colliders and looks, and the [RingCurrent] that carries the fish. The lane starts at the lap
## line on the top straight, runs clockwise and ends back at the line.

## Middle of the stadium.
@export var center: Vector2 = Vector2(960.0, 540.0)
## Length of each straight.
@export var straight_length: float = 800.0
## Radius of the bends along the middle of the lane.
@export var lane_radius: float = 405.0
## Half the width of the channel.
@export var half_width: float = 95.0
## Distance of the lap line from the left end of the top straight.
@export var line_offset: float = 140.0
## Angle between two points on a bend.
@export var bend_step_degrees: float = 3.0
## How far past the walls the stone reaches, so it fills the screen.
@export var stone_reach: float = 520.0
@export var stone_dark: Color = Color(0.03, 0.07, 0.1)
@export var stone_light: Color = Color(0.13, 0.26, 0.32)
@export var rim: Color = Color(0.45, 0.85, 1.0)
@export var water: Color = Color(0.05, 0.25, 0.4)
## The still water of the lagoon.
@export var lagoon_water: Color = Color(0.015, 0.07, 0.11)

var _current: RingCurrent = null


func _ready() -> void:
	curve = _lane_curve()
	_build_walls()
	_build_water()
	_current = RingCurrent.new()
	_current.name = "Current"
	add_child(_current)
	_current.setup(curve, half_width, Rect2(-200.0, -200.0, 2320.0, 1480.0))


## Radius of the outer edge of the channel.
func outer_radius() -> float:
	return lane_radius + half_width


## Radius of the inner edge of the channel, the shore of the lagoon.
func inner_radius() -> float:
	return lane_radius - half_width


## The still water in the middle of the ring, where the cut fish wait: a box that stays clear of
## the shore all round.
func lagoon() -> Rect2:
	var reach: float = 100.0
	var half_height: float = inner_radius() * 0.8
	return Rect2(
		center.x - straight_length * 0.5 - reach,
		center.y - half_height,
		straight_length + reach * 2.0,
		half_height * 2.0
	)


## A point on the lane `fraction` (0 to 1) of the way round from the lap line.
func lane_point(fraction: float) -> Vector2:
	return curve.sample_baked(fposmod(fraction, 1.0) * curve.get_baked_length())


## Direction of the water at `fraction` of the way round.
func lane_direction(fraction: float) -> Vector2:
	var length: float = curve.get_baked_length()
	var at: float = fposmod(fraction, 1.0) * length
	return (
		(curve.sample_baked(minf(at + 8.0, length)) - curve.sample_baked(maxf(at - 8.0, 0.0)))
		. normalized()
	)


## The seed starts the current's gusts and each fish's knack with the water.
func reseed(seed_value: int) -> void:
	_current.reseed(seed_value)


func stop_gimmick() -> void:
	_current.stop_gimmick()


## Points of a stadium of bend radius `radius` round the middle, clockwise on screen, starting at
## the left end of the top straight.
func stadium(radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var half: float = straight_length * 0.5
	var left: Vector2 = center + Vector2(-half, 0.0)
	var right: Vector2 = center + Vector2(half, 0.0)
	var steps: int = roundi(180.0 / bend_step_degrees)
	points.append(left + Vector2(0.0, -radius))
	for i: int in range(0, steps + 1):
		var angle: float = deg_to_rad(-90.0 + bend_step_degrees * float(i))
		points.append(right + Vector2.from_angle(angle) * radius)
	for i: int in range(0, steps + 1):
		var angle: float = deg_to_rad(90.0 + bend_step_degrees * float(i))
		points.append(left + Vector2.from_angle(angle) * radius)
	# The last point is the start again.
	points.remove_at(points.size() - 1)
	return points


func _lane_curve() -> Curve2D:
	var lane: PackedVector2Array = stadium(lane_radius)
	var start: Vector2 = lane[0] + Vector2(line_offset, 0.0)
	var result: Curve2D = Curve2D.new()
	result.add_point(start)
	# The second point on the top straight is the right end; the lap line lies before it.
	for i: int in range(1, lane.size()):
		result.add_point(lane[i])
	result.add_point(lane[0])
	result.add_point(start)
	return result


func _build_walls() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Walls"
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.3
	material.bounce = 0.35
	body.physics_material_override = material
	var outer: PackedVector2Array = stadium(outer_radius())
	var inner: PackedVector2Array = stadium(inner_radius())
	var outer_shape: CollisionPolygon2D = CollisionPolygon2D.new()
	outer_shape.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	outer_shape.polygon = outer
	body.add_child(outer_shape)
	var island_shape: CollisionPolygon2D = CollisionPolygon2D.new()
	island_shape.polygon = inner
	body.add_child(island_shape)
	add_child(body)
	# Stone from the outer edge outward: one wide line round a bigger loop, so the screen is full.
	var stone_material: ShaderMaterial = ShaderMaterial.new()
	stone_material.shader = TrackStyle.STONE_SHADER
	stone_material.set_shader_parameter("dark_color", stone_dark)
	stone_material.set_shader_parameter("light_color", stone_light)
	var outside: Line2D = _loop(
		stadium(outer_radius() + stone_reach * 0.5), stone_reach, Color.WHITE
	)
	outside.material = stone_material
	outside.z_index = -1
	var island: Polygon2D = Polygon2D.new()
	island.polygon = inner
	island.color = lagoon_water
	island.z_index = -1
	add_child(outside)
	add_child(island)
	for ring: PackedVector2Array in [outer, inner]:
		var glow: Line2D = _loop(ring, 9.0, Color(rim, 0.13))
		var add: CanvasItemMaterial = CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		glow.z_index = -1
		add_child(glow)
		var edge: Line2D = _loop(ring, 2.0, Color(rim, 0.7))
		edge.z_index = -1
		add_child(edge)


## The water in the channel: a wide dim band with a brighter jet down the middle.
func _build_water() -> void:
	var lane: PackedVector2Array = stadium(lane_radius)
	var band: Line2D = _loop(lane, half_width * 2.0 + 4.0, Color(water, 0.55))
	band.z_index = -4
	add_child(band)
	var jet: Line2D = _loop(lane, half_width * 0.9, Color(water.lightened(0.25), 0.25))
	jet.z_index = -3
	add_child(jet)


func _loop(points: PackedVector2Array, width: float, color: Color) -> Line2D:
	var line: Line2D = Line2D.new()
	line.points = points
	line.closed = true
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = width < 20.0
	return line
