class_name Treasure
extends Node2D
## A glowing treasure lying on the map. The first fish to touch it takes it and its viewer earns
## the value. It has no physics body: [Race] checks the distance and calls [method collect].
## Which treasures a race gets, and where, are a pure function of a seed (see [method plan]).

enum Kind { COIN, PEARL, CHEST }

## Fewest and most treasures a race gets.
const MIN_COUNT: int = 2
const MAX_COUNT: int = 4
## The race is split into this stretch of the track, as fractions of the centerline length.
const FIRST_PROGRESS: float = 0.12
const LAST_PROGRESS: float = 0.9
## How far from its centre a fish must be to pick the treasure up, including the fish's own size.
const REACH: float = 34.0
const VALUES: Dictionary = {Kind.COIN: 15, Kind.PEARL: 25, Kind.CHEST: 50}
const NAMES: Dictionary = {Kind.COIN: "coin", Kind.PEARL: "pearl", Kind.CHEST: "chest"}
const COLORS: Dictionary = {
	Kind.COIN: Color(1.0, 0.82, 0.3),
	Kind.PEARL: Color(0.85, 0.95, 1.0),
	Kind.CHEST: Color(1.0, 0.65, 0.25),
}
## Seconds the "+points" text floats up.
const FLOAT_SECONDS: float = 1.2

var kind: Kind = Kind.COIN
var collected: bool = false

var _time: float = 0.0


## The treasures for a race as [{kind, progress}], sorted by progress. Each one sits in its own
## slice of the track, so they spread out. Uses only its own generator, seeded from `seed_value`.
static func plan(seed_value: int) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = rng.randi_range(MIN_COUNT, MAX_COUNT)
	var slice: float = (LAST_PROGRESS - FIRST_PROGRESS) / float(count)
	var result: Array[Dictionary] = []
	for i: int in count:
		var roll: int = rng.randi_range(0, 99)
		var chosen: Kind = Kind.COIN if roll < 50 else (Kind.PEARL if roll < 85 else Kind.CHEST)
		var progress: float = FIRST_PROGRESS + slice * (float(i) + rng.randf_range(0.15, 0.85))
		result.append({"kind": chosen, "progress": progress})
	return result


static func value_of(treasure_kind: Kind) -> int:
	return int(VALUES[treasure_kind])


static func name_of(treasure_kind: Kind) -> String:
	return str(NAMES[treasure_kind])


func _ready() -> void:
	z_index = 3


func value() -> int:
	return value_of(kind)


## Takes the treasure: a sparkle, the amount floating up, and it is gone.
func collect() -> void:
	if collected:
		return
	collected = true
	var color: Color = COLORS[kind]
	RaceFx.burst(get_parent(), global_position, color, 22, 130.0, Vector2(0, -30))
	var label: Label = Label.new()
	label.top_level = true
	label.text = "+%d" % value()
	label.z_index = 12
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(label)
	var size: Vector2 = label.get_minimum_size()
	var start: Vector2 = global_position + Vector2(-size.x * 0.5, -REACH - size.y)
	label.global_position = start
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", start.y - 46.0, FLOAT_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_SECONDS * 0.4).set_delay(
		FLOAT_SECONDS * 0.6
	)
	tween.chain().tween_callback(label.queue_free)
	hide()
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var color: Color = COLORS[kind]
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
	var bob: Vector2 = Vector2(0.0, sin(_time * 2.0) * 2.5)
	# Soft glow behind, brighter and larger on a pulse.
	var glow_size: float = 44.0 + 8.0 * pulse
	draw_texture_rect(
		RaceFx.glow_texture(),
		Rect2(-Vector2.ONE * glow_size + bob, Vector2.ONE * glow_size * 2.0),
		false,
		Color(color, 0.35 + 0.2 * pulse)
	)
	match kind:
		Kind.COIN:
			draw_circle(bob, 13.0, color.darkened(0.35))
			draw_circle(bob, 10.5, color)
			draw_arc(bob, 6.0, 0.0, TAU, 20, color.darkened(0.3), 2.0)
		Kind.PEARL:
			draw_circle(bob, 12.0, color.darkened(0.25))
			draw_circle(bob, 10.0, color)
			draw_circle(bob + Vector2(-3.5, -3.5), 3.5, Color(1, 1, 1, 0.9))
		Kind.CHEST:
			var body: Rect2 = Rect2(Vector2(-16.0, -6.0) + bob, Vector2(32.0, 19.0))
			var lid: Rect2 = Rect2(Vector2(-16.0, -14.0) + bob, Vector2(32.0, 10.0))
			draw_rect(body, color.darkened(0.45))
			draw_rect(lid, color.darkened(0.25))
			draw_rect(Rect2(Vector2(-16.0, -6.0) + bob, Vector2(32.0, 3.0)), color)
			draw_rect(Rect2(Vector2(-3.0, -8.0) + bob, Vector2(6.0, 9.0)), color.lightened(0.3))
			draw_rect(body, color, false, 1.5)
			draw_rect(lid, color, false, 1.5)
