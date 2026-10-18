class_name TournamentBoard
extends CanvasLayer
## Tournament standings in the top-right corner, where the all-time board shows outside a
## tournament. Hidden until [method show_standings] gets a title.

const MARGIN: int = 48
## Most rows listed.
const ROWS: int = 5

var _panel: PanelContainer
var _title: Label
var _rows: VBoxContainer


func _init() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)
	_title = _make_label("", 26, 800, UiStyle.CYAN, 3)
	box.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	box.add_child(_rows)
	add_child(_panel)
	# Top-right, growing to the left and down with its content.
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_top = MARGIN
	_panel.offset_right = -MARGIN


## [param rows] are best first: {"name", "points"} plus an optional "bonus". An empty
## [param title] hides the board.
func show_standings(title: String, rows: Array[Dictionary]) -> void:
	_panel.visible = not title.is_empty()
	_title.text = title
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for i: int in mini(rows.size(), ROWS):
		var row: Dictionary = rows[i]
		var text: String = "%d. %s  %d" % [i + 1, row["name"], row["points"]]
		if int(row.get("bonus", 0)) > 0:
			text += "  +%d bonus" % int(row["bonus"])
		var top: bool = i < 3
		_rows.add_child(
			_make_label(text, 26, 700 if top else 600, UiStyle.TEXT if top else UiStyle.MUTED)
		)


func is_shown() -> bool:
	return _panel.visible


## Text of the title and each row, for tests.
func lines() -> PackedStringArray:
	var result: PackedStringArray = [_title.text]
	for child: Node in _rows.get_children():
		result.append((child as Label).text)
	return result


func _make_label(text: String, size: int, weight: int, color: Color, spacing: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.style_label(label, size, weight, color, spacing)
	return label
