class_name AquariumFish
extends Node2D
## One fish in the tank. Its position is a spot in a wide world plus a depth: [member z] is
## 0 at the glass and 1 at the back. The tank turns that into a screen position and scale.
## Only the wandering lives here; the drawing is a [FishVisual].

## Seconds a fish keeps one swimming direction and depth target before picking new ones.
const WANDER_MIN: float = 4.0
const WANDER_MAX: float = 11.0
const SPEED_MIN: float = 50.0
const SPEED_MAX: float = 120.0
## How fast z and the vertical pitch follow their targets (per second).
const DEPTH_EASE: float = 0.6
const PITCH_EASE: float = 1.2
const MAX_PITCH: float = 0.35
const FADE_SECONDS: float = 1.0
## Where a trail starts behind the fish (pixels at scale 1), and how far the depth scale may
## drift before the particles are resized.
const TRAIL_TAIL: float = 10.0
const TRAIL_RESIZE_STEP: float = 0.05

var contestant: Contestant
var visual: FishVisual
## Where it swims. x is a fraction of the world width (it wraps at 1) so a resize keeps the
## spread, y is 0..1 down the water.
var world_x: float = 0.0
var depth_y: float = 0.5
var z: float = 0.5
## 1 swims right, -1 left.
var dir: float = 1.0
var speed: float = 80.0
## Opacity of the whole fish. The tank fades fish out and in when it rotates the crowd.
var fade: float = 0.0
var fading_out: bool = false

var _target_z: float = 0.5
var _target_y: float = 0.5
var _pitch: float = 0.0
var _target_pitch: float = 0.0
var _wander_left: float = 0.0
var _rng: RandomNumberGenerator
var _trail: CPUParticles2D
## The emitter's particle scale range at depth scale 1, as (min, max).
var _trail_base_scale: Vector2 = Vector2.ONE
var _trail_depth_scale: float = 1.0


func _init(p_rng: RandomNumberGenerator) -> void:
	_rng = p_rng
	visual = FishVisual.new()
	visual.glow_boost = 0.7
	add_child(visual)


## Gives the fish [param who]'s look and a fresh spot.
func assign(who: Contestant) -> void:
	contestant = who
	visual.color = who.color
	visual.species = who.species
	visual.pattern = who.pattern
	visual.accessory = who.accessory
	visual.skin = who.skin
	_build_trail(who.trail)
	world_x = _rng.randf()
	depth_y = _rng.randf_range(0.12, 0.8)
	z = _rng.randf()
	dir = 1.0 if _rng.randf() < 0.5 else -1.0
	speed = _rng.randf_range(SPEED_MIN, SPEED_MAX)
	_pitch = 0.0
	visual.heading = 0.0 if dir > 0.0 else PI
	fade = 0.0
	fading_out = false
	_pick_wander()
	_wander_left = _rng.randf_range(0.0, WANDER_MAX)


## Advances the wandering. Returns the velocity (pixels per second, unscaled) to face.
func step(delta: float, world_width: float) -> Vector2:
	_wander_left -= delta
	if _wander_left <= 0.0:
		_pick_wander()
	z = move_toward(z, _target_z, delta * DEPTH_EASE * 0.25)
	_pitch = lerpf(_pitch, _target_pitch, clampf(delta * PITCH_EASE, 0.0, 1.0))
	# Turn around near the top and bottom of the water instead of leaving it.
	if depth_y < 0.1:
		_target_pitch = absf(_target_pitch)
	elif depth_y > 0.85:
		_target_pitch = -absf(_target_pitch)
	var velocity: Vector2 = Vector2(dir * cos(_pitch), sin(_pitch)) * speed
	world_x = fposmod(world_x + velocity.x * delta / maxf(world_width, 1.0), 1.0)
	depth_y = clampf(depth_y + velocity.y * delta * 0.002, 0.05, 0.92)
	fade = move_toward(fade, 0.0 if fading_out else 1.0, delta / FADE_SECONDS)
	return velocity


## Moves and shows the trail behind the fish. [param active] is false for fish that are hidden
## or far away, which stop emitting. Call after the fish and its visual are placed.
func update_trail(active: bool, depth_scale: float) -> void:
	if _trail == null:
		return
	_trail.emitting = active
	if not active:
		return
	var behind: Vector2 = Vector2.from_angle(visual.heading) * TRAIL_TAIL * depth_scale
	_trail.global_position = global_position - behind
	_trail.z_index = visual.z_index - 1
	_trail.modulate = visual.modulate
	if absf(depth_scale - _trail_depth_scale) > TRAIL_RESIZE_STEP * _trail_depth_scale:
		_trail_depth_scale = depth_scale
		_trail.scale_amount_min = _trail_base_scale.x * depth_scale
		_trail.scale_amount_max = _trail_base_scale.y * depth_scale


## True once a fish that was told to leave has faded away.
func is_gone() -> bool:
	return fading_out and fade <= 0.0


## Gives the fish the emitter for [param kind] ([enum FishTrail.Kind]). The plain trail (0) is
## skipped: the tank already has its own bubbles.
func _build_trail(kind: int) -> void:
	if _trail != null:
		_trail.queue_free()
		_trail = null
	if kind <= 0:
		return
	_trail = FishTrail.make(kind)
	_trail.top_level = true
	_trail_base_scale = Vector2(_trail.scale_amount_min, _trail.scale_amount_max)
	_trail_depth_scale = 1.0
	add_child(_trail)


func _pick_wander() -> void:
	_wander_left = _rng.randf_range(WANDER_MIN, WANDER_MAX)
	_target_z = _rng.randf()
	_target_pitch = _rng.randf_range(-MAX_PITCH, MAX_PITCH)
	if _rng.randf() < 0.18:
		dir = -dir
	speed = _rng.randf_range(SPEED_MIN, SPEED_MAX)
