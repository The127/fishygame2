class_name Slingshot
extends StaticBody2D
## A rubber face on a pinball table. A fish that touches it is kicked away along `kick`, like the
## slingshots over the lower flippers of a real table. The face itself is the `Collider`
## polygon; the `Sensor` (an Area2D) is a slightly bigger copy that sets it off. Kicks only
## depend on contacts, so a seed with no chat replays the same race.

const KICK_SPEED: float = 560.0
const FLASH_SECONDS: float = 0.35
const RUBBER: Color = Color(1.0, 0.8, 0.35)

## Direction of the kick, need not be normalized.
@export var kick: Vector2 = Vector2.UP

var _flash: float = 0.0
var _rubber: Line2D


func _ready() -> void:
	Replayable.join(self)
	var sensor: Area2D = get_node("Sensor") as Area2D
	sensor.body_entered.connect(_on_body_entered)
	# The rubber is the top edge of the face: the first two corners of the polygon.
	var face: PackedVector2Array = (get_node("Collider") as CollisionPolygon2D).polygon
	_rubber = Line2D.new()
	_rubber.points = PackedVector2Array([face[0], face[1]])
	_rubber.width = 5.0
	_rubber.z_index = 1
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rubber.material = material
	add_child(_rubber)
	_show_flash()


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta / FLASH_SECONDS, 0.0)
	_show_flash()


## Kicks `marble` away from the face. Returns whether it was kicked.
func kick_marble(marble: Marble) -> bool:
	_flash = 1.0
	var direction: Vector2 = kick.normalized()
	var gain: float = KICK_SPEED - marble.linear_velocity.dot(direction)
	if gain <= 0.0:
		return false
	marble.sleeping = false
	marble.apply_central_impulse(direction * gain * marble.mass)
	return true


## Glow of the face, 1 just after a kick fading to 0.
func get_flash() -> float:
	return _flash


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([_flash])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	_flash = Replayable.mix(from, to, weight, 0)
	_show_flash()


func _on_body_entered(body: Node2D) -> void:
	# Switched off while the finish replay plays, when the marbles only show the recording.
	if not is_physics_processing() or not body is Marble:
		return
	kick_marble(body as Marble)


func _show_flash() -> void:
	_rubber.default_color = Color(RUBBER, 0.35 + 0.65 * _flash)
	_rubber.width = 5.0 + 5.0 * _flash
