class_name AquariumTank
extends Control
## The water and everyone swimming in it, in fake 3D: a 2D scene where each fish has a depth.
## Far fish are smaller, darker, bluer and follow the camera less, and they freeze their
## tail to save work. Only [constant MAX_FISH] swim at once; with more viewers than that the
## rest wait and take turns, one fish fading out as another fades in.

## Most fish swimming at once. The rest of a bigger roster wait their turn.
const MAX_FISH: int = 60
## Seconds between swaps while fish are waiting.
const ROTATE_SECONDS: float = 6.0
## The fish world is this many screens wide; the camera pans across it.
const WORLD_SCREENS: float = 2.2
const CAMERA_DRIFT: float = 0.3
const MOUSE_PAN: float = 0.12
## Fish size at the glass and at the back.
const NEAR_SCALE: float = 2.6
const FAR_SCALE: float = 0.8
## How much less a fish at the back follows the camera than one at the glass.
const FAR_PARALLAX: float = 0.3
## Fish at the back and beyond this z are tinted by this much of the water color.
const FOG_AMOUNT: float = 0.7
const FOG_TINT: Color = Color(0.12, 0.4, 0.55)
## Fish freeze their tail beyond [constant FREEZE_Z] (off screen too), and wake below
## [constant WAKE_Z], so one sitting on the line does not flicker.
const FREEZE_Z: float = 0.7
const WAKE_Z: float = 0.6
## Names are drawn on fish nearer than this.
const NAME_Z: float = 0.35
const NAME_SIZE: int = 15
const HOVER_SIZE: int = 26
const HOVER_RADIUS: float = 34.0
const OFFSCREEN_MARGIN: float = 120.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _fish: Array[AquariumFish] = []
var _waiting: Array[Contestant] = []
var _swap_left: float = ROTATE_SECONDS
var _time: float = 0.0
var _cam_x: float = 0.0
var _mouse_pan: float = 0.0
var _hovered: AquariumFish
var _back: AquariumBackdrop
var _light: AquariumBackdrop
var _front: AquariumBackdrop
var _labels: Node2D
var _font: Font
var _total: int = 0


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value if seed_value != 0 else randi()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	_font = UiStyle.font(700, 1)
	_back = _add_backdrop(AquariumBackdrop.Layer.BACK, -100)
	_light = _add_backdrop(AquariumBackdrop.Layer.LIGHT, -99)
	_add_bubbles()
	_front = _add_backdrop(AquariumBackdrop.Layer.FRONT, 200)
	_labels = Node2D.new()
	_labels.z_index = 300
	_labels.draw.connect(_draw_labels)
	add_child(_labels)
	resized.connect(_on_resized)
	_on_resized()


## Puts [param roster] in the water: the first [constant MAX_FISH] (shuffled) swim and the
## rest wait their turn.
func set_roster(roster: Array[Contestant]) -> void:
	for fish: AquariumFish in _fish:
		fish.queue_free()
	_fish.clear()
	_waiting.clear()
	_hovered = null
	_total = roster.size()
	var order: Array[Contestant] = roster.duplicate()
	_shuffle(order)
	for who: Contestant in order:
		if _fish.size() < MAX_FISH:
			_spawn(who)
		else:
			_waiting.append(who)


## How many fish exist (swimming or waiting).
func fish_total() -> int:
	return _total


## The fish swimming right now.
func swimmers() -> Array[AquariumFish]:
	return _fish


## The fish waiting for a turn.
func waiting() -> Array[Contestant]:
	return _waiting


## Screen position and scale of a fish: [member AquariumFish.z] shrinks it, pulls it toward
## the middle of the water and slows its parallax. Returns {"position", "scale"}.
func project(fish: AquariumFish) -> Dictionary:
	var world_width: float = world_width_px()
	var parallax: float = lerpf(1.0, FAR_PARALLAX, fish.z)
	var x: float = (
		fposmod(fish.world_x * world_width - _cam_x * parallax + OFFSCREEN_MARGIN, world_width)
		- OFFSCREEN_MARGIN
	)
	var y: float = size.y * lerpf(fish.depth_y, 0.5, fish.z * 0.35)
	return {"position": Vector2(x, y), "scale": lerpf(NEAR_SCALE, FAR_SCALE, fish.z)}


func world_width_px() -> float:
	return maxf(size.x, 1.0) * WORLD_SCREENS


func _process(delta: float) -> void:
	_time += delta
	var mouse: Vector2 = get_local_mouse_position()
	var mouse_target: float = 0.0
	if Rect2(Vector2.ZERO, size).has_point(mouse):
		mouse_target = (mouse.x / maxf(size.x, 1.0) - 0.5) * size.x * MOUSE_PAN * 2.0
	_mouse_pan = lerpf(_mouse_pan, mouse_target, clampf(delta * 2.0, 0.0, 1.0))
	_cam_x = sin(_time * 0.05) * size.x * CAMERA_DRIFT * 0.5 + _mouse_pan
	_rotate_crowd(delta)
	var nearest: AquariumFish = null
	var nearest_dist: float = INF
	for fish: AquariumFish in _fish:
		_update_fish(fish, delta)
		if fish.fading_out or not fish.visible:
			continue
		var dist: float = fish.position.distance_to(mouse)
		if dist < HOVER_RADIUS * fish.visual.scale.x and dist < nearest_dist:
			nearest = fish
			nearest_dist = dist
	_hovered = nearest
	for backdrop: AquariumBackdrop in [_back, _light, _front]:
		backdrop.cam_x = _cam_x
		backdrop.time = _time
		if backdrop != _front:
			backdrop.queue_redraw()
	_labels.queue_redraw()


func _update_fish(fish: AquariumFish, delta: float) -> void:
	var velocity: Vector2 = fish.step(delta, world_width_px())
	var placed: Dictionary = project(fish)
	var at: Vector2 = placed["position"]
	var depth_scale: float = placed["scale"]
	fish.position = at
	fish.visible = (
		fish.fade > 0.0 and at.x > -OFFSCREEN_MARGIN and at.x < size.x + OFFSCREEN_MARGIN
	)
	var visual: FishVisual = fish.visual
	var want_frozen: bool = not fish.visible or fish.z > (WAKE_Z if visual.frozen else FREEZE_Z)
	if want_frozen != visual.frozen:
		visual.frozen = want_frozen
	if not fish.visible:
		fish.update_trail(false, depth_scale)
		return
	visual.face(velocity, delta)
	visual.scale *= depth_scale
	visual.z_index = 10 + int((1.0 - fish.z) * 100.0)
	var fog: float = fish.z * FOG_AMOUNT
	var tint: Color = Color.WHITE.lerp(FOG_TINT, fog)
	visual.modulate = Color(tint.r, tint.g, tint.b, fish.fade * lerpf(1.0, 0.75, fish.z))
	fish.update_trail(not visual.frozen and not fish.fading_out, depth_scale)


## While fish wait, swaps one swimmer out every [constant ROTATE_SECONDS]: it fades, and
## its place goes to the fish that has waited longest.
func _rotate_crowd(delta: float) -> void:
	for i: int in range(_fish.size() - 1, -1, -1):
		var fish: AquariumFish = _fish[i]
		if not fish.is_gone():
			continue
		_waiting.append(fish.contestant)
		var next: Contestant = _waiting.pop_front()
		fish.assign(next)
	if _waiting.is_empty():
		return
	_swap_left -= delta
	if _swap_left > 0.0:
		return
	_swap_left = ROTATE_SECONDS
	var settled: Array[AquariumFish] = []
	for fish: AquariumFish in _fish:
		if not fish.fading_out and fish.fade >= 1.0:
			settled.append(fish)
	if not settled.is_empty():
		settled[_rng.randi_range(0, settled.size() - 1)].fading_out = true


func _spawn(who: Contestant) -> void:
	var fish := AquariumFish.new(_rng)
	add_child(fish)
	fish.assign(who)
	_fish.append(fish)


func _shuffle(list: Array[Contestant]) -> void:
	for i: int in range(list.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: Contestant = list[i]
		list[i] = list[j]
		list[j] = swap


func _add_backdrop(layer: AquariumBackdrop.Layer, z: int) -> AquariumBackdrop:
	var backdrop := AquariumBackdrop.new()
	backdrop.layer = layer
	backdrop.z_index = z
	add_child(backdrop)
	return backdrop


## Bubbles rising from the seabed, added to the light so they glow.
func _add_bubbles() -> void:
	var bubbles := CPUParticles2D.new()
	bubbles.name = "Bubbles"
	bubbles.texture = RaceFx.glow_texture()
	bubbles.material = RaceFx.additive_material()
	bubbles.amount = 28
	bubbles.lifetime = 9.0
	bubbles.preprocess = 9.0
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bubbles.gravity = Vector2(0.0, -34.0)
	bubbles.initial_velocity_min = 4.0
	bubbles.initial_velocity_max = 12.0
	bubbles.direction = Vector2.UP
	bubbles.spread = 25.0
	bubbles.scale_amount_min = 0.05
	bubbles.scale_amount_max = 0.16
	bubbles.color = Color(0.6, 0.92, 1.0, 0.35)
	bubbles.z_index = -98
	add_child(bubbles)


func _on_resized() -> void:
	for backdrop: AquariumBackdrop in [_back, _light, _front]:
		backdrop.view = size
		backdrop.queue_redraw()
	var bubbles: CPUParticles2D = get_node_or_null("Bubbles")
	if bubbles != null:
		bubbles.position = Vector2(size.x * 0.5, size.y)
		bubbles.emission_rect_extents = Vector2(size.x * 0.5, 4.0)


func _draw_labels() -> void:
	for fish: AquariumFish in _fish:
		if fish.visible and fish.z < NAME_Z and fish != _hovered:
			var alpha: float = fish.fade * (1.0 - fish.z / NAME_Z) * 0.85
			_draw_text(
				fish.contestant.display_name,
				fish.position + Vector2(0.0, -34.0 * fish.visual.scale.x),
				NAME_SIZE,
				Color(UiStyle.TEXT, alpha)
			)
	if _hovered != null:
		var at: Vector2 = _hovered.position + Vector2(0.0, -42.0 * _hovered.visual.scale.x)
		_draw_text(_hovered.contestant.display_name, at, HOVER_SIZE, UiStyle.TEXT)
		_draw_text(
			AquariumRoster.describe(_hovered.contestant),
			at + Vector2(0.0, 22.0),
			NAME_SIZE + 2,
			UiStyle.CYAN_LIGHT
		)


func _draw_text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var origin: Vector2 = center - Vector2(width * 0.5, 0.0)
	_labels.draw_string_outline(
		_font,
		origin,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		6,
		Color(0.0, 0.03, 0.08, color.a)
	)
	_labels.draw_string(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
