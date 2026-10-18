class_name ReverseHazard
extends Hazard
## A reverse card on Board Game: two rows of the board flash, then for a moment their current runs
## backwards and carries the fish the wrong way. It pushes the fish itself, against the board's
## own current, so the fish drift back slowly and never jam: when the card is over the current
## takes them on again. Fish the board is moving (a hop, a ladder, a lift) are left alone.

## Push against the way a row runs, in pixels per second squared. Against the board's current
## this leaves the fish drifting back at about 90 pixels per second.
const PUSH: float = 1800.0
const ROWS_PER_EVENT: int = 2
const TINT: Color = Color(0.95, 0.25, 0.3)
const ARROWS_PER_ROW: int = 5

## Rows (0 is the bottom one) the card reverses, -1 for none.
var _rows: Array[int] = [-1, -1]


func _ready() -> void:
	z_index = -2


func reversed_rows() -> Array[int]:
	var rows: Array[int] = []
	for row: int in _rows:
		if row >= 0:
			rows.append(row)
	return rows


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	var first: int = rng.randi_range(0, SnakeBoard.ROWS - 1)
	var second: int = (first + rng.randi_range(1, SnakeBoard.ROWS - 1)) % SnakeBoard.ROWS
	_rows = [first, second]


func _process_active(_delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(Marble.GROUP):
		var marble: Marble = node as Marble
		if marble.eaten or marble.freeze or marble.has_finished or marble.replaying:
			continue
		var square: int = SnakeBoard.square_at(marble.global_position)
		if square < 1:
			continue
		var row: int = (square - 1) / SnakeBoard.COLS
		if _rows.has(row):
			var back: float = -float(SnakeBoard.row_dir(row))
			marble.apply_central_force(Vector2(back * PUSH * marble.mass, 0.0))


func _end_event() -> void:
	_rows = [-1, -1]


func _reset() -> void:
	_rows = [-1, -1]


func _replay_extra() -> PackedFloat32Array:
	return PackedFloat32Array([float(_rows[0]), float(_rows[1])])


func _apply_replay_extra(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_rows = [
		int(Replayable.step(from, to, weight, REPLAY_BASE)),
		int(Replayable.step(from, to, weight, REPLAY_BASE + 1))
	]


func _draw() -> void:
	if phase == Phase.IDLE:
		return
	var font: Font = ThemeDB.fallback_font
	var blink: float = 0.5 + 0.5 * sin(clock * 18.0)
	var strength: float = blink if phase == Phase.TELEGRAPH else 1.0
	for row: int in _rows:
		if row < 0:
			continue
		var top: float = SnakeBoard.ORIGIN.y - float(row + 1) * SnakeBoard.CELL.y
		var left: float = SnakeBoard.ORIGIN.x
		var width: float = SnakeBoard.CELL.x * SnakeBoard.COLS
		draw_rect(
			Rect2(left, top, width, SnakeBoard.CELL.y - SnakeBoard.SHELF),
			Color(TINT, 0.28 * strength)
		)
		var back: float = -float(SnakeBoard.row_dir(row))
		var y: float = top + SnakeBoard.CELL.y * 0.45
		# Chevrons pointing the wrong way, drifting that way while the card is in play.
		var drift: float = fposmod(clock * 0.25, 1.0) if phase == Phase.ACTIVE else 0.0
		for i: int in ARROWS_PER_ROW:
			var along: float = fposmod((float(i) + 0.5) / float(ARROWS_PER_ROW) + drift * back, 1.0)
			var x: float = left + along * width
			var tip: Vector2 = Vector2(x + back * 18.0, y)
			var color: Color = Color(1.0, 0.92, 0.92, 0.85 * strength)
			draw_line(Vector2(x - back * 10.0, y - 18.0), tip, color, 6.0, true)
			draw_line(Vector2(x - back * 10.0, y + 18.0), tip, color, 6.0, true)
		draw_string_outline(
			font,
			Vector2(left, top + 22.0),
			"REVERSE!",
			HORIZONTAL_ALIGNMENT_CENTER,
			width,
			24,
			6,
			Color(0.0, 0.0, 0.0, 0.6 * strength)
		)
		draw_string(
			font,
			Vector2(left, top + 22.0),
			"REVERSE!",
			HORIZONTAL_ALIGNMENT_CENTER,
			width,
			24,
			Color(1.0, 1.0, 1.0, strength)
		)
