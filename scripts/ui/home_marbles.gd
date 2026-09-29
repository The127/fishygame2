class_name HomeMarbles
extends Control
## Glass marbles with fish drifting across the home screen. They wrap around
## the edges, bounce off each other and get a kick when clicked.

const RADIUS: float = 48.0
const CLICK_IMPULSE: float = 240.0
const MARBLE_COUNT: int = 12
const GOLDEN_RATIO_CONJUGATE: float = 0.618034

var _marbles: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i: int in MARBLE_COUNT:
		var speed: float = rng.randf_range(50.0, 130.0)
		var angle: float = rng.randf() * TAU
		var marble: Dictionary = {
			"pos": Vector2(rng.randf() * size.x, rng.randf() * size.y),
			"vel": Vector2.from_angle(angle) * speed,
			"color": Color.from_hsv(fmod(float(i) * GOLDEN_RATIO_CONJUGATE, 1.0), 0.8, 0.95),
			"heading": angle,
			"spin": rng.randf() * TAU,
		}
		_marbles.append(marble)


func _process(delta: float) -> void:
	_time += delta
	_resolve_collisions()
	var pad: float = RADIUS
	var wrap: Vector2 = size + Vector2(pad, pad) * 2.0
	for marble: Dictionary in _marbles:
		var pos: Vector2 = marble["pos"]
		var vel: Vector2 = marble["vel"]
		pos += vel * delta
		pos.x = fposmod(pos.x + pad, wrap.x) - pad
		pos.y = fposmod(pos.y + pad, wrap.y) - pad
		marble["pos"] = pos
		marble["spin"] = float(marble["spin"]) + vel.length() / RADIUS * delta
		if vel.length() > 1.0:
			marble["heading"] = lerp_angle(float(marble["heading"]), vel.angle(), delta * 4.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	for marble: Dictionary in _marbles:
		var offset: Vector2 = marble["pos"] - click.position
		if offset.length() < RADIUS + 4.0:
			var dir: Vector2 = offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT
			marble["vel"] = Vector2(marble["vel"]) + dir * CLICK_IMPULSE
			accept_event()
			return


func _resolve_collisions() -> void:
	var diameter: float = RADIUS * 2.0
	for i: int in _marbles.size():
		for j: int in range(i + 1, _marbles.size()):
			var a: Dictionary = _marbles[i]
			var b: Dictionary = _marbles[j]
			var offset: Vector2 = Vector2(b["pos"]) - Vector2(a["pos"])
			var dist: float = offset.length()
			if dist >= diameter or dist < 0.0001:
				continue
			var normal: Vector2 = offset / dist
			var push: Vector2 = normal * (diameter - dist) * 0.5
			a["pos"] = Vector2(a["pos"]) - push
			b["pos"] = Vector2(b["pos"]) + push
			# Equal masses: swap the velocity components along the normal.
			var approach: float = (Vector2(a["vel"]) - Vector2(b["vel"])).dot(normal)
			if approach > 0.0:
				a["vel"] = Vector2(a["vel"]) - normal * approach
				b["vel"] = Vector2(b["vel"]) + normal * approach


func _draw() -> void:
	for marble: Dictionary in _marbles:
		_draw_marble(marble)


func _draw_marble(marble: Dictionary) -> void:
	var pos: Vector2 = marble["pos"]
	var color: Color = marble["color"]
	# Body, then a lighter core offset up-left for the glass depth.
	draw_circle(pos, RADIUS, color.darkened(0.35))
	draw_circle(pos + Vector2(-5, -6), RADIUS * 0.82, color)
	draw_circle(pos + Vector2(-9, -11), RADIUS * 0.5, color.lightened(0.25))
	_draw_fish(pos, float(marble["heading"]), color)
	# Fresnel rim and glass highlights.
	draw_arc(pos, RADIUS - 1.0, 0.0, TAU, 48, Color(0.6, 0.9, 1.0, 0.55), 2.5, true)
	draw_circle(pos + Vector2(-17, -21), 8.0, Color(1, 1, 1, 0.75))
	draw_circle(pos + Vector2(-9, -28), 3.0, Color(1, 1, 1, 0.5))


func _draw_fish(pos: Vector2, heading: float, color: Color) -> void:
	var facing_left: bool = absf(wrapf(heading, -PI, PI)) > PI * 0.5
	var flip: float = -1.0 if facing_left else 1.0
	var xform: Transform2D = Transform2D(heading, Vector2(1.0, flip), 0.0, pos)
	var wag: float = sin(_time * 8.0) * 3.0
	var body: Color = Color(1, 1, 1, 0.82)
	var tail: Color = Color(1, 1, 1, 0.5)
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in 24:
		var a: float = float(k) / 24.0 * TAU
		pts.append(xform * Vector2(cos(a) * 18.0, sin(a) * 11.0))
	draw_colored_polygon(pts, body)
	var tail_pts: PackedVector2Array = PackedVector2Array(
		[Vector2(-14, 0), Vector2(-27, -10 + wag), Vector2(-23, wag * 0.4), Vector2(-27, 10 + wag)]
	)
	var moved: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in tail_pts:
		moved.append(xform * p)
	draw_colored_polygon(moved, tail)
	draw_circle(xform * Vector2(10, -3), 2.5, color.darkened(0.7))
