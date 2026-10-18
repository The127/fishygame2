class_name FishDance
extends Node2D
## The winner's victory dance on the podium. Holds a [FishVisual] and moves it through a
## looping dance; floss, dab, moonwalk and twirl also give the fish two little arms.
## Every pose is a pure function of time ([method pose]), so a dance is easy to test.

enum Kind { RANDOM, FLOSS, DAB, WORM, MOONWALK, TWIRL }

## Chat names in the order of [enum Kind] after RANDOM.
const NAMES: Array[String] = ["floss", "dab", "worm", "moonwalk", "twirl"]
const ARM_LENGTH: float = 14.0
const ARM_WIDTH: float = 2.6
const HAND_RADIUS: float = 2.4
## Cartoon gloves, so the hands read against any fish color.
const GLOVE: Color = Color(0.97, 0.97, 1.0)
## Where the arms join the body, in the fish's own space (it faces +x, y points down).
const SHOULDER: Vector2 = Vector2(3.0, 4.0)
const OUTLINE: Color = Color(0.0, 0.03, 0.08, 0.9)

## The dance being shown; never RANDOM once set up.
var kind: int = Kind.FLOSS
var fish: FishVisual = null

var _time: float = 0.0
## Carries the dance's offset, rotation, scale and skew; the arms and the fish ride on it.
var _body: Node2D
var _back_arm: Node2D
var _front_arm: Node2D
var _arm_color: Color = Color.WHITE
var _pose: Dictionary = {}


## The kind for a chat name, RANDOM if unknown.
static func kind_of(item: String) -> int:
	return NAMES.find(item.strip_edges().to_lower()) + 1


## [param wanted] itself, or a random dance when it is RANDOM or out of range.
static func pick(wanted: int, rng: RandomNumberGenerator) -> int:
	if wanted > Kind.RANDOM and wanted <= NAMES.size():
		return wanted
	return rng.randi_range(1, NAMES.size())


## The pose of [param dance] at [param t] seconds: "offset" (Vector2), "rotation", "scale"
## (Vector2), "skew", and the arm angles "back_arm" and "front_arm" (radians in the fish's
## space, 0 points at the snout, PI/2 down), or NAN when the dance has no arms.
static func pose(dance: int, t: float) -> Dictionary:
	var p: Dictionary = {
		"offset": Vector2.ZERO,
		"rotation": 0.0,
		"scale": Vector2.ONE,
		"skew": 0.0,
		"back_arm": NAN,
		"front_arm": NAN,
	}
	match dance:
		Kind.FLOSS:
			_floss(p, t)
		Kind.DAB:
			_dab(p, t)
		Kind.WORM:
			_worm(p, t)
		Kind.MOONWALK:
			_moonwalk(p, t)
		Kind.TWIRL:
			_twirl(p, t)
	return p


## Hips swing one way while both straight arms swing the other, passing front and back.
static func _floss(p: Dictionary, t: float) -> void:
	var swing: float = sin(TAU * t / 0.9)
	p["offset"] = Vector2(7.0 * swing, -2.0 * absf(swing))
	p["rotation"] = -0.15 * swing
	p["back_arm"] = PI * 0.5 - 1.3 * swing - 0.15
	p["front_arm"] = PI * 0.5 - 1.3 * swing + 0.15
	# The arms cross as the hips pass the middle, so which one is in front flips there.
	if cos(TAU * t / 0.9) < 0.0:
		var back: float = p["back_arm"]
		p["back_arm"] = p["front_arm"]
		p["front_arm"] = back


## Snaps into a dab (head down into one elbow, the other arm thrown up and back), holds it,
## then switches sides on the next beat.
static func _dab(p: Dictionary, t: float) -> void:
	var beat: float = 1.4
	var phase: float = fposmod(t, beat) / beat
	var side: float = 1.0 if posmod(int(floor(t / beat)), 2) == 0 else -1.0
	var k: float = 0.0
	if phase < 0.12:
		k = ease(phase / 0.12, 0.3)
	elif phase < 0.7:
		k = 1.0
	elif phase < 0.85:
		k = 1.0 - ease((phase - 0.7) / 0.15, 2.0)
	p["scale"] = Vector2(side, 1.0)
	p["rotation"] = 0.45 * k * side
	p["offset"] = Vector2(0.0, -3.0 * sin(PI * clampf(phase / 0.2, 0.0, 1.0)))
	# The thrown arm is the front one: behind the body it would be hidden.
	p["front_arm"] = lerpf(PI * 0.5 + 0.3, PI + 0.75, k)
	p["back_arm"] = lerpf(PI * 0.5 - 0.3, -1.0, k)


## A wave rolls through the body from snout to tail while it inches back and forth.
static func _worm(p: Dictionary, t: float) -> void:
	var w: float = TAU * t / 0.8
	p["offset"] = Vector2(8.0 * sin(w * 0.25), -6.0 * maxf(0.0, sin(w + 0.8)))
	p["rotation"] = 0.35 * sin(w)
	p["skew"] = 0.25 * cos(w)
	var squash: float = 0.08 * sin(2.0 * w)
	p["scale"] = Vector2(1.0 + squash, 1.0 - squash)


## Glides backwards across the step with little bobs, then turns round and glides back.
static func _moonwalk(p: Dictionary, t: float) -> void:
	var lap: float = 2.4
	var phase: float = fposmod(t, lap * 2.0)
	var side: float = 1.0 if phase < lap else -1.0
	var u: float = fposmod(phase, lap) / lap
	# Kept narrow so the fish never glides into the winner's cup beside it.
	var x: float = lerpf(8.0, -8.0, u) * side
	var step: float = sin(TAU * t / 0.4)
	p["scale"] = Vector2(side, 1.0)
	p["offset"] = Vector2(x, -1.5 * absf(step))
	p["skew"] = 0.08 * step
	p["back_arm"] = PI * 0.5 + 0.4 + 0.3 * step
	p["front_arm"] = PI * 0.5 - 0.2 - 0.3 * step


## Hops into a full spin, lands and throws both arms up.
static func _twirl(p: Dictionary, t: float) -> void:
	var beat: float = 1.6
	var phase: float = fposmod(t, beat) / beat
	if phase < 0.5:
		var u: float = phase / 0.5
		var turn: float = cos(TAU * ease(u, -2.0))
		# A zero scale has no inverse, so the edge-on frame stays a sliver wide.
		p["scale"] = Vector2(signf(turn) * maxf(absf(turn), 0.05) if turn != 0.0 else 0.05, 1.0)
		p["offset"] = Vector2(0.0, -10.0 * sin(PI * u))
		p["back_arm"] = PI * 0.5 + 0.5
		p["front_arm"] = PI * 0.5 - 0.5
	else:
		var shake: float = 0.15 * sin(TAU * t * 4.0)
		p["back_arm"] = -PI * 0.5 - 0.6 + shake
		p["front_arm"] = -PI * 0.5 + 0.6 - shake


func _ready() -> void:
	_body = Node2D.new()
	add_child(_body)
	_back_arm = _add_arm_layer(true)
	if fish != null:
		_arm_color = (
			fish.color if fish.skin == FishSkin.Kind.NONE else FishSkin.accent_of(fish.skin)
		)
		_body.add_child(fish)
		# FishVisual detaches itself in _ready to follow a marble; here it dances in place.
		fish.top_level = false
	_front_arm = _add_arm_layer(false)
	_apply(pose(kind, 0.0))


func _add_arm_layer(behind: bool) -> Node2D:
	var layer := Node2D.new()
	# The fish draws at z 5, so the arms go just below and just above it.
	layer.z_index = 4 if behind else 6
	layer.draw.connect(_draw_arm.bind(layer, "back_arm" if behind else "front_arm"))
	_body.add_child(layer)
	return layer


func _process(delta: float) -> void:
	_time += delta
	_apply(pose(kind, _time))


func _apply(p: Dictionary) -> void:
	_pose = p
	_body.position = p["offset"]
	_body.rotation = p["rotation"]
	_body.scale = p["scale"]
	_body.skew = p["skew"]
	_back_arm.queue_redraw()
	_front_arm.queue_redraw()


func _draw_arm(layer: Node2D, key: String) -> void:
	var angle: float = _pose.get(key, NAN)
	if is_nan(angle):
		return
	var shoulder: Vector2 = SHOULDER + (Vector2(-2.0, 0.0) if key == "back_arm" else Vector2.ZERO)
	var hand: Vector2 = shoulder + Vector2.from_angle(angle) * ARM_LENGTH
	var tint: Color = _arm_color.darkened(0.35) if key == "back_arm" else _arm_color.lightened(0.15)
	layer.draw_line(shoulder, hand, OUTLINE, ARM_WIDTH + 1.6, true)
	layer.draw_circle(hand, HAND_RADIUS + 0.8, OUTLINE)
	layer.draw_line(shoulder, hand, tint, ARM_WIDTH, true)
	layer.draw_circle(hand, HAND_RADIUS, GLOVE if key == "front_arm" else GLOVE.darkened(0.2))
