class_name BlastFx
extends Node2D
## The streamer's bubble blast: a short charge-up glow that pulls inward, a bright flash, then
## two shockwave rings and a bubble burst. Visual only; RacePowers pushes the fish.

const CHARGE_SECONDS: float = 0.14
const FLASH_SECONDS: float = 0.18
const TOTAL_SECONDS: float = 0.7
const FLASH_COLOR: Color = Color(0.85, 1.0, 1.0)

var radius: float = 200.0

var _age: float = 0.0
var _went_off: bool = false


func _ready() -> void:
	z_index = 9


func _process(delta: float) -> void:
	_age += delta
	if not _went_off and _age >= CHARGE_SECONDS:
		_went_off = true
		_go_off()
	queue_redraw()
	if _age >= TOTAL_SECONDS:
		queue_free()


func is_charging() -> bool:
	return _age < CHARGE_SECONDS


## 1 at the instant of the flash, fading to 0; 0 while charging.
func flash_alpha() -> float:
	if is_charging():
		return 0.0
	return clampf(1.0 - (_age - CHARGE_SECONDS) / FLASH_SECONDS, 0.0, 1.0)


func _go_off() -> void:
	var host: Node = get_parent()
	ShockRing.spawn(host, global_position, radius, 0.45, RaceFx.BOOST_COLOR, 6.0)
	ShockRing.spawn(host, global_position, radius * 0.65, 0.35, FLASH_COLOR, 3.0, 0.07)
	RaceFx.burst(host, global_position, RaceFx.BOOST_COLOR, 24, radius, Vector2.ZERO)


func _draw() -> void:
	if is_charging():
		var t: float = _age / CHARGE_SECONDS
		var glow: float = radius * 0.5 * (1.0 - t)
		draw_circle(Vector2.ZERO, glow + 12.0, Color(0.4, 0.95, 1.0, 0.15 + 0.35 * t))
		draw_arc(Vector2.ZERO, glow + 18.0, 0.0, TAU, 32, Color(0.8, 1.0, 1.0, 0.8 * t), 3.0)
		return
	var alpha: float = flash_alpha()
	draw_circle(Vector2.ZERO, radius * 0.35 * (1.3 - alpha), Color(FLASH_COLOR, 0.7 * alpha))
