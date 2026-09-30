class_name GulpDebris
extends RigidBody2D
## A piece of sea junk the whale gulps down: a barrel, a crate or a plank. A gulp hazard owns a
## small pool of them and switches them on and off, so nothing is created during a race. A piece
## that falls into an acid pit fizzles away (see [method fizzle]).

enum Kind { BARREL, CRATE, PLANK }

const GROUP: StringName = &"acid_fodder"
const BARREL_RADIUS: float = 17.0
const CRATE_SIZE: float = 32.0
const PLANK_SIZE: Vector2 = Vector2(76.0, 13.0)
const WOOD: Color = Color(0.56, 0.38, 0.22)
const WOOD_DARK: Color = Color(0.3, 0.19, 0.12)
const WOOD_LIGHT: Color = Color(0.85, 0.66, 0.42)

var kind: Kind = Kind.BARREL
var is_active: bool = false
## Set when acid got it; the hazard that owns the pool then retires the piece.
var fizzling: bool = false

var _collision: CollisionShape2D


func _ready() -> void:
	add_to_group(GROUP)
	_collision = CollisionShape2D.new()
	add_child(_collision)
	mass = 2.0
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.5
	material.bounce = 0.35
	physics_material_override = material
	deactivate()


## Switches the piece on as `new_kind`, at `at`, moving with `velocity`.
func activate(new_kind: Kind, at: Vector2, velocity: Vector2, angle: float) -> void:
	is_active = true
	fizzling = false
	show_as(new_kind)
	collision_layer = 1
	collision_mask = 1
	freeze = false
	global_position = at
	rotation = angle
	linear_velocity = velocity
	angular_velocity = 0.0
	visible = true


## Switches the piece off: hidden, frozen and out of the physics.
func deactivate() -> void:
	is_active = false
	fizzling = false
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	# Deferred: a race can end (and clear the pool) from inside a physics callback.
	set_deferred("freeze", true)
	visible = false


## Takes on the shape and look of `new_kind` without touching the physics state.
func show_as(new_kind: Kind) -> void:
	kind = new_kind
	match kind:
		Kind.BARREL:
			var circle: CircleShape2D = CircleShape2D.new()
			circle.radius = BARREL_RADIUS
			_collision.shape = circle
		Kind.CRATE:
			var box: RectangleShape2D = RectangleShape2D.new()
			box.size = Vector2.ONE * CRATE_SIZE
			_collision.shape = box
		Kind.PLANK:
			var plank: RectangleShape2D = RectangleShape2D.new()
			plank.size = PLANK_SIZE
			_collision.shape = plank
	queue_redraw()


## Acid got the piece.
func fizzle() -> void:
	fizzling = true


func _draw() -> void:
	match kind:
		Kind.BARREL:
			draw_circle(Vector2.ZERO, BARREL_RADIUS, WOOD)
			draw_arc(Vector2.ZERO, BARREL_RADIUS - 5.0, 0.0, TAU, 20, WOOD_DARK, 2.0, true)
			draw_arc(Vector2.ZERO, BARREL_RADIUS, 0.0, TAU, 24, WOOD_LIGHT, 2.0, true)
			draw_circle(Vector2.ZERO, 3.0, WOOD_DARK)
		Kind.CRATE:
			var half: float = CRATE_SIZE * 0.5
			draw_rect(Rect2(-half, -half, CRATE_SIZE, CRATE_SIZE), WOOD)
			draw_line(Vector2(-half, -half), Vector2(half, half), WOOD_DARK, 3.0, true)
			draw_line(Vector2(-half, half), Vector2(half, -half), WOOD_DARK, 3.0, true)
			draw_rect(Rect2(-half, -half, CRATE_SIZE, CRATE_SIZE), WOOD_LIGHT, false, 2.0)
		Kind.PLANK:
			var size: Vector2 = PLANK_SIZE
			draw_rect(Rect2(-size * 0.5, size), WOOD)
			draw_rect(Rect2(-size * 0.5, size), WOOD_LIGHT, false, 2.0)
			draw_circle(Vector2(-size.x * 0.5 + 7.0, 0.0), 1.8, WOOD_DARK)
			draw_circle(Vector2(size.x * 0.5 - 7.0, 0.0), 1.8, WOOD_DARK)
