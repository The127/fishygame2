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

var contestant: Contestant
var visual: FishVisual
## Where it swims, in tank units. x wraps at the world width, y is 0..1 down the water.
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


func _init(p_rng: RandomNumberGenerator) -> void:
	_rng = p_rng
	visual = FishVisual.new()
	visual.glow_boost = 0.7
	add_child(visual)


## Gives the fish [param who]'s look and a fresh spot. [param world_width] is the tank's world
## width in pixels.
func assign(who: Contestant, world_width: float) -> void:
	contestant = who
	visual.color = who.color
	visual.species = who.species
	visual.pattern = who.pattern
	visual.accessory = who.accessory
	world_x = _rng.randf() * world_width
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
	world_x = posmod(world_x + velocity.x * delta, world_width)
	depth_y = clampf(depth_y + velocity.y * delta * 0.002, 0.05, 0.92)
	fade = move_toward(fade, 0.0 if fading_out else 1.0, delta / FADE_SECONDS)
	return velocity


## True once a fish that was told to leave has faded away.
func is_gone() -> bool:
	return fading_out and fade <= 0.0


func _pick_wander() -> void:
	_wander_left = _rng.randf_range(WANDER_MIN, WANDER_MAX)
	_target_z = _rng.randf()
	_target_pitch = _rng.randf_range(-MAX_PITCH, MAX_PITCH)
	if _rng.randf() < 0.18:
		dir = -dir
	speed = _rng.randf_range(SPEED_MIN, SPEED_MAX)
