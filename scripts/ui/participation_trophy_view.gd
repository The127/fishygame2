class_name ParticipationTrophyView
extends Control
## The last finisher with a participation trophy three times the winner's, and a slow clap.
## Each clap of the slow clap sound bumps the trophy and adds a "clap" to the caption.

const VIEW_SIZE: Vector2 = Vector2(340.0, 330.0)
const TROPHY_HEIGHT: float = Trophy.WINNER_HEIGHT * 3.0
const FISH_SCALE: float = 2.2
## Seconds after the trophy appears before the clapping starts (after the win jingle).
const CLAP_DELAY: float = 2.0
## Seconds into the slow clap sound of each clap; matches SLOW_CLAP_TIMES in
## tools/generate_audio.py.
const CLAP_TIMES: Array[float] = [0.0, 1.1, 2.1, 3.0, 3.8, 4.5]
const BUMP: float = 0.07
const BUMP_DECAY: float = 6.0
## Where the trophy stands and where the fish floats, inside the view.
const TROPHY_BOTTOM: Vector2 = Vector2(228.0, 240.0)
const FISH_POS: Vector2 = Vector2(78.0, 190.0)

var _elapsed: float = 0.0
var _claps: int = 0
var _bump: float = 0.0
var _caption: Label


func _ready() -> void:
	custom_minimum_size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## `entry` needs name, color, place and the fish look (species, pattern, accessory, skin).
func show_entry(entry: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var fish := FishVisual.new()
	fish.color = entry["color"]
	fish.species = int(entry.get("species", entry.get("id", 0)))
	fish.pattern = int(entry.get("pattern", 0))
	fish.accessory = int(entry.get("accessory", 0))
	fish.skin = int(entry.get("skin", 0))
	add_child(fish)
	# FishVisual detaches itself in _ready to follow a marble; here it stays with the view.
	fish.top_level = false
	fish.scale = Vector2.ONE * FISH_SCALE
	fish.position = FISH_POS
	var name_label := _make_label(str(entry["name"]), 30, 800, UiStyle.TEXT)
	name_label.position = Vector2(0.0, TROPHY_BOTTOM.y + 8.0)
	add_child(name_label)
	var place_text: String = "last place, %s" % _ordinal(int(entry["place"]))
	var place_label := _make_label(place_text, 22, 600, UiStyle.MUTED)
	place_label.position = Vector2(0.0, TROPHY_BOTTOM.y + 46.0)
	add_child(place_label)
	_caption = _make_label("", 24, 700, Trophy.GOLD_LIGHT)
	add_child(_caption)
	_elapsed = 0.0
	_claps = 0
	_bump = 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	_bump = maxf(0.0, _bump - BUMP_DECAY * delta)
	while _claps < CLAP_TIMES.size() and _elapsed >= CLAP_DELAY + CLAP_TIMES[_claps]:
		if _claps == 0:
			Sound.play(Sound.Sfx.SLOW_CLAP)
		_claps += 1
		_bump = 1.0
		_caption.text = "clap ".repeat(_claps).strip_edges()
	if _claps >= CLAP_TIMES.size() and _bump <= 0.0:
		set_process(false)
	queue_redraw()


## Stops the clapping (the podium ended early).
func stop() -> void:
	set_process(false)


func _draw() -> void:
	Trophy.draw(self, TROPHY_BOTTOM, TROPHY_HEIGHT * (1.0 + BUMP * _bump))


func _make_label(text: String, font_size: int, weight: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.size = Vector2(VIEW_SIZE.x, 36.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiStyle.style_label(label, font_size, weight, color)
	return label


static func _ordinal(n: int) -> String:
	var suffix: String = "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][n % 10]
	return "%d%s" % [n, suffix]
