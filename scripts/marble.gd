class_name Marble
extends RigidBody2D
## A fish marble. The visual is drawn by FishVisual, tinted by `color`.

## Group every fish is in, for map parts that act on all of them.
const GROUP: StringName = &"marbles"
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

## Seconds a snapped fish takes to fade away, and the color of its dust.
const SNAP_FADE_SECONDS: float = 1.0
const SNAP_DUST: Color = Color(0.9, 0.75, 0.35)

## Seconds a fish can lie above the waterline before it is stranded (see [method update_dryness]).
const DRY_GRACE: float = 2.0
## Dry time at which a fish starts to gasp (flashes), in seconds.
const DRY_WARNING: float = 0.6
## Seconds a stranded fish flops, then seconds it takes to fade away.
const FLOP_SECONDS: float = 1.3
const STRAND_FADE_SECONDS: float = 0.9
const FLOP_TINT: Color = Color(0.85, 0.75, 0.5)

## Seconds a fish takes to dissolve in acid, and the color of the fizz.
const DISSOLVE_SECONDS: float = 0.6
const ACID_COLOR: Color = Color(0.75, 1.0, 0.3)

## Seconds the meow bubble stays up.
const MEOW_SECONDS: float = 1.2

var id: int = 0
## Set by the race once the fish has crossed the finish.
var has_finished: bool = false
## True while an anglerfish holds the fish: hidden, frozen and out of the physics.
var eaten: bool = false
## True once a Thanos snap turned the fish to dust. It stays out of the race for good.
var snapped: bool = false
## True once the tide left the fish high and dry. It stays out of the race for good.
var stranded: bool = false
## True once stomach acid dissolved the fish. It stays out of the race for good.
var dissolved: bool = false
## Seconds the fish has lain above the waterline without getting wet again.
var dry_time: float = 0.0
## How often anglerfish have swallowed this fish in the current race.
var times_eaten: int = 0
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

## A [enum FishSkin.Kind], a premium animated look; 0 wears `color`.
var skin: int = 0:
	set(value):
		skin = value
		if _fish != null:
			_fish.skin = value

## A [enum FishAccessory.Kind].
var accessory: int = 0:
	set(value):
		accessory = value
		if _fish != null:
			_fish.accessory = value

## A [enum FishTrail.Kind]; 0 is the plain bubble trail.
var trail: int = 0:
	set(value):
		if value == trail:
			return
		trail = value
		if _trail != null:
			_build_trail()

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

## While a finish replay drives this marble, its heading comes from [member replay_velocity].
var replaying: bool = false:
	set(value):
		if value == replaying:
			return
		replaying = value
		if _fish == null:
			return
		# The winner's glow is replayed at the crossing, not shown from the first frame.
		if value:
			_was_celebrating = _fish.celebrating
			_fish.celebrating = false
		else:
			_fish.celebrating = _fish.celebrating or _was_celebrating
var replay_velocity: Vector2 = Vector2.ZERO

var _strand_tween: Tween
var _curse_left: float = 0.0
var _layer_before_eaten: int = 0
var _mask_before_eaten: int = 0
var _was_celebrating: bool = false
var _base_damp: float = 0.0
var _label: Label
var _fish: FishVisual
var _trail: CPUParticles2D


func _ready() -> void:
	add_to_group(GROUP)
	_fish = FishVisual.new()
	_fish.color = color
	_fish.species = species if species >= 0 else id
	_fish.pattern = pattern
	_fish.accessory = accessory
	_fish.skin = skin
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
	_build_trail()


## Swaps in the emitter for the current [member trail].
func _build_trail() -> void:
	if _trail != null:
		_trail.queue_free()
	_trail = FishTrail.make(trail)
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


## An anglerfish swallows the fish: it vanishes and takes no part in the physics until
## [method release].
func swallow() -> void:
	if eaten:
		return
	eaten = true
	times_eaten += 1
	_layer_before_eaten = collision_layer
	_mask_before_eaten = collision_mask
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	visible = false


## A Thanos snap: the fish fades into dust and is out of the race for good (it counts as
## unfinished). Also sets [member eaten], so the race and the hazards leave it alone.
func snap() -> void:
	if eaten:
		return
	eaten = true
	snapped = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	RaceFx.burst(get_parent(), global_position, SNAP_DUST, 32, 140.0, Vector2(0, -30))
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, SNAP_FADE_SECONDS)
	tween.tween_callback(func() -> void: visible = false)


## Whether the fish is out of the race for good (snapped, stranded or dissolved). It counts as
## unfinished.
func is_out() -> bool:
	return snapped or stranded or dissolved


## Tracks how long the fish has been above the waterline at `waterline_y` (world pixels, the
## fish counts as dry while its center is above it). The fish gasps once it has been dry a
## while and is stranded after [constant DRY_GRACE] seconds. Getting wet again dries it out
## twice as fast as it gathered. Returns true on the call that strands the fish.
func update_dryness(waterline_y: float, delta: float) -> bool:
	if eaten:
		return false
	if global_position.y >= waterline_y:
		dry_time = maxf(dry_time - delta * 2.0, 0.0)
		return false
	var before: float = dry_time
	dry_time += delta
	if dry_time >= DRY_GRACE:
		strand()
		return true
	# Flash at the warning mark and then roughly every half second.
	if _fish != null and dry_time >= DRY_WARNING and floorf(dry_time * 2.0) != floorf(before * 2.0):
		_fish.flash(FLOP_TINT, 0.4)
	return false


## The tide leaves the fish behind: it flops on the spot, fades away and is out of the race for
## good (it counts as unfinished). Also sets [member eaten], so the race and the hazards leave
## it alone.
func strand() -> void:
	if eaten:
		return
	eaten = true
	stranded = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	RaceFx.burst(get_parent(), global_position, RaceFx.SPLASH_COLOR, 10, 70.0, Vector2(0, -40))
	var base: Vector2 = global_position
	var heading_before: float = _fish.heading if _fish != null else 0.0
	_strand_tween = create_tween()
	_strand_tween.tween_method(
		func(t: float) -> void: _flop(base, heading_before, t), 0.0, 1.0, FLOP_SECONDS
	)
	_strand_tween.tween_property(self, "modulate:a", 0.0, STRAND_FADE_SECONDS)
	_strand_tween.tween_callback(func() -> void: visible = false)


## Stomach acid eats the fish: it fizzes, sinks a little and fades, and is out of the race for
## good (it counts as unfinished). The acid pit draws the skeleton it leaves behind. Also sets
## [member eaten], so the race and the hazards leave it alone.
func dissolve() -> void:
	if eaten:
		return
	eaten = true
	dissolved = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	if _fish != null:
		_fish.flash(ACID_COLOR, DISSOLVE_SECONDS)
	_strand_tween = create_tween()
	_strand_tween.set_parallel(true)
	_strand_tween.tween_property(
		self, "global_position:y", global_position.y + 10.0, DISSOLVE_SECONDS
	)
	_strand_tween.tween_property(self, "modulate:a", 0.0, DISSOLVE_SECONDS)
	_strand_tween.chain().tween_callback(func() -> void: visible = false)


## Ends a stranded or dissolving fish's last moments at once, leaving it gone. The race calls it
## when it ends, so a fish lost a moment before never reappears under the finish replay.
func finish_strand() -> void:
	if not stranded and not dissolved:
		return
	if _strand_tween != null:
		_strand_tween.kill()
		_strand_tween = null
	modulate.a = 0.0
	visible = false


## One frame of the stranded flop: hops and rocks side to side, tiring as it goes.
func _flop(base: Vector2, heading_before: float, t: float) -> void:
	var tiring: float = 1.0 - 0.6 * t
	global_position = base + Vector2(0.0, -absf(sin(t * TAU * 2.0)) * 10.0 * tiring)
	if _fish != null:
		_fish.heading = heading_before + sin(t * TAU * 3.0) * 0.7 * tiring


## Brings a swallowed fish back at `at`, moving with `velocity`.
func release(at: Vector2, velocity: Vector2) -> void:
	if not eaten or is_out():
		return
	eaten = false
	collision_layer = _layer_before_eaten
	collision_mask = _mask_before_eaten
	freeze = false
	global_position = at
	linear_velocity = velocity
	visible = true
	if _fish != null:
		_fish.flash(RaceFx.SPLASH_COLOR)


## A splash of bubbles where the fish crossed the finish.
func splash() -> void:
	RaceFx.burst(self, global_position, RaceFx.SPLASH_COLOR, 18, 110.0, Vector2(0, 60))


## Winner celebration: pulsing gold glow and a shower of sparkles.
func celebrate() -> void:
	if _fish != null:
		_fish.celebrating = true
	RaceFx.burst(self, global_position, RaceFx.WINNER_COLOR, 24, 150.0, Vector2(0, 30))


func _process(delta: float) -> void:
	_fish.face(replay_velocity if replaying else linear_velocity, delta)
	_trail.global_position = global_position
	var heading: Vector2 = replay_velocity if replaying else linear_velocity
	_trail.emitting = heading.length() > 60.0 and (replaying or not freeze)
	var size: Vector2 = _label.get_minimum_size()
	_label.global_position = global_position + Vector2(-size.x * 0.5, -RADIUS - size.y - 2.0)
