class_name CoralBed
extends Node2D
## One opening in a lane of the Coral Garden that living coral can grow shut. The bed sits at the
## upstream lip of the opening. Children: `Trigger`, an Area2D on the lane just upstream (the
## first fish into it wakes the coral), and everything else is built in [method _ready]: a `Plug`
## (an AnimatableBody2D that slides out of the lane into the opening as the coral grows) and the
## drawn coral.
##
## A woken bed goes through [enum Stage]: the polyps glow for a moment (WARN), the coral grows
## across the opening (GROWING) and then stays grown for the rest of the race. The plug is thin,
## in line with the lane and slides in from the side, so it never crushes a fish: a fish that is
## falling through the opening when the coral arrives is brushed on and keeps falling.
##
## Coordinates below are "flow" coordinates: `u` runs along the lane in the direction fish roll
## (from the upstream lip, 0, to the downstream lip, `gap_width`) and `v` is the depth under the
## lane's surface. See [method _at].

signal burst_played(position: Vector2, color: Color, amount: int, speed: float, gravity: Vector2)

enum Stage { DORMANT, WARN, GROWING, GROWN }

## How far the plug reaches into the lane at either end of a closed opening, in pixels.
const OVERLAP: float = 14.0
## The plug rests this far inside the upstream lip, so its end face never lies on the lane's.
const REST_INSET: float = 2.0
const TONGUE_COLOR: Color = Color(0.78, 0.26, 0.3)
const TONGUE_EDGE: Color = Color(1.0, 0.62, 0.45)
const POLYP_COLORS: Array[Color] = [
	Color(1.0, 0.45, 0.55), Color(1.0, 0.65, 0.3), Color(1.0, 0.85, 0.45), Color(0.95, 0.5, 0.9)
]
const SPORE_COLOR: Color = Color(1.0, 0.8, 0.6)
## Branches that hang from the tongue once it has grown, and how many times each one forks.
const ROOTS: int = 7
## Buds on the two faces of the opening while the coral sleeps.
const BUDS: int = 3
## Seconds between moves of the sway and the twinkle of grown coral.
const ANIMATE_STEP: float = 1.0 / 30.0

## +1 when the lane descends to the right, -1 when it descends to the left.
@export_enum("Left:-1", "Right:1") var flow: int = 1
## Width of the opening between the two lips, in pixels.
@export var gap_width: float = 110.0
## Fall of the lane's surface per pixel of horizontal distance.
@export var slope: float = 0.085
@export var thickness: float = 22.0
## Seconds the polyps glow before the coral starts to grow, and the time it takes to close.
@export var warn_seconds: float = 1.0
@export var grow_seconds: float = 4.0

var stage: Stage = Stage.DORMANT
## How much of the opening the coral covers, 0 to 1.
var growth: float = 0.0
## 0 to 1 glow of the polyps (WARN, or a hazard event pointing at this bed).
var glow: float = 0.0
## Extra seconds this race adds to the warning, drawn from the race seed.
var hesitation: float = 0.0

var _plug: AnimatableBody2D
## The reach the plug was last put at, so a plug that has not moved is left alone.
var _plug_reach: float = NAN
var _time_in_stage: float = 0.0
var _clock: float = 0.0
var _seed: int = 1
var _spores: float = 0.0
var _roots: Array[Dictionary] = []
## The drawn branches, one per root, and the buds on the faces of the opening.
var _branches: Array[CoralBranch] = []
var _buds: Array[Dictionary] = []
## Layers the grown coral is drawn on, so a drawing that does not change is kept: the tongue, the
## flecks of light on it (they twinkle) and, after them, the branches.
var _tongue_layer: Node2D
var _fleck_layer: Node2D
## The growth the tongue layer was last drawn at.
var _tongue_growth: float = -1.0
## The race clock when the sway and the twinkle were last moved, and whether the last drawing of
## the bed itself showed buds.
var _animated_at: float = -1.0
var _buds_drawn: bool = true

@onready var _trigger: Area2D = $Trigger


func _ready() -> void:
	_seed = hash(name) + 17
	_build_plug()
	_tongue_layer = _add_layer("Tongue", _draw_tongue)
	_fleck_layer = _add_layer("Flecks", _draw_flecks)
	_build_roots()
	z_index = 2
	reset()


## Puts the bed back to sleep with the lane open.
func reset() -> void:
	stage = Stage.DORMANT
	growth = 0.0
	glow = 0.0
	_time_in_stage = 0.0
	_spores = 0.0
	hesitation = 0.0
	pose()


## Whether a fish is in the trigger zone right now.
func fish_in_trigger() -> bool:
	for body: Node2D in _trigger.get_overlapping_bodies():
		if body is Marble:
			return true
	return false


## Wakes the coral: the polyps glow and then it grows. Returns whether it woke (it only does from
## sleep).
func wake() -> bool:
	if stage != Stage.DORMANT:
		return false
	stage = Stage.WARN
	_time_in_stage = 0.0
	return true


## Starts the growth at once, without the warning. Returns whether it started.
func grow_now() -> bool:
	if stage != Stage.DORMANT and stage != Stage.WARN:
		return false
	stage = Stage.GROWING
	_time_in_stage = 0.0
	_spore(0.0, 10)
	return true


## Whether the opening lets fish through. It counts as shut once the coral covers most of it.
func is_open() -> bool:
	return growth < 0.6


## Advances the coral by `delta` seconds. `clock` is the map's race clock, for the sway.
func advance(delta: float, clock: float) -> void:
	_clock = clock
	match stage:
		Stage.WARN:
			_time_in_stage += delta
			var length: float = warn_seconds + hesitation
			var pulse: float = 0.5 + 0.5 * sin(_clock * 16.0)
			glow = clampf(_time_in_stage / length, 0.0, 1.0) * (0.55 + 0.45 * pulse)
			if _time_in_stage >= length:
				grow_now()
		Stage.GROWING:
			_time_in_stage += delta
			growth = clampf(_time_in_stage / grow_seconds, 0.0, 1.0)
			glow = 1.0 - growth
			_spores += delta
			if _spores >= 0.35 and growth < 1.0:
				_spores = 0.0
				_spore(growth, 4)
			if growth >= 1.0:
				stage = Stage.GROWN
				glow = 0.0
				_spore(1.0, 12)
	pose()


## Part of the finish replay: the state of this bed as three floats.
func replay_values() -> PackedFloat32Array:
	return PackedFloat32Array([float(stage), growth, glow])


## Shows the bed as it was `weight` of the way from `from` to `to`, both starting at `at`.
func apply_replay(
	from: PackedFloat32Array, to: PackedFloat32Array, weight: float, at: int, clock: float
) -> void:
	_clock = clock
	stage = int(Replayable.step(from, to, weight, at)) as Stage
	growth = Replayable.mix(from, to, weight, at + 1)
	glow = Replayable.mix(from, to, weight, at + 2)
	pose()


## Puts the plug and the drawing where the state says. The plug is given position and angle in
## one go: set one after the other, a physics body ignores the first.
func pose(force_plug: bool = false) -> void:
	if _plug != null and (force_plug or _reach() != _plug_reach):
		var reach: float = _reach()
		_plug_reach = reach
		_plug.transform = Transform2D(0.0, _at(reach, 0.0) - _at(-REST_INSET, 0.0))
	var shown: bool = growth > 0.04
	if _tongue_layer != null and (shown or _tongue_layer.visible):
		_tongue_layer.visible = shown
		_fleck_layer.visible = shown
		# The sway and the twinkle are slow: a third of the frames is enough for them.
		if growth != _tongue_growth or absf(_clock - _animated_at) >= ANIMATE_STEP:
			_animated_at = _clock
			_pose_branches()
			if shown:
				_fleck_layer.queue_redraw()
			if growth != _tongue_growth:
				_tongue_growth = growth
				_tongue_layer.queue_redraw()
	if growth < 1.0 or _buds_drawn:
		queue_redraw()


## Where the closed opening's far edge, the plug's leading end, is along the lane right now.
func _reach() -> float:
	return -REST_INSET + growth * (gap_width + OVERLAP + REST_INSET)


## Position, in this node's space, of the point `u` along the lane and `v` under its surface.
func _at(u: float, v: float) -> Vector2:
	return Vector2(u * float(flow), u * slope + v)


## World position of the middle of the opening, on the lane's surface.
func gap_center() -> Vector2:
	return to_global(_at(gap_width * 0.5, 0.0))


func _build_plug() -> void:
	_plug = AnimatableBody2D.new()
	_plug.name = "Plug"
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.6
	material.bounce = 0.3
	_plug.physics_material_override = material
	var length: float = gap_width + 2.0 * OVERLAP
	var collider: CollisionPolygon2D = CollisionPolygon2D.new()
	collider.name = "Collider"
	# The plug's rest pose has its leading end just inside the upstream lip; it is drawn by this
	# node, so it needs no visual of its own.
	collider.polygon = PackedVector2Array(
		[
			_at(-REST_INSET - length, 0.0),
			_at(-REST_INSET, 0.0),
			_at(-REST_INSET, thickness),
			_at(-REST_INSET - length, thickness)
		]
	)
	_plug.add_child(collider)
	add_child(_plug)


func _build_roots() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed
	_roots.clear()
	for i: int in ROOTS:
		var across: float = (float(i) + rng.randf_range(0.25, 0.75)) / float(ROOTS)
		var root: Dictionary = {
			"at": across,
			"length": rng.randf_range(34.0, 62.0),
			"lean": rng.randf_range(-0.35, 0.35),
			"phase": rng.randf_range(0.0, TAU),
			"color": POLYP_COLORS[rng.randi_range(0, POLYP_COLORS.size() - 1)],
			"seed": rng.randi(),
		}
		_roots.append(root)
		var branch: CoralBranch = CoralBranch.new()
		branch.name = "Branch%d" % i
		branch.visible = false
		branch.setup(float(root["length"]), root["color"], TONGUE_COLOR, int(root["seed"]))
		add_child(branch)
		_branches.append(branch)
	# The buds' colors and how far each one reaches, drawn from the seed once.
	rng.seed = _seed + 5
	_buds.clear()
	for face: int in 2:
		for i: int in BUDS:
			(
				_buds
				. append(
					{
						"face": face,
						"index": i,
						"color": POLYP_COLORS[rng.randi_range(0, POLYP_COLORS.size() - 1)],
						"reach": 5.0 + rng.randf_range(0.0, 4.0),
					}
				)
			)


func _spore(at_growth: float, amount: int) -> void:
	var where: Vector2 = to_global(_at(at_growth * gap_width, thickness * 0.5))
	var gravity: Vector2 = Vector2(0.0, -30.0)
	RaceFx.burst(self, where, SPORE_COLOR, amount, 70.0, gravity)
	burst_played.emit(where, SPORE_COLOR, amount, 70.0, gravity)


func _add_layer(layer_name: String, drawer: Callable) -> Node2D:
	var layer: Node2D = Node2D.new()
	layer.name = layer_name
	layer.visible = false
	layer.draw.connect(drawer.bind(layer))
	add_child(layer)
	return layer


func _draw() -> void:
	_buds_drawn = growth < 1.0
	_draw_buds()


## Sleeping buds on the two faces of the opening. They glow when the coral is about to wake.
func _draw_buds() -> void:
	var fade: float = 1.0 - growth
	if fade <= 0.0:
		return
	var breathe: float = 0.5 + 0.5 * sin(_clock * 1.6 + float(_seed % 7))
	for bud: Dictionary in _buds:
		var u: float = 0.0 if int(bud["face"]) == 0 else gap_width
		var side: float = 1.0 if int(bud["face"]) == 0 else -1.0
		var v: float = 5.0 + (thickness - 8.0) * (float(bud["index"]) + 0.5) / float(BUDS)
		var color: Color = bud["color"]
		var base: Vector2 = _at(u, v)
		var reach: float = float(bud["reach"]) + 6.0 * glow
		var tip: Vector2 = base + Vector2(side * float(flow) * reach, 0.0)
		var alpha: float = (0.65 + 0.25 * breathe + 0.4 * glow) * fade
		draw_line(base, tip, Color(TONGUE_COLOR, alpha), 3.0)
		if glow > 0.05:
			draw_circle(tip, 7.0 + 6.0 * glow, Color(color, 0.22 * glow * fade))
		draw_circle(tip, 3.2 + 1.6 * glow, Color(color.lightened(0.25 * glow), alpha))


## The tongue of coral that has grown out of the lane into the opening, drawn on `layer`.
func _draw_tongue(layer: Node2D) -> void:
	var reach: float = _reach()
	var top: PackedVector2Array = PackedVector2Array()
	var bottom: PackedVector2Array = PackedVector2Array()
	var steps: int = 12
	for i: int in steps + 1:
		var u: float = -2.0 + (reach + 2.0) * float(i) / float(steps)
		var lump: float = 3.0 * sin(u * 0.21 + float(_seed % 5)) * growth
		top.append(_at(u, 0.0))
		bottom.append(_at(u, thickness + lump))
	bottom.reverse()
	var outline: PackedVector2Array = top + bottom
	layer.draw_colored_polygon(outline, TONGUE_COLOR)
	layer.draw_polyline(top, Color(TONGUE_EDGE, 0.85), 2.0, true)
	layer.draw_circle(_at(reach, thickness * 0.5), thickness * 0.5, TONGUE_COLOR)


## Flecks of light along the tongue, drawn on `layer`.
func _draw_flecks(layer: Node2D) -> void:
	var reach: float = _reach()
	for i: int in 5:
		var u: float = reach * (float(i) + 0.5) / 5.0
		var twinkle: float = 0.5 + 0.5 * sin(_clock * 3.0 + float(i) * 1.9)
		layer.draw_circle(
			_at(u, thickness * 0.45), 1.8, Color(1.0, 0.92, 0.75, 0.35 + 0.4 * twinkle)
		)


## Places the branches that hang from the tongue into the opening and sways them. A branch
## keeps its drawing once it has grown: only its angle changes.
func _pose_branches() -> void:
	var shown: bool = growth > 0.04
	var reach: float = _reach()
	for i: int in _roots.size():
		var root: Dictionary = _roots[i]
		var branch: CoralBranch = _branches[i]
		var own: float = clampf(growth * 1.5 - float(root["at"]) * 0.5, 0.0, 1.0)
		var u: float = maxf(reach * float(root["at"]) + 4.0, 0.0)
		var grown: bool = shown and own > 0.0 and u <= reach
		if branch.visible != grown:
			branch.visible = grown
		if not grown:
			continue
		branch.position = _at(u, thickness - 2.0)
		var sway: float = sin(_clock * 1.3 + float(root["phase"])) * 0.09
		branch.rotation = float(root["lean"]) + sway
		branch.grow_to(own)
