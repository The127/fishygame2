class_name SponsorBreak
extends CanvasLayer
## The "Sponsor break" setting: once per race, when the leader is around the middle of the
## course, a fake ad slides over the left or right half of the play area for a couple of
## seconds and slides away again. It never waits for the finish: a race whose leader is
## already past [constant LATEST] gets no ad, and a running ad leaves the moment a fish
## finishes. Sits above the overlay and below the RTX filter, which then shines on it too.

const LAYER: int = 4
## The ad shows once the leader is this far along, a random point between the two.
const TRIGGER_MIN: float = 0.35
const TRIGGER_MAX: float = 0.5
## Past this the ad is skipped for the race, or cut short if it is still up.
const LATEST: float = 0.75
## Seconds fully on screen, and seconds to slide in or out.
const HOLD_SECONDS: float = 2.0
const SLIDE_SECONDS: float = 0.2
const HEADER: String = "This race is brought to you by"

## brand, tagline, and the ad's background color.
const ADS: Array[Dictionary] = [
	{"brand": "KELP", "tagline": "Kelp: it's there.", "color": Color(0.16, 0.42, 0.14)},
	{"brand": "SAND", "tagline": "Sand. Now in grains.", "color": Color(0.62, 0.45, 0.2)},
	{"brand": "WATER", "tagline": "Water: you're already in it.", "color": Color(0.05, 0.36, 0.7)},
	{"brand": "A ROCK", "tagline": "Sit on it. Or don't.", "color": Color(0.38, 0.38, 0.42)},
	{"brand": "PLANKTON", "tagline": "Plankton. Small. Numerous.", "color": Color(0.2, 0.55, 0.45)},
	{"brand": "BUBBLES", "tagline": "Bubbles: they go up.", "color": Color(0.32, 0.62, 0.86)},
	{"brand": "THE TIDE", "tagline": "The Tide. It comes back.", "color": Color(0.1, 0.25, 0.5)},
	{"brand": "SALT", "tagline": "Salt. It's in everything.", "color": Color(0.4, 0.45, 0.52)},
	{"brand": "CORAL", "tagline": "Coral: a rock that's trying.", "color": Color(0.86, 0.38, 0.4)},
	{
		"brand": "THE DEEP",
		"tagline": "The Deep: it's down there.",
		"color": Color(0.03, 0.05, 0.14)
	},
	{"brand": "BARNACLES", "tagline": "Stick with what you know.", "color": Color(0.45, 0.4, 0.33)},
	{"brand": "FOAM", "tagline": "Foam: water, but nervous.", "color": Color(0.28, 0.5, 0.6)},
	{
		"brand": "SEAWEED",
		"tagline": "Not related to KELP. Legally.",
		"color": Color(0.3, 0.45, 0.12)
	},
	{
		"brand": "A SHELL",
		"tagline": "Something used to live here.",
		"color": Color(0.72, 0.45, 0.36)
	},
	{"brand": "WET", "tagline": "Wet. It's a whole thing.", "color": Color(0.12, 0.48, 0.62)},
	{"brand": "GRAVITY", "tagline": "Gravity: keeping you down.", "color": Color(0.28, 0.16, 0.42)},
]

## One line of fine print under each ad, drawn at random.
const FINE_PRINT: Array[String] = [
	"Not available in rivers.",
	"Results not typical. Results not anything.",
	"Ask your doctor fish if this is right for you.",
	"Contains water. May contain more water.",
	"No fish were paid for this message.",
	"Offer ends never.",
	"Side effects may include being a fish.",
	"Terms and conditions are also there.",
]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Ad indexes still to show before any repeats, drawn from the back.
var _bag: Array[int] = []
## Leader fraction at which this race's ad shows, or -1 while no ad is due.
var _trigger_at: float = -1.0
## Seconds since the ad started sliding in, or -1 while none is up.
var _age: float = -1.0
var _on_left: bool = true
var _frame: Control
var _half: Control
var _panel: PanelContainer
var _box: StyleBoxFlat
var _brand: Label
var _tagline: Label
var _fine_print: Label
var _resume: Label


func _init() -> void:
	layer = LAYER
	visible = false
	_rng.randomize()
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_half = Control.new()
	_half.name = "Half"
	_half.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_half.clip_contents = true
	_frame.add_child(_half)
	_panel = PanelContainer.new()
	_panel.name = "Ad"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = StyleBoxFlat.new()
	_box.set_border_width_all(10)
	_box.border_color = Color(1.0, 0.86, 0.2)
	_box.content_margin_left = 64.0
	_box.content_margin_right = 64.0
	_box.content_margin_top = 48.0
	_box.content_margin_bottom = 48.0
	_panel.add_theme_stylebox_override("panel", _box)
	_half.add_child(_panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	var tag: Label = _label("SPONSORED", 28, 800, Color(1.0, 0.86, 0.2))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(tag)
	column.add_child(_spacer())
	column.add_child(_label(HEADER, 40, 500, Color(1.0, 1.0, 1.0, 0.85)))
	_brand = _label("", 150, 900, Color.WHITE)
	_brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	_brand.label_settings.outline_size = 18
	_brand.label_settings.outline_color = Color(0.0, 0.0, 0.0, 0.45)
	_brand.label_settings.shadow_size = 0
	_brand.label_settings.shadow_offset = Vector2(8.0, 8.0)
	_brand.label_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	column.add_child(_brand)
	_tagline = _label("", 56, 700, Color.WHITE)
	column.add_child(_tagline)
	column.add_child(_spacer())
	_fine_print = _label("", 22, 500, Color(1.0, 1.0, 1.0, 0.75))
	_fine_print.label_settings.shadow_color = Color.TRANSPARENT
	column.add_child(_fine_print)
	_resume = _label("", 26, 700, Color.WHITE)
	_resume.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_resume)


## Keeps the ad inside the area not blocked by the streamer's own overlays.
func set_play_fraction(fraction: Rect2) -> void:
	_frame.anchor_left = fraction.position.x
	_frame.anchor_top = fraction.position.y
	_frame.anchor_right = fraction.end.x
	_frame.anchor_bottom = fraction.end.y
	_frame.offset_left = 0.0
	_frame.offset_top = 0.0
	_frame.offset_right = 0.0
	_frame.offset_bottom = 0.0


## Seeds the draws, so tests can pick the side and the ad.
func set_seed(value: int) -> void:
	_rng.seed = value
	_bag.clear()


## A new race started: picks where along the course its ad shows, or with [param on] false
## (the setting is off, or the fake sequel round, which is its own show) shows none.
func arm(on: bool = true) -> void:
	_trigger_at = _rng.randf_range(TRIGGER_MIN, TRIGGER_MAX) if on else -1.0


## Takes the ad down at once and forgets any ad still due this race.
func stop() -> void:
	_trigger_at = -1.0
	_age = -1.0
	visible = false


## Takes a running ad down, so it never hides a finish. Fits [signal Race.marble_finished].
func cut_short(_id: int = -1, _place: int = 0) -> void:
	stop()


func is_showing() -> bool:
	return _age >= 0.0


func is_due() -> bool:
	return _trigger_at >= 0.0


## Which half the ad covers.
func is_on_left() -> bool:
	return _on_left


## The brand on the ad now up (or last shown).
func get_brand() -> String:
	return _brand.text


## Called every frame with how far along the leader is (0 to 1), or a negative number while
## no race is running, which takes the ad down.
func update(delta: float, leader: float) -> void:
	if leader > LATEST or leader < 0.0:
		stop()
		return
	if is_showing():
		_age += delta
		if _age >= HOLD_SECONDS + 2.0 * SLIDE_SECONDS:
			stop()
			return
		_place()
	elif is_due() and leader >= _trigger_at:
		_trigger_at = -1.0
		_show()


func _show() -> void:
	if _bag.is_empty():
		for i: int in ADS.size():
			_bag.append(i)
		for i: int in range(_bag.size() - 1, 0, -1):
			var j: int = _rng.randi_range(0, i)
			var swap: int = _bag[i]
			_bag[i] = _bag[j]
			_bag[j] = swap
	var ad: Dictionary = ADS[_bag.pop_back()]
	_brand.text = ad["brand"]
	# Long names get a smaller size so they fit on one line.
	_brand.label_settings.font_size = clampi(int(900.0 / float(_brand.text.length())), 80, 160)
	_tagline.text = ad["tagline"]
	_box.bg_color = ad["color"]
	_fine_print.text = FINE_PRINT[_rng.randi_range(0, FINE_PRINT.size() - 1)]
	_on_left = _rng.randf() < 0.5
	_half.anchor_left = 0.0 if _on_left else 0.5
	_half.anchor_right = 0.5 if _on_left else 1.0
	_half.anchor_top = 0.0
	_half.anchor_bottom = 1.0
	_age = 0.0
	visible = true
	_place()


## Slides the ad in from its own edge of the screen and back out.
func _place() -> void:
	var total: float = HOLD_SECONDS + 2.0 * SLIDE_SECONDS
	var shown: float = clampf(minf(_age, total - _age) / SLIDE_SECONDS, 0.0, 1.0)
	var width: float = _frame.size.x * 0.5
	var shift: float = (1.0 - ease(shown, 0.4)) * width * (-1.0 if _on_left else 1.0)
	_half.offset_left = shift
	_half.offset_right = shift
	var left: int = ceili(maxf(HOLD_SECONDS + SLIDE_SECONDS - _age, 0.0))
	_resume.text = "Your race resumes in %d" % maxi(left, 1)


func _label(text: String, size: int, weight: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := LabelSettings.new()
	look.font = UiStyle.font(weight)
	look.font_size = size
	look.font_color = color
	look.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	look.shadow_offset = Vector2(3.0, 3.0)
	look.shadow_size = 0
	label.label_settings = look
	return label


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
