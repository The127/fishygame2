class_name SushiBelts
extends Path2D
## The conveyor belts of Sushi Bar. This node is the map's `Centerline`: it builds a stack of
## belts from the exports below, each running the other way to the one above, with a drop at the
## far end of each onto the next, the counter walls round them and the route the fish take.
##
## A belt carries every fish that rests on it toward its far end. Each fish has its own knack
## with each belt (a little faster or slower than the belt itself), drawn from the race seed, so
## the order changes along the way and a seed replays the same race. Now and then a fish flops:
## it hops up and a little ahead, so it can pass the fish riding in front of it. The belts draw their own
## moving slats from a clock that the finish replay records. Each [SushiChef] child stands over the
## belt nearest to it; this node tells it how that belt moves and passes the race on to it. The
## chefs share one [ChopTally], so the field share a race can lose counts every knife, and this
## node folds their meters into one.

## The chefs' chat meter changed. Empty text hides it.
signal meter_changed(text: String)

## Group the walls and pegs join so [TrackStyle] dresses them like a map's own stone.
const STONE_GROUP: StringName = TrackStyle.STONE_GROUP
## Largest difference in a fish's knack with a belt, as a fraction of the belt's speed.
const KNACK: float = 0.25
## Seconds between a fish's flops, its upward kick and the most it hops ahead, in pixels per second.
const FLOP_MIN: float = 1.2
const FLOP_MAX: float = 3.4
const FLOP_UP: float = 330.0
const FLOP_AHEAD: float = 170.0
## Below this speed a fish off the belts counts as lodged and flops too.
const STILL_SPEED: float = 20.0
## How quickly a fish on a belt takes up its speed, per second.
const GRIP: float = 5.0
## How far above a belt's top a fish's center still counts as resting on it.
const CONTACT: float = Marble.RADIUS + 8.0
## Spacing of the slats drawn on a belt.
const SLAT: float = 34.0
## Where the humps sit along each belt (fractions of its length), and their width and height. A
## fish riding over one hops, so the pack shuffles. The chef's spot is kept clear.
const HUMPS: PackedFloat32Array = [0.22, 0.5, 0.78]
const HUMP_HALF: float = 16.0
const HUMP_HEIGHT: float = 9.0
## Distance from the chef that a hump keeps.
const CHEF_CLEAR: float = 140.0
## The sesame pegs under the start that scatter the fish over the first belt: rows above that
## belt (pixels), pegs per row, spacing, and radius.
const PEG_ROWS: PackedFloat32Array = [100.0, 58.0]
const PEGS_PER_ROW: int = 7
const PEG_SPACING: float = 62.0
const PEG_RADIUS: float = 9.0

## World y of the top of the first belt, and the distance from one belt to the next.
@export var top_y: float = 250.0
@export var spacing: float = 205.0
@export var belt_count: int = 4
## Inner faces of the counter's side walls.
@export var left_x: float = 60.0
@export var right_x: float = 1860.0
## Width of the opening at a belt's far end that the fish drop through.
@export var drop_width: float = 104.0
@export var thickness: float = 26.0
## Speed of the belts in pixels per second, and how much a seed may change each one.
@export var speed: float = 270.0
@export var speed_spread: float = 0.1
@export var belt_color: Color = Color(0.2, 0.21, 0.24)
@export var slat_color: Color = Color(0.55, 0.58, 0.62)
@export var hump_color: Color = Color(0.55, 0.78, 0.3)
@export var rim: Color = Color(1.0, 0.7, 0.4)
## World x the start's pegs are centered on, over the first belt.
@export var start_x: float = 960.0
@export var peg_color: Color = Color(0.96, 0.9, 0.7)

## Race seconds, advanced in physics frames so the slats replay.
var clock: float = 0.0

var _speeds: PackedFloat32Array = PackedFloat32Array()
## Share of its speed each belt runs at right now (a jam turns one round), and how strongly each
## flashes a warning, set by [method set_belt_state].
var _factors: PackedFloat32Array = PackedFloat32Array()
var _warnings: PackedFloat32Array = PackedFloat32Array()
## How far each belt's slats have moved this race, in pixels.
var _travel: PackedFloat32Array = PackedFloat32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _knack_seed: int = 0
var _bodies: Array[StaticBody2D] = []
var _chefs: Array[SushiChef] = []
var _tally: ChopTally = ChopTally.new()
var _meter: String = ""
## Race second of each fish's next flop, and how many flops it has had, by marble id.
var _next_flop: Dictionary = {}
var _flops: Dictionary = {}


func _ready() -> void:
	Replayable.join(self)
	_speeds.resize(belt_count)
	_speeds.fill(speed)
	_factors.resize(belt_count)
	_factors.fill(1.0)
	_warnings.resize(belt_count)
	_warnings.fill(0.0)
	_travel.resize(belt_count)
	_travel.fill(0.0)
	curve = _route()
	_build_belts()
	_build_walls()
	_build_pegs()
	for child: Node in get_children():
		if child is SushiChef:
			var chef: SushiChef = child as SushiChef
			_chefs.append(chef)
			chef.share_tally(_tally)
			chef.meter_changed.connect(_on_chef_meter.unbind(1))
	_apply_speeds()


## Plans a race: each belt's speed and each fish's knack come from `seed_value`.
func reseed(seed_value: int) -> void:
	_rng.seed = seed_value
	for i: int in belt_count:
		_speeds[i] = speed * (1.0 + _rng.randf_range(-speed_spread, speed_spread))
	_knack_seed = _rng.randi()
	_restart()
	for chef: SushiChef in _chefs:
		chef.reseed(_rng.randi())


## Tells the chefs how many fish race.
func set_field_size(count: int) -> void:
	for chef: SushiChef in _chefs:
		chef.set_field_size(count)


func stop_gimmick() -> void:
	_speeds.fill(speed)
	_restart()
	for chef: SushiChef in _chefs:
		chef.stop_gimmick()


## Clears the race clock, the flops and any jam, and sets the belts going.
func _restart() -> void:
	clock = 0.0
	_next_flop.clear()
	_flops.clear()
	_factors.fill(1.0)
	_warnings.fill(0.0)
	_travel.fill(0.0)
	_apply_speeds()


func get_chefs() -> Array[SushiChef]:
	return _chefs


## Text of the one meter for every chef: a swing anywhere shows, then a knife ready to swing, and
## the chefs are full or sharpening only when all of them are.
func meter_text() -> String:
	var texts: PackedStringArray = PackedStringArray()
	for chef: SushiChef in _chefs:
		if chef.is_armed():
			texts.append(chef.meter_text())
	if texts.is_empty():
		return ""
	if _chefs.size() == 1:
		return texts[0]
	if texts.has("CHOP!"):
		return "CHOP!"
	if texts.has("SUSHI CHEF   #chop"):
		return "SUSHI CHEFS   #chop"
	if texts.has("SHARPENING THE KNIFE"):
		return "SHARPENING THE KNIVES"
	return "THE CHEFS ARE FULL"


func _on_chef_meter() -> void:
	var text: String = meter_text()
	if text != _meter:
		_meter = text
		meter_changed.emit(text)


## Direction of belt `index`: 1 runs to the right, -1 to the left.
func direction(index: int) -> float:
	return 1.0 if index % 2 == 0 else -1.0


## World y of the top surface of belt `index`.
func belt_y(index: int) -> float:
	return top_y + spacing * float(index)


## Speed of belt `index` this race, in pixels per second, along its own direction.
func belt_speed(index: int) -> float:
	return _speeds[index]


## Velocity of belt `index` right now along x: its direction and speed, turned round while jammed.
func belt_velocity(index: int) -> float:
	return direction(index) * _speeds[index] * _factors[index]


## Feed it [signal BeltReverseHazard.belt_changed]: belt `index` runs at `factor` of its speed and
## flashes a `warning` (0 to 1).
func set_belt_state(index: int, factor: float, warning: float) -> void:
	if index < 0 or index >= belt_count:
		return
	_factors[index] = factor
	_warnings[index] = warning
	_apply_speeds()


## Left and right ends of belt `index`. The far end leaves room for the drop.
func belt_span(index: int) -> Vector2:
	if direction(index) > 0.0:
		return Vector2(left_x, right_x - drop_width)
	return Vector2(left_x + drop_width, right_x)


## Index of the belt that `at` (a world point) rests on, or -1.
func belt_under(at: Vector2) -> int:
	for i: int in belt_count:
		var y: float = belt_y(i)
		var span: Vector2 = belt_span(i)
		if at.y <= y and at.y >= y - CONTACT and at.x >= span.x and at.x <= span.y:
			return i
	return -1


## How much faster (positive) or slower than belt `index` the fish `marble_id` rides it.
func knack(marble_id: int, index: int) -> float:
	var h: int = absi(hash(Vector3i(_knack_seed, marble_id, index)))
	return (float(h % 2001) / 1000.0 - 1.0) * KNACK


func _physics_process(delta: float) -> void:
	clock += delta
	for i: int in belt_count:
		_travel[i] += belt_velocity(i) * delta
	for node: Node in get_tree().get_nodes_in_group(Marble.GROUP):
		var marble: Marble = node as Marble
		if marble.freeze or marble.eaten:
			continue
		var index: int = belt_under(marble.global_position)
		if index < 0:
			# A fish lodged anywhere off the belts (between the pegs) flops its way free.
			if marble.linear_velocity.length() < STILL_SPEED:
				_flop(marble, -1)
			continue
		var target: float = belt_velocity(index) * (1.0 + knack(marble.id, index))
		var push: float = (target - marble.linear_velocity.x) * GRIP * marble.mass
		marble.apply_central_force(Vector2(push, 0.0))
		_flop(marble, index)
	queue_redraw()


## A seeded share in [0, 1) for flop number `count` of fish `marble_id`; `salt` picks the value.
func _draw_flop(marble_id: int, count: int, salt: int) -> float:
	return float(absi(hash(Vector4i(_knack_seed, marble_id, count, salt))) % 10000) / 10000.0


## Hops the fish when its next flop is due, once it rests on belt `index`. Off the belts (`index`
## -1) the seed picks the side it hops to.
func _flop(marble: Marble, index: int) -> void:
	var count: int = int(_flops.get(marble.id, 0))
	if not _next_flop.has(marble.id):
		_next_flop[marble.id] = clock + lerpf(FLOP_MIN, FLOP_MAX, _draw_flop(marble.id, 0, 0))
	if clock < float(_next_flop[marble.id]) or absf(marble.linear_velocity.y) > 30.0:
		return
	var share: float = _draw_flop(marble.id, count, 1)
	var hop: float = lerpf(-1.0, 1.0, share) * FLOP_AHEAD
	if index >= 0:
		hop = direction(index) * lerpf(-0.3, 1.0, share) * FLOP_AHEAD
	marble.apply_central_impulse(Vector2(hop, -FLOP_UP) * marble.mass)
	_flops[marble.id] = count + 1
	_next_flop[marble.id] = clock + lerpf(FLOP_MIN, FLOP_MAX, _draw_flop(marble.id, count + 1, 0))


func _apply_speeds() -> void:
	for i: int in _bodies.size():
		_bodies[i].constant_linear_velocity = Vector2(belt_velocity(i), 0.0)
	for chef: SushiChef in _chefs:
		var index: int = nearest_belt(chef.global_position.y)
		var span: Vector2 = belt_span(index)
		var far_end: float = span.y if direction(index) > 0.0 else span.x
		chef.set_belt(direction(index), _speeds[index], far_end)


## Index of the belt whose top is nearest world y `y`.
func nearest_belt(y: float) -> int:
	return clampi(roundi((y - top_y) / spacing), 0, belt_count - 1)


## The route: along each belt to its far end, down the drop and back along the next.
func _route() -> Curve2D:
	var result: Curve2D = Curve2D.new()
	var lane: float = Marble.RADIUS + 4.0
	for i: int in belt_count:
		var y: float = belt_y(i) - lane
		var span: Vector2 = belt_span(i)
		var gap: float = drop_width * 0.5
		if direction(i) > 0.0:
			result.add_point(Vector2(span.x + gap, y))
			result.add_point(Vector2(span.y + gap, y))
		else:
			result.add_point(Vector2(span.y - gap, y))
			result.add_point(Vector2(span.x - gap, y))
	var last: Vector2 = result.get_point_position(result.point_count - 1)
	result.add_point(Vector2(last.x, belt_y(belt_count - 1) + spacing * 0.7))
	return result


func _build_belts() -> void:
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.1
	for i: int in belt_count:
		var span: Vector2 = belt_span(i)
		var y: float = belt_y(i)
		var body: StaticBody2D = StaticBody2D.new()
		body.name = "Belt%d" % (i + 1)
		body.physics_material_override = material
		var shape: CollisionPolygon2D = CollisionPolygon2D.new()
		shape.name = "Collider"
		var round_end: float = thickness * 0.5
		var outline: PackedVector2Array = PackedVector2Array([Vector2(span.x + round_end, y)])
		for x: float in hump_xs(i):
			outline.append(Vector2(x - HUMP_HALF, y))
			outline.append(Vector2(x - HUMP_HALF * 0.5, y - HUMP_HEIGHT * 0.8))
			outline.append(Vector2(x, y - HUMP_HEIGHT))
			outline.append(Vector2(x + HUMP_HALF * 0.5, y - HUMP_HEIGHT * 0.8))
			outline.append(Vector2(x + HUMP_HALF, y))
		(
			outline
			. append_array(
				PackedVector2Array(
					[
						Vector2(span.y - round_end, y),
						Vector2(span.y, y + round_end),
						Vector2(span.y - round_end, y + thickness),
						Vector2(span.x + round_end, y + thickness),
						Vector2(span.x, y + round_end),
					]
				)
			)
		)
		shape.polygon = outline
		body.add_child(shape)
		add_child(body)
		_bodies.append(body)


## World xs of the humps on belt `index`, left to right.
func hump_xs(index: int) -> PackedFloat32Array:
	var span: Vector2 = belt_span(index)
	var xs: PackedFloat32Array = PackedFloat32Array()
	for fraction: float in HUMPS:
		var x: float = lerpf(span.x, span.y, fraction)
		var clear: bool = true
		for chef: Node in get_children():
			if chef is SushiChef and nearest_belt((chef as Node2D).position.y) == index:
				clear = clear and absf((chef as Node2D).position.x - x) >= CHEF_CLEAR
		if clear:
			xs.append(x)
	return xs


## The counter's side walls, the floor, and the counter under the last belt, so a fish that drops
## off it can only land in the finish.
func _build_walls() -> void:
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.4
	material.bounce = 0.3
	var bottom: float = 1120.0
	var walls: Array[PackedVector2Array] = [
		PackedVector2Array(
			[
				Vector2(left_x - 120.0, -400.0),
				Vector2(left_x, -400.0),
				Vector2(left_x, bottom),
				Vector2(left_x - 120.0, bottom)
			]
		),
		PackedVector2Array(
			[
				Vector2(right_x, -400.0),
				Vector2(right_x + 120.0, -400.0),
				Vector2(right_x + 120.0, bottom),
				Vector2(right_x, bottom)
			]
		),
		_under_last_belt(),
		PackedVector2Array(
			[
				Vector2(left_x - 120.0, 1050.0),
				Vector2(right_x + 120.0, 1050.0),
				Vector2(right_x + 120.0, bottom),
				Vector2(left_x - 120.0, bottom)
			]
		),
	]
	for i: int in walls.size():
		var body: StaticBody2D = StaticBody2D.new()
		body.name = "Wall%d" % (i + 1)
		body.physics_material_override = material
		body.add_to_group(STONE_GROUP)
		var shape: CollisionPolygon2D = CollisionPolygon2D.new()
		shape.name = "Collider"
		shape.polygon = walls[i]
		body.add_child(shape)
		var visual: Polygon2D = Polygon2D.new()
		visual.name = "Visual"
		visual.polygon = walls[i]
		body.add_child(visual)
		add_child(body)


func _build_pegs() -> void:
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.2
	material.bounce = 0.6
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = PEG_RADIUS
	for row: int in PEG_ROWS.size():
		var count: int = PEGS_PER_ROW - row % 2
		for i: int in count:
			var at: Vector2 = Vector2(
				start_x + (float(i) - float(count - 1) * 0.5) * PEG_SPACING, top_y - PEG_ROWS[row]
			)
			var body: StaticBody2D = StaticBody2D.new()
			body.name = "Peg%d_%d" % [row + 1, i + 1]
			body.physics_material_override = material
			body.add_to_group(STONE_GROUP)
			var shape: CollisionShape2D = CollisionShape2D.new()
			shape.name = "Collider"
			shape.shape = circle
			shape.position = at
			body.add_child(shape)
			var visual: Polygon2D = Polygon2D.new()
			visual.name = "Visual"
			visual.color = peg_color
			var points: PackedVector2Array = PackedVector2Array()
			for k: int in 16:
				points.append(at + Vector2.from_angle(TAU * float(k) / 16.0) * PEG_RADIUS)
			visual.polygon = points
			body.add_child(visual)
			add_child(body)


## A jammed belt: a red flash while it warns, and chevrons pointing the way it runs once it has
## turned round.
func _draw_jam(index: int, rect: Rect2) -> void:
	var warning: float = _warnings[index]
	var backwards: float = clampf(-_factors[index] / BeltReverseHazard.REVERSE, 0.0, 1.0)
	if warning <= 0.0 and backwards <= 0.0:
		return
	var flash: float = warning * (0.5 + 0.5 * sin(clock * 20.0)) + backwards * 0.6
	draw_rect(rect, Color(1.0, 0.2, 0.15, 0.5 * flash))
	if backwards <= 0.0:
		return
	var way: float = -direction(index)
	var y: float = rect.position.y + rect.size.y * 0.5
	var x: float = rect.position.x + 60.0
	while x < rect.end.x - 40.0:
		draw_polyline(
			PackedVector2Array(
				[
					Vector2(x - way * 7.0, y - 8.0),
					Vector2(x + way * 7.0, y),
					Vector2(x - way * 7.0, y + 8.0),
				]
			),
			Color(1.0, 0.9, 0.8, backwards),
			3.0,
			true
		)
		x += 160.0


## The solid counter from the underside of the last belt down to the floor.
func _under_last_belt() -> PackedVector2Array:
	var last: int = belt_count - 1
	var span: Vector2 = belt_span(last)
	var top: float = belt_y(last) + thickness
	return PackedVector2Array(
		[
			Vector2(span.x, top),
			Vector2(span.y, top),
			Vector2(span.y, 1060.0),
			Vector2(span.x, 1060.0)
		]
	)


## Part of the finish replay ([Replayable]): the clock and how far each belt's slats have moved.
## A jam replays through its hazard.
func replay_state() -> PackedFloat32Array:
	var state: PackedFloat32Array = PackedFloat32Array([clock])
	state.append_array(_travel)
	return state


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	clock = Replayable.mix(from, to, weight, 0)
	for i: int in belt_count:
		_travel[i] = Replayable.mix(from, to, weight, 1 + i)
	queue_redraw()


func _draw() -> void:
	for i: int in belt_count:
		_draw_belt(i)


## One belt: a dark band with a lit top edge and slats that run toward its far end.
func _draw_belt(index: int) -> void:
	var span: Vector2 = belt_span(index)
	var y: float = belt_y(index)
	var rect: Rect2 = Rect2(span.x, y, span.y - span.x, thickness)
	draw_rect(rect, belt_color)
	var shift: float = fposmod(_travel[index], SLAT)
	var x: float = span.x + shift - SLAT
	while x < span.y:
		if x > span.x + 4.0:
			draw_line(Vector2(x, y + 3.0), Vector2(x, y + thickness - 3.0), slat_color, 3.0)
		x += SLAT
	draw_line(Vector2(span.x, y), Vector2(span.y, y), Color(rim, 0.8), 2.0, true)
	_draw_jam(index, rect)
	for end: float in [span.x, span.y]:
		draw_circle(Vector2(end, y + thickness * 0.5), thickness * 0.5, slat_color)
		draw_circle(Vector2(end, y + thickness * 0.5), 4.0, Color(rim, 0.6))
	# The humps are dabs of wasabi on little dishes.
	for hump: float in hump_xs(index):
		draw_rect(Rect2(hump - HUMP_HALF - 4.0, y - 3.0, HUMP_HALF * 2.0 + 8.0, 4.0), slat_color)
		var dab: PackedVector2Array = PackedVector2Array()
		for k: int in 13:
			var a: float = PI + PI * float(k) / 12.0
			dab.append(Vector2(hump + cos(a) * HUMP_HALF, y - 2.0 + sin(a) * HUMP_HEIGHT))
		draw_colored_polygon(dab, hump_color)
		draw_circle(Vector2(hump - 4.0, y - HUMP_HEIGHT * 0.6), 2.5, hump_color.lightened(0.4))
