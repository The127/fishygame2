class_name PowerCursor
extends Node2D
## A ring that follows the mouse while a streamer power is armed, showing how far it reaches.
## The ring is styled per power and carries the power's icon in the middle.

const ICON_HALF: float = 9.0
const TICKS: int = 12

## The armed power, a [enum StreamerPowers.Kind], or -1 for none.
var kind: int = -1
var radius: float = 0.0:
	set(value):
		radius = value
		visible = value > 0.0
		queue_redraw()

var _time: float = 0.0


func _ready() -> void:
	z_index = 20
	visible = false


func _process(delta: float) -> void:
	if radius > 0.0:
		global_position = get_global_mouse_position()
		_time += delta
		queue_redraw()


## Shows the ring of [param power_kind] reaching [param reach] pixels. Pass -1 to hide it.
func arm(power_kind: int, reach: float) -> void:
	kind = power_kind
	radius = reach if power_kind >= 0 else 0.0


func _draw() -> void:
	if radius <= 0.0:
		return
	var color: Color = UiStyle.power_color(kind) if kind >= 0 else Color.WHITE
	var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
	match kind:
		StreamerPowers.Kind.NET:
			# Dashes turning slowly, like a net being drawn in.
			var dash: float = TAU / float(TICKS)
			for i: int in TICKS:
				var start: float = _time * 0.6 + dash * float(i)
				draw_arc(Vector2.ZERO, radius, start, start + dash * 0.6, 6, Color(color, 0.8), 2.0)
		StreamerPowers.Kind.BLAST:
			# A solid ring with a second one breathing just inside it.
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, 0.8), 2.0)
			draw_arc(
				Vector2.ZERO, radius * (0.82 + 0.1 * pulse), 0.0, TAU, 48, Color(color, 0.35), 2.0
			)
		_:
			# The rod: a solid ring with tick marks pointing at the centre.
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, 0.8), 2.0)
			for i: int in 4:
				var dir: Vector2 = Vector2.from_angle(TAU * float(i) / 4.0)
				draw_line(dir * (radius - 8.0), dir * radius, Color(color, 0.9), 3.0)
	# A soft disc behind the icon keeps it readable over any track.
	draw_circle(Vector2.ZERO, ICON_HALF + 5.0, Color(0.0, 0.03, 0.08, 0.45))
	if kind >= 0:
		PowerIcon.draw(self, kind, Vector2.ZERO, ICON_HALF, Color(color, 0.9 + 0.1 * pulse))
	else:
		draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0, 0.9))
