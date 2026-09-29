class_name RaceFx
extends RefCounted
## Cheap 2D effects for the race: a shared soft glow texture, bubble trails and
## one-shot particle bursts. Kept to small CPUParticles2D counts and no shaders so
## 20 fish stay light in the web export.

const GLOW_SIZE: int = 64
const BOOST_COLOR: Color = Color(0.35, 0.95, 1.0)
const CURSE_COLOR: Color = Color(0.6, 0.25, 0.85)
const SPLASH_COLOR: Color = Color(0.75, 0.95, 1.0)
const CHEER_COLOR: Color = Color(1.0, 0.75, 0.9)
const WINNER_COLOR: Color = Color(1.0, 0.85, 0.35)

static var _glow_texture: GradientTexture2D = null
static var _additive: CanvasItemMaterial = null


## A white radial gradient, opaque in the middle and clear at the edge. Tint it with modulate.
static func glow_texture() -> GradientTexture2D:
	if _glow_texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = GLOW_SIZE
		texture.height = GLOW_SIZE
		_glow_texture = texture
	return _glow_texture


static func additive_material() -> CanvasItemMaterial:
	if _additive == null:
		var material: CanvasItemMaterial = CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_additive = material
	return _additive


## A small continuous bubble emitter. Particles stay in world space, so the caller
## keeps it top level and moves it with the fish.
static func make_trail() -> CPUParticles2D:
	var trail: CPUParticles2D = CPUParticles2D.new()
	trail.amount = 10
	trail.lifetime = 0.8
	trail.local_coords = false
	trail.emitting = false
	trail.texture = glow_texture()
	trail.material = additive_material()
	trail.direction = Vector2.UP
	trail.spread = 50.0
	trail.gravity = Vector2(0, -25)
	trail.initial_velocity_min = 5.0
	trail.initial_velocity_max = 20.0
	trail.scale_amount_min = 0.06
	trail.scale_amount_max = 0.16
	trail.color = Color(0.7, 0.9, 1.0, 0.45)
	trail.color_ramp = _fade_ramp()
	trail.z_index = 4
	return trail


## Spawns a one-shot burst of glowing particles at a global position. It frees itself when done.
static func burst(
	host: Node,
	global_pos: Vector2,
	color: Color,
	amount: int = 14,
	speed: float = 90.0,
	gravity: Vector2 = Vector2(0, -40)
) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.top_level = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.7
	particles.local_coords = false
	particles.texture = glow_texture()
	particles.material = additive_material()
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = gravity
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.damping_min = 30.0
	particles.damping_max = 60.0
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.22
	particles.color = color
	particles.color_ramp = _fade_ramp()
	particles.z_index = 8
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	host.add_child(particles)
	particles.global_position = global_pos
	return particles


static func _fade_ramp() -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	return ramp
