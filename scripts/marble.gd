class_name Marble
extends RigidBody2D
## A fish marble. The visual is drawn by FishVisual, tinted by `color`.

const RADIUS: float = 14.0

## Seconds a curse keeps the marble slowed.
const CURSE_SECONDS: float = 3.0
const CURSE_DAMP: float = 3.0
const CURSE_TINT: Color = Color(0.6, 0.35, 0.85)
const BOOST_IMPULSE: float = 450.0
const CURSE_KNOCKBACK: float = 250.0
## Impulse per emote unit of a cheer, far below a boost.
const CHEER_IMPULSE: float = 40.0
## Largest cheer in emote units, so no setting makes a cheer as strong as a boost.
const CHEER_MAX_STRENGTH: float = 8.0

## Seconds the meow bubble stays up.
const MEOW_SECONDS: float = 1.2

var id: int = 0
var color: Color = Color.WHITE:
	set(value):
		color = value
		if _fish != null:
			_fish.color = value

## Index into [constant FishVisual.SPECIES]; a negative value means "by marble id".
var species: int = -1:
	set(value):
		species = value
		if _fish != null:
			_fish.species = value

## A [enum FishVisual.Pattern].
var pattern: int = 0:
	set(value):
		pattern = value
		if _fish != null:
			_fish.pattern = value

## Glow strength, 1 is normal.
var glow_boost: float = 1.0:
	set(value):
		glow_boost = value
		if _fish != null:
			_fish.glow_boost = value

var label_text: String = "":
	set(value):
		label_text = value
		if _label != null:
			_label.text = value

var _curse_left: float = 0.0
var _base_damp: float = 0.0
var _label: Label
var _fish: FishVisual
var _trail: CPUParticles2D


func _ready() -> void:
	_fish = FishVisual.new()
	_fish.color = color
	_fish.species = species if species >= 0 else id
	_fish.pattern = pattern
	_fish.glow_boost = glow_boost
	add_child(_fish)
	# Top level so the name stays upright and unscaled while the marble rolls.
	_label = Label.new()
	_label.top_level = true
	_label.text = label_text
	_label.z_index = 10
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_trail = RaceFx.make_trail()
	_trail.top_level = true
	add_child(_trail)


## Pushes the marble along `forward` (a unit vector toward the finish).
func boost(forward: Vector2) -> void:
	apply_central_impulse(forward * BOOST_IMPULSE * mass)
	if _fish != null:
		_fish.flash(RaceFx.BOOST_COLOR)
		RaceFx.burst(self, global_position, RaceFx.BOOST_COLOR, 16, 130.0, -forward * 60.0)


## A free cheer: a small push along `forward` scaled by `strength` (emote units) and a few bubbles.
func cheer(forward: Vector2, strength: float) -> void:
	strength = minf(strength, CHEER_MAX_STRENGTH)
	apply_central_impulse(forward * CHEER_IMPULSE * strength * mass)
	if _fish != null:
		RaceFx.burst(
			self,
			global_position,
			RaceFx.CHEER_COLOR,
			clampi(4 + roundi(strength * 2.0), 4, 16),
			70.0,
			Vector2(0, -70)
		)


## A little cat noise for show: a "meow" bubble that drifts up and a few pink hearts.
func meow() -> void:
	var bubble: Label = Label.new()
	bubble.top_level = true
	bubble.text = "meow~"
	bubble.z_index = 11
	bubble.add_theme_font_size_override("font_size", 15)
	bubble.add_theme_color_override("font_color", Color(0.25, 0.1, 0.2))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.92, 0.96, 0.92)
	style.set_corner_radius_all(9)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	bubble.add_theme_stylebox_override("normal", style)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)
	var size: Vector2 = bubble.get_minimum_size()
	var start: Vector2 = global_position + Vector2(-size.x * 0.5, -RADIUS - size.y - 26.0)
	bubble.global_position = start
	var tween: Tween = bubble.create_tween()
	tween.set_parallel(true)
	tween.tween_property(bubble, "global_position:y", start.y - 34.0, MEOW_SECONDS)
	tween.tween_property(bubble, "modulate:a", 0.0, MEOW_SECONDS * 0.4).set_delay(
		MEOW_SECONDS * 0.6
	)
	tween.chain().tween_callback(bubble.queue_free)
	RaceFx.burst(self, global_position, RaceFx.CHEER_COLOR, 8, 60.0, Vector2(0, -60))


## Knocks the marble back against `forward` and slows it for [constant CURSE_SECONDS].
func curse(forward: Vector2) -> void:
	if _curse_left <= 0.0:
		_base_damp = linear_damp
	_curse_left = CURSE_SECONDS
	linear_damp = CURSE_DAMP
	apply_central_impulse(-forward * CURSE_KNOCKBACK * mass)
	if _fish != null:
		_fish.color = color.lerp(CURSE_TINT, 0.6)
		_fish.aura = RaceFx.CURSE_COLOR
		_fish.flash(RaceFx.CURSE_COLOR)
		RaceFx.burst(self, global_position, RaceFx.CURSE_COLOR, 14, 70.0, Vector2(0, 30))


func is_cursed() -> bool:
	return _curse_left > 0.0


func _physics_process(delta: float) -> void:
	if _curse_left <= 0.0:
		return
	_curse_left -= delta
	if _curse_left <= 0.0:
		_curse_left = 0.0
		linear_damp = _base_damp
		if _fish != null:
			_fish.color = color
			_fish.aura = Color.TRANSPARENT


## A splash of bubbles where the fish crossed the finish.
func splash() -> void:
	RaceFx.burst(self, global_position, RaceFx.SPLASH_COLOR, 18, 110.0, Vector2(0, 60))


## Winner celebration: pulsing gold glow and a shower of sparkles.
func celebrate() -> void:
	if _fish != null:
		_fish.celebrating = true
	RaceFx.burst(self, global_position, RaceFx.WINNER_COLOR, 24, 150.0, Vector2(0, 30))


func _process(delta: float) -> void:
	_fish.face(linear_velocity, delta)
	_trail.global_position = global_position
	_trail.emitting = linear_velocity.length() > 60.0 and not freeze
	var size: Vector2 = _label.get_minimum_size()
	_label.global_position = global_position + Vector2(-size.x * 0.5, -RADIUS - size.y - 2.0)
