class_name FaultCrack
extends Node2D
## One crack of Earthquake Fault: a stretch of seafloor that stays shut until a quake splits it.
## Children: `Plug` (a StaticBody2D with a `Collider` and a `Visual` polygon that fills the gap
## exactly, so the floor looks whole), and for a pit a `Zone` (an Area2D over the pit). The node
## sits at the origin of the track, so the plug polygon is in track coordinates.
##
## A SHORTCUT is a hole right through the floor: once open, fish above it drop to the floor
## below and skip the stretch in between. A PIT is a hollow cut into the floor, filled with
## rubble: once open, fish roll in, are slowed by it and pushed on out the far side, so no fish
## is ever trapped. [QuakeFault] decides when a crack opens and ticks it.

enum Kind { SHORTCUT, PIT }

## Seconds the plug takes to fall away once it is released.
const OPEN_SECONDS: float = 0.6
## How far the plug sinks while it falls away, in pixels.
const SINK: float = 70.0
## Pit rubble: drag (per second) on the velocity of a fish in it, and the push along `push_dir`
## in pixels per second squared. The push beats gravity on the exit ramp, so nothing stays.
const PIT_DRAG: float = 5.5
const PIT_PUSH: float = 500.0
const MAGMA: Color = Color(1.0, 0.45, 0.12)

@export var kind: Kind = Kind.SHORTCUT
## Which way the pit pushes along x: 1 toward +x, -1 toward -x. The way the floor slopes down.
@export_range(-1, 1, 2) var push_dir: int = 1
## The jagged line across the plug that glows with magma, in track coordinates.
@export var seam: PackedVector2Array = PackedVector2Array()

## 0 while the plug is in place, 1 when it has fallen away.
var openness: float = 0.0
## 0..1 glow of the seam while a quake builds up under this crack.
var alert: float = 0.0

var _opened: bool = false
var _plug: StaticBody2D
var _collider: CollisionPolygon2D
var _visual: Polygon2D
var _zone: Area2D
var _time: float = 0.0


func _ready() -> void:
	Replayable.join(self)
	z_index = 1
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	_plug = get_node("Plug") as StaticBody2D
	_collider = _plug.get_node("Collider") as CollisionPolygon2D
	_visual = _plug.get_node("Visual") as Polygon2D
	_zone = get_node_or_null("Zone") as Area2D
	queue_redraw()


## Puts the plug back in the floor, shut.
func close() -> void:
	_opened = false
	openness = 0.0
	alert = 0.0
	_collider.set_deferred("disabled", false)
	_apply_look()


## Lets the plug go: the floor opens here.
func open() -> void:
	if _opened:
		return
	_opened = true
	_collider.set_deferred("disabled", true)


func is_open() -> bool:
	return _opened


## The glow of the seam while a quake builds up under this crack. 0 turns it off.
func set_alert(amount: float) -> void:
	alert = clampf(amount, 0.0, 1.0)


## Middle of the crack in world coordinates, for the dust and for choosing which crack is ahead.
func center() -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for point: Vector2 in _collider.polygon:
		sum += point
	return to_global(sum / float(maxi(_collider.polygon.size(), 1)))


## Advances the fall of the plug and, on an open pit, the rubble acting on the fish in it.
func tick(delta: float) -> void:
	_time += delta
	if _opened and openness < 1.0:
		openness = minf(openness + delta / OPEN_SECONDS, 1.0)
	if _opened and kind == Kind.PIT and _zone != null:
		for body: Node2D in _zone.get_overlapping_bodies():
			if body is Marble:
				var marble: Marble = body as Marble
				var force: Vector2 = Vector2(float(push_dir) * PIT_PUSH, 0.0)
				marble.apply_central_force(
					(force - marble.linear_velocity * PIT_DRAG) * marble.mass
				)
	_apply_look()


## Part of the finish replay ([Replayable]).
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([openness, alert, _time])


func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	openness = Replayable.mix(from, to, weight, 0)
	alert = Replayable.mix(from, to, weight, 1)
	_time = Replayable.mix(from, to, weight, 2)
	_apply_look()


## The plug sinks and fades as it falls away, and the redraw lights the gap.
func _apply_look() -> void:
	if _visual == null:
		return
	_visual.position = Vector2(0.0, SINK * openness * openness)
	_visual.modulate.a = 1.0 - openness
	queue_redraw()


func _draw() -> void:
	if _collider == null:
		return
	var pulse: float = 0.5 + 0.5 * sin(_time * 18.0)
	var polygon: PackedVector2Array = _collider.polygon
	# The gap glows with magma once the plug is gone.
	if openness > 0.0 and polygon.size() >= 3:
		var glow: float = (0.18 if kind == Kind.SHORTCUT else 0.42) * minf(openness * 2.0, 1.0)
		draw_colored_polygon(polygon, Color(MAGMA, glow))
	var lit: float = 0.2 + 0.55 * alert * (0.6 + 0.4 * pulse) + 0.5 * openness
	if seam.size() >= 2:
		draw_polyline(seam, Color(MAGMA, clampf(lit, 0.0, 1.0)), 3.0, true)
		draw_polyline(seam, Color(MAGMA, clampf(lit * 0.3, 0.0, 1.0)), 9.0, true)
