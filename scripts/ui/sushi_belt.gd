class_name SushiBelt
extends Control
## The fish that did not finish ride past the podium on a sushi conveyor belt, each served on
## a plate of rice with a price tag. One pass: the last plate leaves before the podium ends.

const VIEW_SIZE: Vector2 = Vector2(1200.0, 132.0)
## Most fish served; the rest are only counted (see [method hidden_count]).
const MAX_PLATES: int = 6
## Distance between plate centers along the belt.
const SPACING: float = 200.0
const PLATE_RADIUS: Vector2 = Vector2(56.0, 13.0)
const PLATE_Y: float = 74.0
const FISH_Y: float = 52.0
const FISH_SCALE: float = 1.5
const BELT_TOP: float = 70.0
const BELT_BOTTOM: float = 96.0
const SLAT_GAP: float = 26.0
const TAG_SIZE: Vector2 = Vector2(176.0, 34.0)
const TAG_Y: float = 98.0
## Share of the podium the pass takes, so the belt is empty again as the podium goes.
const PASS_SHARE: float = 0.92
const PLATE_RIMS: Array[Color] = [
	Color(0.9, 0.25, 0.25), Color(0.25, 0.5, 0.95), Color(0.95, 0.75, 0.2), Color(0.2, 0.75, 0.45)
]
## Menu name and price in yen for each Marble.fate.
const MENU: Dictionary = {
	"dissolved": ["acid-cured", 90],
	"snapped": ["dust roll", 40],
	"stranded": ["sun-dried", 180],
	"cut": ["ghost roll", 120],
	"eaten": ["pre-chewed", 30],
	"": ["fresh catch", 300],
}
const TAG_PAPER: Color = Color(0.98, 0.95, 0.86)
const TAG_INK: Color = Color(0.12, 0.08, 0.06)

var _plates: Array[Dictionary] = []
var _fish: Array[FishVisual] = []
var _hidden: int = 0
var _speed: float = 0.0
var _travel: float = 0.0


func _ready() -> void:
	custom_minimum_size = VIEW_SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Serves `fish` (name, color, species, pattern, accessory, skin and fate) over `seconds`.
## Only the first [constant MAX_PLATES] get a plate.
func serve(fish: Array[Dictionary], seconds: float) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_plates = fish.slice(0, MAX_PLATES)
	_hidden = fish.size() - _plates.size()
	_fish.clear()
	for entry: Dictionary in _plates:
		var visual := FishVisual.new()
		visual.color = entry.get("color", Color.WHITE)
		visual.species = int(entry.get("species", 0))
		visual.pattern = int(entry.get("pattern", 0))
		visual.accessory = int(entry.get("accessory", 0))
		visual.skin = int(entry.get("skin", 0))
		add_child(visual)
		# FishVisual detaches itself in _ready to follow a marble; here it rides the belt.
		visual.top_level = false
		visual.scale = Vector2.ONE * FISH_SCALE
		_fish.append(visual)
	# The first plate starts with its tag just on the belt; the last tag is off the far end
	# after the pass.
	var distance: float = VIEW_SIZE.x + SPACING * maxf(_plates.size() - 1, 0)
	_speed = distance / maxf(seconds * PASS_SHARE, 0.1)
	_travel = 0.0
	_place_fish()
	queue_redraw()


func plate_count() -> int:
	return _plates.size()


## Fish left off the belt by the [constant MAX_PLATES] cap.
func hidden_count() -> int:
	return _hidden


## Center x of plate `index` on the belt right now; it starts left of the belt and moves right.
func plate_x(index: int) -> float:
	return TAG_SIZE.x * 0.5 - index * SPACING + _travel


## "¥120 · sun-dried": the price tag of a fish that met `fate` (see Marble.fate). The price
## wobbles a little by name so a belt of the same fate is not all one price.
static func price_tag(fate: String, fish_name: String) -> String:
	var item: Array = MENU.get(fate, MENU[""])
	var price: int = int(item[1]) + (fish_name.hash() & 0x7fffffff) % 5 * 10
	return "¥%d · %s" % [price, item[0]]


func _process(delta: float) -> void:
	if _plates.is_empty():
		return
	_travel += _speed * delta
	_place_fish()
	queue_redraw()


func _place_fish() -> void:
	for i: int in _fish.size():
		_fish[i].position = Vector2(plate_x(i), FISH_Y)
		_fish[i].visible = _on_belt(i)


func _on_belt(index: int) -> bool:
	var x: float = plate_x(index)
	return x > -TAG_SIZE.x * 0.5 and x < VIEW_SIZE.x + TAG_SIZE.x * 0.5


func _draw() -> void:
	_draw_belt()
	var font: Font = UiStyle.font(800)
	for i: int in _plates.size():
		if _on_belt(i):
			_draw_plate(i, font)


func _draw_belt() -> void:
	var top := Rect2(0.0, BELT_TOP, VIEW_SIZE.x, BELT_BOTTOM - BELT_TOP)
	draw_rect(top, Color(0.32, 0.36, 0.4))
	var slat: float = fmod(_travel, SLAT_GAP)
	while slat < VIEW_SIZE.x:
		draw_line(Vector2(slat, BELT_TOP), Vector2(slat, BELT_BOTTOM), Color(0.18, 0.2, 0.23), 3.0)
		slat += SLAT_GAP
	draw_rect(Rect2(0.0, BELT_TOP, VIEW_SIZE.x, 3.0), Color(0.72, 0.78, 0.82))
	draw_rect(Rect2(0.0, BELT_BOTTOM, VIEW_SIZE.x, 6.0), Color(0.1, 0.11, 0.13))


func _draw_plate(index: int, font: Font) -> void:
	var x: float = plate_x(index)
	var rim: Color = PLATE_RIMS[index % PLATE_RIMS.size()]
	_draw_ellipse(Vector2(x, PLATE_Y + 3.0), PLATE_RADIUS, Color(0.0, 0.0, 0.0, 0.35))
	_draw_ellipse(Vector2(x, PLATE_Y), PLATE_RADIUS, rim)
	_draw_ellipse(Vector2(x, PLATE_Y - 2.0), PLATE_RADIUS * 0.78, Color(0.97, 0.97, 0.95))
	# The rice the fish lies on.
	_draw_ellipse(Vector2(x, PLATE_Y - 9.0), Vector2(34.0, 10.0), Color(0.99, 0.99, 0.97))
	var entry: Dictionary = _plates[index]
	var tag := Rect2(Vector2(x - TAG_SIZE.x * 0.5, TAG_Y), TAG_SIZE)
	draw_line(Vector2(x, PLATE_Y + 8.0), Vector2(x, TAG_Y), Color(0.85, 0.85, 0.8), 2.0)
	draw_rect(tag, TAG_PAPER)
	draw_rect(Rect2(tag.position, Vector2(6.0, tag.size.y)), rim)
	var text_left: float = tag.position.x + 12.0
	var text_width: float = tag.size.x - 18.0
	var fish_name: String = _fit(str(entry.get("name", "")), font, 15, text_width)
	draw_string(
		font,
		Vector2(text_left, tag.position.y + 15.0),
		fish_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		text_width,
		15,
		TAG_INK
	)
	draw_string(
		font,
		Vector2(text_left, tag.position.y + 30.0),
		price_tag(str(entry.get("fate", "")), str(entry.get("name", ""))),
		HORIZONTAL_ALIGNMENT_LEFT,
		text_width,
		13,
		Color(0.7, 0.12, 0.1)
	)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radius.y / radius.x))
	draw_circle(Vector2.ZERO, radius.x, color)
	draw_set_transform(Vector2.ZERO)


## `text` cut down with an ellipsis until it fits `width`.
func _fit(text: String, font: Font, font_size: int, width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return text
	var cut: String = text
	while cut.length() > 1:
		cut = cut.left(-1)
		var candidate: String = cut + "…"
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
			return candidate
	return cut
