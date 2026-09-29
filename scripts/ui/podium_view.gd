class_name PodiumView
extends Control
## Three podium steps (2nd, 1st, 3rd) with each winner's fish, name and time on top.
## Drawn from code so it matches the rest of the overlay; a fixed size keeps layout simple.

const VIEW_SIZE: Vector2 = Vector2(900.0, 420.0)
const STEP_WIDTH: float = 260.0
const STEP_GAP: float = 12.0
const BASELINE: float = 410.0
const FISH_SCALE: float = 3.0
## Fish center and name sit this far above the step top; tall species reach about 65 up.
const FISH_LIFT: float = 62.0
const NAME_WIDTH: float = 380.0
## Left to right: 2nd, 1st, 3rd.
const SLOT_PLACES: Array[int] = [2, 1, 3]
const STEP_HEIGHTS: Dictionary = {1: 210.0, 2: 160.0, 3: 120.0}
const PLACE_COLORS: Dictionary = {
	1: Color(1.0, 0.82, 0.25), 2: Color(0.78, 0.86, 0.92), 3: Color(0.85, 0.55, 0.32)
}

var _entries: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `podium` entries need place, id, name, color, time and finished; only places 1 to 3 are shown.
func set_podium(podium: Array[Dictionary]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_entries.clear()
	for entry: Dictionary in podium:
		var place: int = int(entry["place"])
		if STEP_HEIGHTS.has(place):
			_entries[place] = entry
			_add_winner(entry, place)
	queue_redraw()


func step_rect(place: int) -> Rect2:
	var slot: int = SLOT_PLACES.find(place)
	var total: float = STEP_WIDTH * 3.0 + STEP_GAP * 2.0
	var left: float = (VIEW_SIZE.x - total) * 0.5 + slot * (STEP_WIDTH + STEP_GAP)
	var height: float = STEP_HEIGHTS[place]
	return Rect2(left, BASELINE - height, STEP_WIDTH, height)


func _add_winner(entry: Dictionary, place: int) -> void:
	var rect: Rect2 = step_rect(place)
	var fish := FishVisual.new()
	fish.color = entry["color"]
	fish.species = int(entry["id"])
	fish.celebrating = place == 1
	add_child(fish)
	# FishVisual detaches itself in _ready to follow a marble; here it stays with the view.
	fish.top_level = false
	fish.scale = Vector2.ONE * FISH_SCALE
	fish.position = Vector2(rect.get_center().x, rect.position.y - FISH_LIFT)
	var name_label: Label = _make_label(str(entry["name"]), 32, 800, UiStyle.TEXT)
	name_label.position = Vector2(rect.get_center().x - NAME_WIDTH * 0.5, rect.position.y - 180.0)
	name_label.size = Vector2(NAME_WIDTH, 40.0)
	add_child(name_label)
	var time_text: String = "%.1fs" % entry["time"] if entry["finished"] else "did not finish"
	var time_label: Label = _make_label(time_text, 22, 600, UiStyle.MUTED)
	time_label.position = Vector2(rect.position.x, rect.position.y + 78.0)
	time_label.size = Vector2(rect.size.x, 30.0)
	add_child(time_label)


func _make_label(text: String, font_size: int, weight: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiStyle.style_label(label, font_size, weight, color)
	return label


func _draw() -> void:
	var font: Font = UiStyle.font(900)
	for place: int in SLOT_PLACES:
		var rect: Rect2 = step_rect(place)
		var tint: Color = PLACE_COLORS[place]
		var occupied: bool = _entries.has(place)
		var alpha: float = 1.0 if occupied else 0.4
		draw_rect(rect, Color(0.012, 0.047, 0.102, 0.92))
		draw_rect(rect, Color(tint, 0.9 * alpha), false, 3.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6.0)), Color(tint, alpha))
		var text: String = str(place)
		var font_size: int = 64
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos := Vector2(rect.get_center().x - width * 0.5, rect.position.y + 66.0)
		draw_string_outline(
			font,
			pos,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			8,
			Color(0.0, 0.03, 0.08, 0.95)
		)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(tint, alpha))
