class_name SquishyLetter
extends RigidBody3D
## One extruded letter of the title, as a physics body. Hard landings squash it like jelly:
## the look springs back on its own while the collision box stays a plain rigid box, which
## keeps the physics stable (real soft bodies are unreliable in the web build).

## Spring stiffness and damping of the squash, per second squared and per second.
const SPRING: float = 320.0
const DAMPING: float = 11.0
## Squash added per unit of sudden upward speed change (a landing).
const KICK_PER_SPEED: float = 0.09
## Speed changes below this (world units per second) are not landings.
const IMPACT_MIN: float = 0.6
const MAX_SQUASH: float = 0.55
## Sideways bulge per unit of squash, so the letter keeps roughly its volume.
const BULGE: float = 0.55
## How flat a squished letter ends up: its height is 1 - FLAT_SQUASH of the original.
const FLAT_SQUASH: float = 0.86

## Current squash: 0 is the plain letter, positive is flatter and wider, negative taller.
var squash: float = 0.0
## Value the squash springs back to.
var rest_squash: float = 0.0
## Whether the letter was squished flat for good.
var flattened: bool = false

var _squash_speed: float = 0.0
var _last_velocity_y: float = 0.0
var _pivot: Node3D
var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _box: BoxShape3D
## Bounds of the letter's ink in body space.
var _ink: AABB


## [param text] is drawn with its line top-left at the body origin, like a [Label] line.
func _init(
	text: String, font: Font, font_size: int, pixel_size: float, depth: float, material: Material
) -> void:
	var mesh := TextMesh.new()
	mesh.text = text
	mesh.font = font
	mesh.font_size = font_size
	mesh.pixel_size = pixel_size
	mesh.depth = depth
	mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	mesh.material = material
	_ink = mesh.get_aabb()
	# Squash around the bottom middle of the ink, so a flattened letter stays on the ground.
	_pivot = Node3D.new()
	_pivot.position = Vector3(_ink.get_center().x, _ink.position.y, 0.0)
	add_child(_pivot)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.position = -_pivot.position
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_mesh)
	_box = BoxShape3D.new()
	_shape = CollisionShape3D.new()
	_shape.shape = _box
	add_child(_shape)
	_fit_collider(1.0)
	var surface := PhysicsMaterial.new()
	surface.bounce = 0.25
	surface.friction = 0.8
	physics_material_override = surface
	lock_rotation = true
	axis_lock_linear_z = true
	continuous_cd = true
	gravity_scale = 2.2


func _physics_process(delta: float) -> void:
	var change: float = linear_velocity.y - _last_velocity_y
	_last_velocity_y = linear_velocity.y
	# Gravity only ever lowers the vertical speed, so a sudden rise is something hitting us.
	if not freeze and change > IMPACT_MIN:
		kick(change * KICK_PER_SPEED)
	_squash_speed += (-SPRING * (squash - rest_squash) - DAMPING * _squash_speed) * delta
	squash = clampf(squash + _squash_speed * delta, -MAX_SQUASH, FLAT_SQUASH)
	var wide: float = 1.0 + maxf(squash, -0.3) * BULGE
	_pivot.scale = Vector3(wide, 1.0 - squash, wide)


## Bounds of the letter's ink in body space (unsquashed).
func ink() -> AABB:
	return _ink


## World y of the bottom of the letter's ink.
func bottom_y() -> float:
	return global_position.y + _ink.position.y


## World y of the top of the letter's ink, squash included.
func top_y() -> float:
	return bottom_y() + _ink.size.y * (1.0 - squash)


## Wobbles the letter: positive squashes it, negative stretches it.
func kick(amount: float) -> void:
	_squash_speed += clampf(amount, -MAX_SQUASH, MAX_SQUASH) * 30.0


## Squishes the letter flat for good. Its collision box shrinks to the pancake.
func flatten() -> void:
	flattened = true
	rest_squash = FLAT_SQUASH
	_squash_speed = 0.0
	squash = FLAT_SQUASH * 0.7
	_fit_collider(1.0 - FLAT_SQUASH)


## Puts the letter in its squished end state at once (no animation).
func set_flat() -> void:
	flatten()
	squash = FLAT_SQUASH
	_pivot.scale = Vector3(1.0 + FLAT_SQUASH * BULGE, 1.0 - FLAT_SQUASH, 1.0 + FLAT_SQUASH * BULGE)


## Turns the look of the letter around the vertical axis, so its extruded sides show.
func set_yaw(radians: float) -> void:
	_pivot.rotation.y = radians


func _fit_collider(height_fraction: float) -> void:
	var size: Vector3 = _ink.size
	size.y *= height_fraction
	size.z = maxf(size.z, 0.05)
	_box.size = size
	_shape.position = Vector3(_ink.get_center().x, _ink.position.y + size.y * 0.5, 0.0)
