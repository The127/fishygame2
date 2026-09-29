class_name LeaderboardPanel
extends HBoxContainer
## Two columns, most points and most race wins. Used on the home screen and in the lobby.

const ROWS: int = 5

var _points_column: VBoxContainer
var _wins_column: VBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 64)
	_points_column = _make_column("MOST POINTS")
	_wins_column = _make_column("MOST WINS")


## Shows [param points_rows] and [param wins_rows] (from PointsStore.top_by_points and
## top_by_wins). Returns false when both are empty so callers can hide the panel.
func set_rows(points_rows: Array[Dictionary], wins_rows: Array[Dictionary]) -> bool:
	_fill(_points_column, points_rows, "points")
	_fill(_wins_column, wins_rows, "wins")
	return not points_rows.is_empty() or not wins_rows.is_empty()


func _make_column(title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	column.custom_minimum_size = Vector2(300, 0)
	column.add_child(_make_label(title, 26, 800, UiStyle.CYAN, 3))
	add_child(column)
	return column


func _fill(column: VBoxContainer, rows: Array[Dictionary], key: String) -> void:
	# Child 0 is the title.
	for child: Node in column.get_children().slice(1):
		column.remove_child(child)
		child.queue_free()
	for i: int in mini(rows.size(), ROWS):
		var color: Color = UiStyle.TEXT if i < 3 else UiStyle.MUTED
		var label: Label = _make_label(
			"%d.  %s   %d" % [i + 1, rows[i]["name"], rows[i][key]], 24, 700, color
		)
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		column.add_child(label)


func _make_label(text: String, size: int, weight: int, color: Color, spacing: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.style_label(label, size, weight, color, spacing)
	return label
