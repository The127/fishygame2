class_name FlushBowl
extends Whirlpool
## The toilet bowl of the Toilet Flush map: a [Whirlpool] dressed as porcelain with a cistern
## above it. The hazard event is the flush: the lever on the cistern swings down and the vortex
## spins up for a few seconds. The lever only follows the surge and the phase, which the replay
## already records, so the bowl needs no state of its own.

const PORCELAIN: Color = Color(0.82, 0.92, 0.96)
## Lever angle in radians when the flush is fully pulled.
const LEVER_DOWN: float = 0.75
const CISTERN_SIZE: Vector2 = Vector2(280.0, 84.0)
## Gap in pixels between the top of the bowl rim and the bottom of the cistern.
const CISTERN_GAP: float = 14.0
## Thickness of the bowl rim in the scene, used to sit the cistern on top of it.
const RIM_THICKNESS: float = 22.0
## Seconds a fish circles before it may go down the drain, at least and up to this many more.
## Shorter than a plain whirlpool's: the bowl is the opening act, not the whole race.
const BOWL_MIN_DWELL: float = 2.0
const BOWL_DWELL_SPREAD: float = 4.5


## Angle of the cistern lever: still at rest, twitching in the warning, pulled during the flush.
func get_lever_angle() -> float:
	var twitch: float = 0.0
	if phase == Phase.TELEGRAPH:
		twitch = 0.1 * sin(phase_time * 26.0) * phase_progress()
	return _surge * LEVER_DOWN + twitch


## Same mix of marble, race seed and arrival as the whirlpool, over a shorter stay.
func _dwell_needed(marble: Marble) -> float:
	var arrival: float = (
		marble.global_position.y * 0.0137 + marble.linear_velocity.length() * 0.0071
	)
	var mix: float = float(marble.id) * 0.618034 + _salt + arrival
	return BOWL_MIN_DWELL + fposmod(mix, 1.0) * BOWL_DWELL_SPREAD


func _draw() -> void:
	if _zone == null:
		return
	var center: Vector2 = to_local(_zone.global_position)
	draw_circle(center, _radius, Color(PORCELAIN, 0.07))
	super()
	_draw_cistern(center)


func _draw_cistern(center: Vector2) -> void:
	var bottom: float = center.y - _radius - RIM_THICKNESS - CISTERN_GAP
	var box: Rect2 = Rect2(
		Vector2(center.x - CISTERN_SIZE.x * 0.5, bottom - CISTERN_SIZE.y), CISTERN_SIZE
	)
	var flush: float = _surge
	draw_rect(box, Color(PORCELAIN, 0.16 + 0.1 * flush))
	draw_rect(box, Color(PORCELAIN, 0.6), false, 3.0)
	# Lid.
	var lid: Rect2 = Rect2(box.position + Vector2(-12.0, -14.0), Vector2(box.size.x + 24.0, 14.0))
	draw_rect(lid, Color(PORCELAIN, 0.34))
	draw_rect(lid, Color(PORCELAIN, 0.7), false, 2.0)
	# Pipe from the cistern into the bowl.
	var pipe_x: float = center.x
	draw_rect(Rect2(pipe_x - 20.0, bottom, 40.0, CISTERN_GAP + 4.0), Color(PORCELAIN, 0.4))
	# Water sloshing in the cistern, higher while it empties.
	var water: float = 0.62 - 0.4 * flush
	var water_top: float = box.end.y - box.size.y * water
	var sway: float = 3.0 * sin(clock * 2.4)
	draw_colored_polygon(
		PackedVector2Array(
			[
				Vector2(box.position.x + 4.0, water_top + sway),
				Vector2(box.end.x - 4.0, water_top - sway),
				Vector2(box.end.x - 4.0, box.end.y - 4.0),
				Vector2(box.position.x + 4.0, box.end.y - 4.0)
			]
		),
		Color(tint, 0.2)
	)
	_draw_lever(box)


func _draw_lever(box: Rect2) -> void:
	var pivot: Vector2 = Vector2(box.position.x, box.position.y + 34.0)
	var angle: float = get_lever_angle()
	# The lever points out to the left and swings down.
	var tip: Vector2 = pivot + Vector2(-58.0, 0.0).rotated(-angle)
	draw_line(pivot, tip, Color(PORCELAIN, 0.85), 7.0, true)
	draw_circle(tip, 9.0, Color(1.0, 0.85, 0.3, 0.9))
	draw_circle(pivot, 6.0, Color(PORCELAIN, 0.9))
	if phase == Phase.ACTIVE:
		draw_arc(tip, 18.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.3, 0.45 * _surge), 3.0, true)
