class_name RubberDuck
extends Node2D
## Easter egg: a small rubber duck that very rarely drifts through the background of a map.
##
## Purely visual: no collision or physics body, drawn behind the fish, and it never draws
## from the race's random numbers. Which races get one, and its route, come from a seed.

## One race in this many gets a duck.
const ODDS: int = 25
## Between the far and the mid environment layers, so it is always behind the fish.
const DUCK_Z: int = -45
const SIZE: float = 1.0
const MIN_SPEED: float = 35.0
const MAX_SPEED: float = 60.0
## How far past the view edge the duck starts and ends, in pixels.
const MARGIN: float = 140.0
const BODY: Color = Color(0.95, 0.78, 0.16)
const BODY_SHADE: Color = Color(0.72, 0.5, 0.1)
const BEAK: Color = Color(0.95, 0.42, 0.1)

var velocity: Vector2 = Vector2.ZERO

var _time: float = 0.0
var _home_y: float = 0.0
var _end_x: float = 0.0
var _facing: float = 1.0


## True for about one seed in [constant ODDS]. Pure function of the seed.
static func appears(seed_value: int, odds: int = ODDS) -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randi() % maxi(odds, 1) == 0


## A duck that crosses [param bounds] (the map's view area), route chosen from the seed.
static func create(seed_value: int, bounds: Rect2) -> RubberDuck:
	var duck: RubberDuck = RubberDuck.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	# Offset so the route is not correlated with the draw that decided the duck appears.
	rng.seed = seed_value + 1
	duck._facing = 1.0 if rng.randf() < 0.5 else -1.0
	var speed: float = rng.randf_range(MIN_SPEED, MAX_SPEED)
	duck.velocity = Vector2(duck._facing * speed, 0.0)
	duck._home_y = bounds.position.y + bounds.size.y * rng.randf_range(0.15, 0.55)
	var start_x: float = bounds.position.x - MARGIN if duck._facing > 0.0 else bounds.end.x + MARGIN
	duck._end_x = bounds.end.x + MARGIN if duck._facing > 0.0 else bounds.position.x - MARGIN
	duck.position = Vector2(start_x, duck._home_y)
	duck.z_index = DUCK_Z
	duck.name = "RubberDuck"
	return duck


func _ready() -> void:
	Replayable.join(self)
	queue_redraw()


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([position.x, position.y, rotation, _time])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	position = Replayable.mix_vector(from, to, weight, 0)
	rotation = Replayable.mix(from, to, weight, 2)
	_time = Replayable.mix(from, to, weight, 3)


func _process(delta: float) -> void:
	_time += delta
	position.x += velocity.x * delta
	position.y = _home_y + sin(_time * 1.7) * 7.0
	rotation = sin(_time * 1.1) * 0.09
	if (_end_x - position.x) * _facing <= 0.0:
		queue_free()


func _draw() -> void:
	# Drawn facing right; flipped for a duck heading left.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing * SIZE, SIZE))
	draw_circle(Vector2(0.0, 6.0), 26.0, BODY_SHADE)
	draw_circle(Vector2(0.0, 4.0), 25.0, BODY)
	# The tail lifts at the back.
	draw_colored_polygon(
		PackedVector2Array([Vector2(-20.0, 0.0), Vector2(-38.0, -12.0), Vector2(-24.0, 12.0)]), BODY
	)
	draw_circle(Vector2(16.0, -20.0), 14.0, BODY)
	draw_colored_polygon(
		PackedVector2Array([Vector2(27.0, -22.0), Vector2(40.0, -18.0), Vector2(27.0, -13.0)]), BEAK
	)
	draw_circle(Vector2(20.0, -24.0), 2.6, Color(0.1, 0.06, 0.02))
	draw_arc(Vector2(-2.0, 6.0), 13.0, PI * 0.9, PI * 1.9, 12, BODY_SHADE, 3.0, true)
	# A faint glow so it reads in the murk.
	draw_arc(Vector2(0.0, 4.0), 28.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, 0.12), 6.0, true)
	draw_set_transform(Vector2.ZERO)
