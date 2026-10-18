class_name SnakeBoard
extends Path2D
## The board of Board Game: Snakes and Ladders, ten rows of ten squares. This node is the map's
## `Centerline`: it builds the route, the shelves the fish roll along, the start pen and the
## winners' tray, and draws the board. Square 1 is bottom left, the rows run back and forth and
## square 100, the finish, is top left. A current carries the fish along every row, and at the end
## of a row a bubble lift takes them up to the next one.
##
## The [BoardDice] beside the board rolls every few seconds, sooner when chat spams "#roll". Every
## fish on the board then hops that many squares on. A fish that lands at the foot of a ladder
## climbs it, one that lands on a snake's head slides down to its tail. Rolling past one does
## nothing, as on a real board. Fish in the pen are not on the board yet and do not hop. The snakes
## fall asleep late in a race, so every race ends. Time advances only in physics frames.

## A particle burst was let off, for the finish replay to play again.
signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)
## The dice meter changed. Empty text hides it.
signal meter_changed(text: String)

enum Move { HOP, LADDER, SNAKE, LIFT, TRAY }

const COLS: int = 10
const ROWS: int = 10
const LAST_SQUARE: int = COLS * ROWS
## Size of a square, and the bottom left corner of the board.
const CELL: Vector2 = Vector2(110.0, 96.0)
const ORIGIN: Vector2 = Vector2(410.0, 1040.0)
## Thickness of the shelves between the rows, and of the walls round the board.
const SHELF: float = 10.0
const WALL: float = 30.0
## Ladders, foot square to top square, and snakes, head square to tail square.
const LADDERS: Dictionary = {3: 22, 8: 30, 20: 41, 28: 55, 36: 57, 51: 72, 63: 81, 71: 92}
const SNAKES: Dictionary = {17: 7, 34: 12, 47: 26, 62: 19, 64: 43, 87: 48, 93: 73, 95: 75, 98: 79}
## Speed the current along a row carries the fish at, in pixels per second, and how hard it pulls
## a slower fish up to it (per second).
const FLOW_SPEED: float = 360.0
const FLOW_GRIP: float = 4.0
## Seconds a hop from one square to the next takes, and how high the fish jumps.
const HOP_STEP: float = 0.11
const HOP_HEIGHT: float = 34.0
## Speeds in pixels per second of a fish climbing a ladder, sliding down a snake, riding a lift and
## being carried to the winners' tray.
const LADDER_SPEED: float = 520.0
const SNAKE_SPEED: float = 640.0
const LIFT_SPEED: float = 560.0
const TRAY_SPEED: float = 700.0
## Race second at which the snakes fall asleep and stop biting.
const SNAKE_SLEEP: float = 28.0
## How far outside the board the lift tubes run.
const LIFT_OUT: float = 32.0
## The start pen left of square 1, and the winners' tray above it.
const PEN_LEFT: float = 40.0
const PEN_TOP: float = 640.0
const TRAY: Rect2 = Rect2(50.0, 230.0, 300.0, 190.0)
## Fish dropped into the tray per row of drop spots.
const TRAY_SLOTS: int = 9
const DICE_POSITION: Vector2 = Vector2(1735.0, 360.0)

const SQUARE_COLORS: Array[Color] = [
	Color(0.96, 0.58, 0.47),
	Color(0.98, 0.84, 0.52),
	Color(0.5, 0.82, 0.66),
	Color(0.52, 0.74, 0.95),
	Color(0.78, 0.62, 0.92),
]
const NUMBER_COLOR: Color = Color(0.16, 0.12, 0.2, 0.85)
const SHELF_COLOR: Color = Color(0.32, 0.2, 0.12)
const SHELF_LIGHT: Color = Color(0.62, 0.42, 0.24)
const LADDER_COLOR: Color = Color(0.72, 0.48, 0.24)
const LADDER_LIGHT: Color = Color(0.95, 0.75, 0.42)
const SNAKE_COLORS: Array[Color] = [
	Color(0.3, 0.75, 0.25),
	Color(0.85, 0.3, 0.25),
	Color(0.95, 0.65, 0.15),
	Color(0.35, 0.45, 0.9),
	Color(0.7, 0.3, 0.75),
]
const GLASS_COLOR: Color = Color(0.7, 0.92, 1.0)
const CLIMB_COLOR: Color = Color(1.0, 0.85, 0.35)
const BITE_COLOR: Color = Color(0.6, 1.0, 0.35)
const WIN_COLOR: Color = Color(1.0, 0.86, 0.3)

## Seconds since the race started, advanced by [method tick].
var clock: float = 0.0

var _armed: bool = false
var _dice: BoardDice
var _links: Node2D
## Fish being moved by the board: instance id -> the move (see [method _start_move]).
var _moves: Dictionary = {}
## Instance ids of the fish already carried to the tray.
var _in_tray: Dictionary = {}
## Instance id -> the last square a fish was seen on, to put back a fish knocked off the board.
var _last_square: Dictionary = {}
var _lift_count: int = 0
var _climbs: int = 0
var _bites: int = 0
## Link key (its start square) -> seconds its flash has left.
var _flashes: Dictionary = {}
var _time: float = 0.0


func _ready() -> void:
	curve = _route_curve()
	_build_walls()
	_links = Node2D.new()
	_links.name = "Links"
	# The board is far behind the fish, the ladders and snakes just behind them.
	z_index = -20
	_links.z_index = 19
	_links.draw.connect(_draw_links)
	add_child(_links)
	_dice = BoardDice.new()
	_dice.name = "Dice"
	_dice.position = DICE_POSITION
	_dice.z_index = 25
	add_child(_dice)
	_dice.rolled.connect(_on_rolled)
	_dice.meter_changed.connect(meter_changed.emit)


func _physics_process(delta: float) -> void:
	tick(delta)


func _process(delta: float) -> void:
	_time += delta
	for key: int in _flashes.keys():
		var left: float = float(_flashes[key]) - delta
		if left <= 0.0:
			_flashes.erase(key)
		else:
			_flashes[key] = left
	_links.queue_redraw()


## Plans the rolls of a race from `seed_value` and arms the board.
func reseed(seed_value: int) -> void:
	stop_gimmick()
	_dice.reseed(seed_value)
	_armed = true


## Stops everything and lets go of every fish the board was moving.
func stop_gimmick() -> void:
	_armed = false
	_end_moves()
	_in_tray.clear()
	_last_square.clear()
	_flashes.clear()
	clock = 0.0
	_lift_count = 0
	_climbs = 0
	_bites = 0
	_dice.stop()


## Ends the board for good at the end of a race: no more rolls, and the fish being moved stay
## where they are. [method stop_gimmick] readies it again.
func freeze() -> void:
	if not _armed:
		return
	_armed = false
	_end_moves()
	_dice.freeze()


func is_armed() -> bool:
	return _armed


func get_dice() -> BoardDice:
	return _dice


## Whether the snakes still bite.
func snakes_awake() -> bool:
	return clock < SNAKE_SLEEP


## How many ladders were climbed and snakes slid down this race.
func climb_count() -> int:
	return _climbs


func bite_count() -> int:
	return _bites


## Whether the board is moving `marble` right now (a hop, a ladder, a snake or a lift).
func is_moving(marble: Marble) -> bool:
	return _moves.has(marble.get_instance_id())


## Kind of the move the board has `marble` in, or -1.
func move_of(marble: Marble) -> int:
	var move: Dictionary = _moves.get(marble.get_instance_id(), {})
	return int(move.get("kind", -1))


func tick(delta: float) -> void:
	if not _armed:
		return
	clock += delta
	_dice.tick(delta)
	if not _armed:
		return
	_advance_moves(delta)
	for marble: Marble in _fish():
		if marble.eaten or marble.replaying or _moves.has(marble.get_instance_id()):
			continue
		if marble.has_finished:
			if not _in_tray.has(marble.get_instance_id()):
				_send_to_tray(marble)
			continue
		var square: int = square_at(marble.global_position)
		if square >= 1:
			_last_square[marble.get_instance_id()] = square
		elif _astray(marble.global_position):
			_rescue(marble)
			continue
		if not _lift(marble):
			_flow(marble)


## Every fish on the board hops `value` squares on (see the class notes).
func roll(value: int) -> void:
	if not _armed:
		return
	var landings: PackedVector2Array = PackedVector2Array()
	for marble: Marble in _fish():
		if (
			marble.eaten
			or marble.replaying
			or marble.has_finished
			or _moves.has(marble.get_instance_id())
		):
			continue
		var from: int = square_at(marble.global_position)
		if from < 1:
			continue
		var to: int = mini(from + value, LAST_SQUARE)
		var along: float = (
			(marble.global_position.x - square_center(from).x) * row_dir(_row_of(from))
		)
		along = clampf(
			along, -CELL.x * 0.5 + Marble.RADIUS + 2.0, CELL.x * 0.5 - Marble.RADIUS - 2.0
		)
		var points: PackedVector2Array = PackedVector2Array([marble.global_position])
		for square: int in range(from + 1, to + 1):
			points.append(_spot(square, along))
		points[-1] = _free_landing(points[-1], to, landings)
		landings.append(points[-1])
		_start_move(marble, Move.HOP, points, to)


## Square (1 to 100) under a global position, or 0 off the board (the pen and the tray).
static func square_at(global_pos: Vector2) -> int:
	if global_pos.x < ORIGIN.x or global_pos.x > ORIGIN.x + CELL.x * COLS:
		return 0
	if global_pos.y > ORIGIN.y or global_pos.y < ORIGIN.y - CELL.y * ROWS:
		return 0
	var row: int = clampi(floori((ORIGIN.y - global_pos.y) / CELL.y), 0, ROWS - 1)
	var col: int = clampi(floori((global_pos.x - ORIGIN.x) / CELL.x), 0, COLS - 1)
	return row * COLS + (col if row_dir(row) > 0 else COLS - 1 - col) + 1


## Where a fish rests in the middle of `square` (1 to 100).
static func square_center(square: int) -> Vector2:
	var row: int = _row_of(square)
	return Vector2(ORIGIN.x + (float(_col_of(square)) + 0.5) * CELL.x, lane_y(row))


## The area of `square` (1 to 100) on the board.
static func square_rect(square: int) -> Rect2:
	var row: int = _row_of(square)
	return Rect2(
		ORIGIN.x + float(_col_of(square)) * CELL.x,
		ORIGIN.y - float(row + 1) * CELL.y,
		CELL.x,
		CELL.y
	)


## World y of a fish rolling along row `row` (0 is the bottom row).
static func lane_y(row: int) -> float:
	return ORIGIN.y - float(row) * CELL.y - SHELF - Marble.RADIUS - 1.0


## Which way row `row` runs: 1 to the right, -1 to the left.
static func row_dir(row: int) -> int:
	return 1 if row % 2 == 0 else -1


## The middle line of a snake from its head to its tail, as points along its body.
static func snake_points(head: int, tail: int) -> PackedVector2Array:
	var from: Vector2 = square_center(head)
	var to: Vector2 = square_center(tail)
	var span: Vector2 = to - from
	var side: Vector2 = span.orthogonal().normalized()
	var waves: float = maxf(1.5, roundf(span.length() / 160.0) - 0.5)
	var points: PackedVector2Array = PackedVector2Array()
	var count: int = 28
	for i: int in count + 1:
		var u: float = float(i) / float(count)
		points.append(from + span * u + side * sin(u * TAU * waves * 0.5) * 24.0)
	return points


static func _row_of(square: int) -> int:
	return (square - 1) / COLS


static func _col_of(square: int) -> int:
	var in_row: int = (square - 1) % COLS
	return in_row if row_dir(_row_of(square)) > 0 else COLS - 1 - in_row


static func _right() -> float:
	return ORIGIN.x + CELL.x * COLS


static func _top() -> float:
	return ORIGIN.y - CELL.y * ROWS


## A spot in `square`, `along` pixels ahead of its middle in the direction its row runs.
func _spot(square: int, along: float) -> Vector2:
	return square_center(square) + Vector2(along * float(row_dir(_row_of(square))), 0.0)


## Moves a landing spot back along its row until no other fish of the same roll lands there.
func _free_landing(at: Vector2, square: int, taken: PackedVector2Array) -> Vector2:
	var step: float = -float(row_dir(_row_of(square))) * (Marble.RADIUS * 2.0 + 4.0)
	var low: float = ORIGIN.x + Marble.RADIUS + 2.0
	var high: float = _right() - Marble.RADIUS - 2.0
	for attempt: int in 12:
		var clear: bool = true
		for other: Vector2 in taken:
			if other.distance_to(at) < Marble.RADIUS * 2.0 + 2.0:
				clear = false
				break
		if clear:
			return at
		at.x += step
		if at.x < low or at.x > high:
			step = -step
			at.x = clampf(at.x + step * 2.0, low, high)
	return at


func _fish() -> Array[Marble]:
	var found: Array[Marble] = []
	for node: Node in get_tree().get_nodes_in_group(Marble.GROUP):
		found.append(node as Marble)
	return found


## The current of the rows: pulls a fish up to [constant FLOW_SPEED] the way its row runs. It never
## holds a faster fish back.
func _flow(marble: Marble) -> void:
	var at: Vector2 = marble.global_position
	if at.y > ORIGIN.y or at.y < _top():
		return
	var direction: int = 0
	if at.x < ORIGIN.x:
		# The pen feeds the bottom row; the tray above it has no current.
		direction = 1 if at.y > PEN_TOP else 0
	else:
		direction = row_dir(clampi(floori((ORIGIN.y - at.y) / CELL.y), 0, ROWS - 1))
	if direction == 0:
		return
	var speed: float = marble.linear_velocity.x * float(direction)
	if speed < FLOW_SPEED:
		marble.apply_central_force(
			Vector2(float(direction) * FLOW_GRIP * (FLOW_SPEED - speed) * marble.mass, 0.0)
		)


## Sends a fish that reached the end of a row up the lift to the next row. Returns whether it did.
func _lift(marble: Marble) -> bool:
	var square: int = square_at(marble.global_position)
	if square < 1:
		return false
	var row: int = _row_of(square)
	if row >= ROWS - 1:
		return false
	var direction: int = row_dir(row)
	var x: float = marble.global_position.x
	var reach: float = Marble.RADIUS + 6.0
	if direction > 0 and x < _right() - reach:
		return false
	if direction < 0 and x > ORIGIN.x + reach:
		return false
	var tube: float = _right() + LIFT_OUT if direction > 0 else ORIGIN.x - LIFT_OUT
	var slot: float = float(_lift_count % 3)
	_lift_count += 1
	var exit_x: float = x - float(direction) * (Marble.RADIUS + 10.0 + slot * 30.0)
	var points: PackedVector2Array = PackedVector2Array(
		[
			marble.global_position,
			Vector2(tube, lane_y(row)),
			Vector2(tube, lane_y(row + 1)),
			Vector2(exit_x, lane_y(row + 1)),
		]
	)
	_start_move(marble, Move.LIFT, points, square_at(points[-1]))
	return true


## Carries a fish that finished off the board and drops it in the winners' tray.
func _send_to_tray(marble: Marble) -> void:
	var count: int = _in_tray.size()
	_in_tray[marble.get_instance_id()] = true
	var slot_x: float = TRAY.position.x + 22.0 + float(count % TRAY_SLOTS) * 32.0
	var points: PackedVector2Array = PackedVector2Array(
		[
			marble.global_position,
			Vector2(ORIGIN.x - LIFT_OUT, marble.global_position.y),
			Vector2(slot_x, TRAY.position.y + 20.0),
		]
	)
	_start_move(marble, Move.TRAY, points, 0)


## Takes `marble` out of the physics and moves it along `points` (global). `square` is where the
## move ends on the board, or 0.
func _start_move(marble: Marble, kind: Move, points: PackedVector2Array, square: int) -> void:
	var key: int = marble.get_instance_id()
	var layer: int = marble.collision_layer
	var mask: int = marble.collision_mask
	if _moves.has(key):
		# A move that chains on from another (a hop onto a ladder) keeps the saved layers.
		layer = int(_moves[key]["layer"])
		mask = int(_moves[key]["mask"])
	var times: PackedFloat32Array = PackedFloat32Array([0.0])
	for i: int in range(1, points.size()):
		var length: float = points[i].distance_to(points[i - 1])
		var seconds: float = HOP_STEP
		match kind:
			Move.LADDER:
				seconds = length / LADDER_SPEED
			Move.SNAKE:
				seconds = length / SNAKE_SPEED
			Move.LIFT:
				seconds = length / LIFT_SPEED
			Move.TRAY:
				seconds = length / TRAY_SPEED
		times.append(times[-1] + maxf(seconds, 0.02))
	_moves[key] = {
		"marble": marble,
		"kind": kind,
		"points": points,
		"times": times,
		"t": 0.0,
		"square": square,
		"layer": layer,
		"mask": mask,
	}
	marble.collision_layer = 0
	marble.collision_mask = 0
	marble.linear_velocity = Vector2.ZERO
	marble.angular_velocity = 0.0
	marble.freeze = true


func _advance_moves(delta: float) -> void:
	for key: int in _moves.keys():
		if not _moves.has(key):
			continue
		var move: Dictionary = _moves[key]
		var marble: Marble = move["marble"]
		if not is_instance_valid(marble) or not marble.is_inside_tree():
			_moves.erase(key)
			continue
		if marble.eaten:
			# Snapped mid-move: the fish is out and keeps the state the snap gave it.
			_moves.erase(key)
			continue
		move["t"] = float(move["t"]) + delta
		var times: PackedFloat32Array = move["times"]
		if float(move["t"]) < times[-1]:
			marble.global_position = _position_on(move)
			continue
		var points: PackedVector2Array = move["points"]
		marble.global_position = points[-1]
		_finish_move(marble, move)


## Where a move has got to.
func _position_on(move: Dictionary) -> Vector2:
	var points: PackedVector2Array = move["points"]
	var times: PackedFloat32Array = move["times"]
	var t: float = float(move["t"])
	var i: int = 1
	while i < times.size() - 1 and t > times[i]:
		i += 1
	var u: float = clampf((t - times[i - 1]) / maxf(times[i] - times[i - 1], 0.001), 0.0, 1.0)
	var at: Vector2 = points[i - 1].lerp(points[i], u)
	if int(move["kind"]) == Move.HOP:
		at.y -= HOP_HEIGHT * 4.0 * u * (1.0 - u)
	return at


func _finish_move(marble: Marble, move: Dictionary) -> void:
	var square: int = int(move["square"])
	var kind: int = int(move["kind"])
	if kind == Move.HOP and LADDERS.has(square):
		_climbs += 1
		_flashes[square] = 1.2
		_burst(marble.global_position, CLIMB_COLOR)
		var top: int = int(LADDERS[square])
		var along: float = (
			(marble.global_position.x - square_center(square).x) * row_dir(_row_of(square))
		)
		_start_move(
			marble,
			Move.LADDER,
			PackedVector2Array([marble.global_position, _spot(top, along)]),
			top
		)
		return
	if kind == Move.HOP and SNAKES.has(square) and snakes_awake():
		_bites += 1
		_flashes[square] = 1.2
		_burst(marble.global_position, BITE_COLOR)
		var points: PackedVector2Array = snake_points(square, int(SNAKES[square]))
		points[0] = marble.global_position
		_start_move(marble, Move.SNAKE, points, int(SNAKES[square]))
		return
	if kind != Move.TRAY and square >= 1:
		# Never drop a fish onto another one: the push apart could throw it through a shelf.
		marble.global_position = _clear_spot(marble, marble.global_position, square)
	_moves.erase(marble.get_instance_id())
	marble.collision_layer = int(move["layer"])
	marble.collision_mask = int(move["mask"])
	marble.freeze = false
	if kind == Move.TRAY:
		marble.linear_velocity = Vector2.ZERO
		return
	if square >= 1:
		var direction: int = row_dir(_row_of(square))
		marble.linear_velocity = Vector2(float(direction) * FLOW_SPEED * 0.5, 0.0)
	if kind == Move.LADDER:
		_burst(marble.global_position, CLIMB_COLOR)


## The nearest spot in the row of `square` to `at` where `marble` touches no other fish: tries
## behind first, then ahead.
func _clear_spot(marble: Marble, at: Vector2, square: int) -> Vector2:
	var row: int = _row_of(square)
	var back: float = -float(row_dir(row)) * (Marble.RADIUS * 2.0 + 4.0)
	var low: float = ORIGIN.x + Marble.RADIUS + 2.0
	var high: float = _right() - Marble.RADIUS - 2.0
	var others: PackedVector2Array = PackedVector2Array()
	for other: Marble in _fish():
		if other != marble and not other.eaten and not _moves.has(other.get_instance_id()):
			others.append(other.global_position)
	for attempt: int in 13:
		var step: int = (attempt + 1) / 2 * (1 if attempt % 2 == 1 else -1)
		var spot: Vector2 = Vector2(clampf(at.x + back * float(step), low, high), lane_y(row))
		var clear: bool = true
		for other: Vector2 in others:
			if other.distance_to(spot) < Marble.RADIUS * 2.0 + 2.0:
				clear = false
				break
		if clear:
			return spot
	return Vector2(clampf(at.x, low, high), lane_y(row))


## Whether a free fish at `at` has left the board, the pen and the tray (knocked through a wall).
func _astray(at: Vector2) -> bool:
	return (
		at.y > ORIGIN.y + Marble.RADIUS
		or at.y < _top() - Marble.RADIUS * 3.0
		or at.x > _right() + Marble.RADIUS
		or at.x < PEN_LEFT - Marble.RADIUS
	)


## Puts a fish that was knocked off the board back on the last square it was on.
func _rescue(marble: Marble) -> void:
	var square: int = int(_last_square.get(marble.get_instance_id(), 1))
	var points: PackedVector2Array = PackedVector2Array(
		[marble.global_position, square_center(square)]
	)
	_start_move(marble, Move.LIFT, points, square)


## Lets go of every fish the board was moving, where it is. Its collisions come back; whoever
## stopped the race decides whether it stays frozen.
func _end_moves() -> void:
	for key: int in _moves.keys():
		var move: Dictionary = _moves[key]
		var marble: Marble = move["marble"]
		if is_instance_valid(marble) and not marble.eaten:
			marble.collision_layer = int(move["layer"])
			marble.collision_mask = int(move["mask"])
	_moves.clear()


func _burst(at: Vector2, color: Color) -> void:
	RaceFx.burst(self, at, color, 16, 130.0, Vector2.ZERO)
	burst_played.emit(at, color, 16, 130.0, Vector2.ZERO)


func _on_rolled(value: int) -> void:
	roll(value)


## The route of the fish: out of the pen along the bottom row, then up the board row by row.
func _route_curve() -> Curve2D:
	var route: Curve2D = Curve2D.new()
	var inset: float = Marble.RADIUS + 1.0
	route.add_point(Vector2(PEN_LEFT + inset, lane_y(0)))
	for row: int in ROWS:
		var y: float = lane_y(row)
		if row_dir(row) > 0:
			route.add_point(Vector2(ORIGIN.x + inset, y))
			route.add_point(Vector2(_right() - inset, y))
		else:
			route.add_point(Vector2(_right() - inset, y))
			route.add_point(Vector2(ORIGIN.x + inset, y))
	return route


func _build_walls() -> void:
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.3
	material.bounce = 0.2
	var right: float = _right()
	var top: float = _top()
	var rects: Array[Rect2] = [
		# The ceiling over the top row. The outer walls are thick, so no fish is knocked through.
		Rect2(ORIGIN.x - WALL, top - WALL, right - ORIGIN.x + WALL * 2.0, WALL),
		# The left wall stops above the bottom row, where the pen feeds in.
		Rect2(ORIGIN.x - WALL, top - WALL, WALL, CELL.y * (ROWS - 1) + WALL),
		Rect2(right, top - WALL, WALL, CELL.y * ROWS + WALL),
		# The pen wall and the floor under the pen and the bottom row.
		Rect2(PEN_LEFT - WALL, PEN_TOP, WALL, ORIGIN.y - PEN_TOP),
		Rect2(PEN_LEFT - WALL, ORIGIN.y - SHELF, right - PEN_LEFT + WALL * 2.0, WALL),
		# The winners' tray.
		Rect2(TRAY.position.x - SHELF, TRAY.position.y, SHELF, TRAY.size.y),
		Rect2(TRAY.end.x, TRAY.position.y + 40.0, SHELF, TRAY.size.y - 40.0),
		Rect2(TRAY.position.x - SHELF, TRAY.end.y, TRAY.size.x + SHELF * 2.0, SHELF),
	]
	# The shelves between the rows: each is the floor of the row above it.
	for row: int in range(1, ROWS):
		var y: float = ORIGIN.y - float(row) * CELL.y - SHELF
		rects.append(Rect2(ORIGIN.x, y, right - ORIGIN.x, SHELF))
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Walls"
	body.physics_material_override = material
	for rect: Rect2 in rects:
		var shape: CollisionShape2D = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		body.add_child(shape)
	add_child(body)


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var right: float = _right()
	var top: float = _top()
	# A frame round the board, then the squares.
	draw_rect(
		Rect2(ORIGIN.x - 18.0, top - 18.0, right - ORIGIN.x + 36.0, ORIGIN.y - top + 26.0),
		SHELF_COLOR
	)
	for square: int in range(1, LAST_SQUARE + 1):
		var rect: Rect2 = square_rect(square)
		var row: int = _row_of(square)
		var col: int = _col_of(square)
		var color: Color = SQUARE_COLORS[(row * 3 + col) % SQUARE_COLORS.size()]
		if (row + col) % 2 == 1:
			color = color.lightened(0.25)
		if square == LAST_SQUARE:
			color = WIN_COLOR
		draw_rect(rect, color)
		draw_string(
			font,
			rect.position + Vector2(6.0, 20.0),
			str(square),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			17,
			NUMBER_COLOR
		)
	draw_string(
		font,
		square_rect(LAST_SQUARE).position + Vector2(0.0, 52.0),
		"FINISH",
		HORIZONTAL_ALIGNMENT_CENTER,
		CELL.x,
		20,
		NUMBER_COLOR
	)
	# The shelves the fish roll on.
	for row: int in ROWS + 1:
		var y: float = ORIGIN.y - float(row) * CELL.y - SHELF
		draw_rect(Rect2(ORIGIN.x, y, right - ORIGIN.x, SHELF), SHELF_COLOR)
		draw_line(Vector2(ORIGIN.x, y), Vector2(right, y), SHELF_LIGHT, 2.0)
	_draw_lift(right + LIFT_OUT, lane_y(0), lane_y(ROWS - 2))
	_draw_lift(ORIGIN.x - LIFT_OUT, lane_y(1), lane_y(ROWS - 1))
	# The pen and the tray.
	draw_rect(Rect2(PEN_LEFT - SHELF, PEN_TOP, SHELF, ORIGIN.y - PEN_TOP), SHELF_COLOR)
	draw_rect(
		Rect2(PEN_LEFT - SHELF, ORIGIN.y - SHELF, ORIGIN.x - PEN_LEFT + SHELF, SHELF * 3.0),
		SHELF_COLOR
	)
	draw_rect(Rect2(TRAY.position, TRAY.size), Color(WIN_COLOR, 0.12))
	draw_rect(Rect2(TRAY.position.x - SHELF, TRAY.position.y, SHELF, TRAY.size.y), SHELF_COLOR)
	draw_rect(Rect2(TRAY.end.x, TRAY.position.y + 40.0, SHELF, TRAY.size.y - 40.0), SHELF_COLOR)
	draw_rect(
		Rect2(TRAY.position.x - SHELF, TRAY.end.y, TRAY.size.x + SHELF * 2.0, SHELF), SHELF_COLOR
	)
	_draw_label(
		font,
		Vector2(TRAY.position.x, TRAY.position.y - 16.0),
		TRAY.size.x,
		"WINNERS",
		26,
		WIN_COLOR
	)
	_draw_label(
		font, Vector2(PEN_LEFT, PEN_TOP + 40.0), ORIGIN.x - PEN_LEFT, "START", 26, Color.WHITE
	)
	var panel_x: float = right + LIFT_OUT * 2.0 + 10.0
	var panel_width: float = 1910.0 - panel_x
	_draw_label(font, Vector2(panel_x, 150.0), panel_width, "SNAKES", 44, BITE_COLOR)
	_draw_label(font, Vector2(panel_x, 196.0), panel_width, "& LADDERS", 44, CLIMB_COLOR)
	_draw_label(
		font, Vector2(panel_x, DICE_POSITION.y + 120.0), panel_width, "#roll", 40, Color.WHITE
	)
	_draw_label(
		font,
		Vector2(panel_x, DICE_POSITION.y + 160.0),
		panel_width,
		"to roll the dice",
		22,
		Color(1.0, 1.0, 1.0, 0.8)
	)
	_draw_label(
		font, Vector2(panel_x, 700.0), panel_width, "Land on a ladder: climb!", 22, CLIMB_COLOR
	)
	_draw_label(
		font, Vector2(panel_x, 736.0), panel_width, "Land on a snake: slide!", 22, BITE_COLOR
	)


func _draw_label(
	font: Font, at: Vector2, width: float, text: String, size: int, color: Color
) -> void:
	draw_string_outline(
		font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 8, Color(0.0, 0.0, 0.0, 0.7)
	)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


## A glass tube with bubbles rising in it, from `bottom` up to `top` (world ys of fish centers).
func _draw_lift(x: float, bottom: float, top: float) -> void:
	var half: float = Marble.RADIUS + 5.0
	var rect: Rect2 = Rect2(x - half, top - half, half * 2.0, bottom - top + half * 2.0)
	draw_rect(rect, Color(GLASS_COLOR, 0.12))
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), Color(GLASS_COLOR, 0.5), 2.0)
	draw_line(Vector2(rect.end.x, rect.position.y), rect.end, Color(GLASS_COLOR, 0.5), 2.0)


func _draw_links() -> void:
	for foot: int in LADDERS:
		_draw_ladder(foot, int(LADDERS[foot]))
	var index: int = 0
	for head: int in SNAKES:
		_draw_snake(head, int(SNAKES[head]), SNAKE_COLORS[index % SNAKE_COLORS.size()])
		index += 1


func _draw_ladder(foot: int, top: int) -> void:
	var from: Vector2 = square_center(foot) + Vector2(0.0, Marble.RADIUS)
	var to: Vector2 = square_center(top) + Vector2(0.0, Marble.RADIUS)
	var span: Vector2 = to - from
	var side: Vector2 = span.orthogonal().normalized() * 15.0
	var flash: float = float(_flashes.get(foot, 0.0))
	var wood: Color = LADDER_COLOR.lerp(CLIMB_COLOR, minf(flash, 1.0))
	if flash > 0.0:
		var glow: float = 70.0
		for i: int in 5:
			var at: Vector2 = from + span * (float(i) / 4.0)
			_links.draw_texture_rect(
				RaceFx.glow_texture(),
				Rect2(at - Vector2.ONE * glow * 0.5, Vector2.ONE * glow),
				false,
				Color(CLIMB_COLOR, 0.5 * minf(flash, 1.0))
			)
	var rungs: int = maxi(2, int(span.length() / 24.0))
	for i: int in range(1, rungs):
		var at: Vector2 = from + span * (float(i) / float(rungs))
		_links.draw_line(at - side, at + side, Color(0.0, 0.0, 0.0, 0.35), 7.0)
		_links.draw_line(at - side, at + side, wood, 4.0)
	for rail: Vector2 in [-side, side]:
		_links.draw_line(from + rail, to + rail, Color(0.0, 0.0, 0.0, 0.4), 8.0)
		_links.draw_line(from + rail, to + rail, wood, 5.0)
		_links.draw_line(from + rail, to + rail, LADDER_LIGHT, 1.5)


func _draw_snake(head: int, tail: int, color: Color) -> void:
	var points: PackedVector2Array = snake_points(head, tail)
	var flash: float = float(_flashes.get(head, 0.0))
	var awake: bool = snakes_awake() or not _armed
	var body: Color = color.lerp(Color.WHITE, 0.4 * minf(flash, 1.0))
	if not awake:
		body = body.darkened(0.35)
	var count: int = points.size()
	for i: int in range(count - 1):
		var u: float = float(i) / float(count - 1)
		var width: float = lerpf(20.0, 5.0, u)
		_links.draw_line(points[i], points[i + 1], Color(0.0, 0.0, 0.0, 0.45), width + 4.0, true)
	for i: int in range(count - 1):
		var u: float = float(i) / float(count - 1)
		var width: float = lerpf(20.0, 5.0, u)
		var stripe: Color = body if i % 4 < 2 else body.darkened(0.25)
		_links.draw_line(points[i], points[i + 1], stripe, width, true)
	# The head, looking back along the body's first stretch.
	var at: Vector2 = points[0]
	var facing: Vector2 = (points[0] - points[2]).normalized()
	var across: Vector2 = facing.orthogonal()
	_links.draw_circle(at, 15.0, Color(0.0, 0.0, 0.0, 0.45), true, -1.0, true)
	_links.draw_circle(at, 13.0, body, true, -1.0, true)
	for eye_side: float in [-1.0, 1.0]:
		var eye: Vector2 = at + facing * 4.0 + across * 6.0 * eye_side
		if awake:
			_links.draw_circle(eye, 3.6, Color.WHITE, true, -1.0, true)
			_links.draw_circle(eye + facing, 1.8, Color.BLACK, true, -1.0, true)
		else:
			_links.draw_line(eye - across * 3.0, eye + across * 3.0, Color.BLACK, 1.5, true)
	if awake:
		var flick: float = 0.5 + 0.5 * sin(_time * 7.0 + float(head))
		var tongue: Vector2 = at + facing * (14.0 + 6.0 * flick)
		var red: Color = Color(0.9, 0.1, 0.15)
		_links.draw_line(at + facing * 12.0, tongue, red, 2.0, true)
		_links.draw_line(tongue, tongue + (facing + across * 0.7) * 5.0, red, 2.0, true)
		_links.draw_line(tongue, tongue + (facing - across * 0.7) * 5.0, red, 2.0, true)
	else:
		var z: float = fposmod(_time * 0.6 + float(head) * 0.13, 1.0)
		_links.draw_string(
			ThemeDB.fallback_font,
			at + Vector2(10.0, -16.0 - z * 18.0),
			"z",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			18,
			Color(1.0, 1.0, 1.0, 1.0 - z)
		)
