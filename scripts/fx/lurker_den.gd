class_name LurkerDen
extends Node2D
## The lurkers on a map: each one a dark shadow of their fish hiding in the scenery (see
## [LurkerSpots]) with their eyes ([LurkerEyes]) following the nearest fish. Purely visual,
## added to the track by the game and fed the lurkers from [signal Lurkers.lurkers_changed].

## How much bigger than a racing fish a shadow is.
const SHADOW_SCALE: float = 2.0
const SHADOW_TINT: Color = Color(0.03, 0.04, 0.07, 0.82)
## Radius of one eye.
const EYE_SIZE: float = 5.5
const KELP: Color = Color(0.06, 0.2, 0.12, 0.95)
## Fish further away than this are not worth looking at.
const LOOK_RANGE: float = 700.0
## How fast the eyes turn to a new target, per second.
const LOOK_SPEED: float = 6.0

## Returns the fish to look at, marble id -> global position (see [method Race.get_position_map]).
var fish_positions: Callable = func() -> Dictionary: return {}

var _map_id: String = ""
var _hideout: LurkerSpots.Hideout = LurkerSpots.Hideout.KELP
var _spots: Array[Vector2] = []
var _spots_found: bool = false
var _watchers: Array[Dictionary] = []
## One per shown lurker: {"spot", "eyes", "fish", "look", "wobble", "blink_in", "blink", "facing"}.
var _shown: Array[Dictionary] = []
var _front: Node2D
var _time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(map_id: String = "") -> void:
	_map_id = map_id
	_hideout = LurkerSpots.hideout_of(map_id)
	# Behind the course walls, in front of the backdrop and its decor.
	z_index = -1
	_rng.randomize()


func _ready() -> void:
	_front = Node2D.new()
	_front.z_index = 1
	_front.draw.connect(_draw_front)
	add_child(_front)


## The lurkers to show, from [method Lurkers.watchers].
func set_watchers(watchers: Array[Dictionary]) -> void:
	_watchers = watchers
	_rebuild()


## How many lurkers are on show right now.
func shown_count() -> int:
	return _shown.size()


func _physics_process(_delta: float) -> void:
	# The track's walls are in the physics space by the first physics frame. The search is
	# skipped until someone lurks.
	if _spots_found or _watchers.is_empty():
		return
	_spots_found = true
	var track: Track = get_parent() as Track
	if track != null:
		_spots = LurkerSpots.find(track, _map_id)
	_rebuild()
	set_physics_process(false)


func _rebuild() -> void:
	if not _spots_found:
		return
	for entry: Dictionary in _shown:
		(entry["fish"] as Node).queue_free()
	_shown.clear()
	for i: int in mini(_watchers.size(), _spots.size()):
		var watcher: Dictionary = _watchers[i]
		var fish := FishVisual.new()
		fish.species = int(watcher["species"])
		fish.color = Color(0.4, 0.45, 0.55)
		fish.frozen = true
		fish.modulate = SHADOW_TINT
		add_child(fish)
		move_child(fish, 0)
		# FishVisual draws itself on its own above the course; a shadow stays with the den.
		fish.top_level = false
		fish.z_index = 0
		fish.position = to_local(_spots[i])
		fish.scale = Vector2.ONE * SHADOW_SCALE
		(
			_shown
			. append(
				{
					"spot": _spots[i],
					"eyes": String(watcher["eyes"]),
					"fish": fish,
					"look": Vector2.ZERO,
					"wobble": Vector2.ZERO,
					"blink_in": _rng.randf_range(1.0, 5.0),
					"blink": 0.0,
					"facing": 1.0,
				}
			)
		)
	queue_redraw()
	_front.queue_redraw()


func _process(delta: float) -> void:
	# The fake 3D round hides the track, and the den with it.
	if _shown.is_empty() or not is_visible_in_tree():
		return
	_time += delta
	var positions: Dictionary = fish_positions.call()
	for entry: Dictionary in _shown:
		_update_entry(entry, positions, delta)
	_front.queue_redraw()


func _update_entry(entry: Dictionary, positions: Dictionary, delta: float) -> void:
	var spot: Vector2 = entry["spot"]
	var target: Vector2 = Vector2.ZERO
	var nearest: float = LOOK_RANGE
	for id: Variant in positions:
		var offset: Vector2 = (positions[id] as Vector2) - spot
		var distance: float = offset.length()
		if distance < nearest:
			nearest = distance
			target = offset.normalized() * clampf(distance / 120.0, 0.4, 1.0)
	if nearest >= LOOK_RANGE:
		# Nothing close: look around a little.
		target = Vector2(sin(_time * 0.7 + spot.x), cos(_time * 0.5 + spot.y) * 0.4) * 0.5
	var look: Vector2 = entry["look"]
	var was: Vector2 = look
	look = look.lerp(target, clampf(delta * LOOK_SPEED, 0.0, 1.0))
	entry["look"] = look
	# Googly pupils lag behind and wobble back.
	var wobble: Vector2 = entry["wobble"]
	wobble = (wobble - (look - was) * 3.0).lerp(Vector2.ZERO, clampf(delta * 4.0, 0.0, 1.0))
	entry["wobble"] = wobble.limit_length(0.5)
	# Turn the shadow to the side it looks at, with some slack so it does not flicker.
	var facing: float = entry["facing"]
	if look.x > 0.25:
		facing = 1.0
	elif look.x < -0.25:
		facing = -1.0
	entry["facing"] = facing
	var fish: FishVisual = entry["fish"]
	var bob: float = sin(_time * 1.3 + spot.x * 0.01) * 3.0
	fish.position = to_local(spot + Vector2(0.0, bob))
	fish.scale = Vector2(facing, 1.0) * SHADOW_SCALE
	var blink_in: float = float(entry["blink_in"]) - delta
	var blink: float = 0.0
	if blink_in < 0.0:
		blink = 1.0 - absf(blink_in / 0.08 + 1.0)
		if blink_in < -0.16:
			blink_in = _rng.randf_range(2.0, 6.0)
	entry["blink_in"] = blink_in
	entry["blink"] = clampf(blink, 0.0, 1.0)


## Where the eyes of [param entry] sit: on the shadow's head.
func _eye_point(entry: Dictionary) -> Vector2:
	var fish: FishVisual = entry["fish"]
	var sp: Dictionary = FishVisual.SPECIES[posmod(fish.species, FishVisual.SPECIES.size())]
	var eye: Vector2 = FishFeatures.eyes(sp, sp["look"])[0]
	var head := Vector2(eye.x * float(entry["facing"]), eye.y) * SHADOW_SCALE
	return fish.position + head


## Behind the shadows: the inside of the hideout.
func _draw() -> void:
	for entry: Dictionary in _shown:
		var at: Vector2 = to_local(entry["spot"])
		match _hideout:
			LurkerSpots.Hideout.PORTHOLE, LurkerSpots.Hideout.PIPE:
				draw_circle(at, 46.0, Color(0.02, 0.03, 0.05, 0.9))
			LurkerSpots.Hideout.GLASS:
				draw_rect(
					Rect2(at - Vector2(50, 36), Vector2(100, 72)), Color(0.02, 0.03, 0.06, 0.6)
				)
			LurkerSpots.Hideout.DARK:
				pass
			_:
				draw_circle(at, 40.0, Color(0.02, 0.03, 0.05, 0.35))


## In front of the shadows: the hideout's front and the eyes.
func _draw_front() -> void:
	for entry: Dictionary in _shown:
		var at: Vector2 = _front.to_local(entry["spot"])
		_draw_hideout_front(at)
		var eyes: Vector2 = _front.to_local(to_global(_eye_point(entry)))
		LurkerEyes.draw(
			_front, entry["eyes"], eyes, EYE_SIZE, entry["look"], entry["blink"], entry["wobble"]
		)
		if _hideout == LurkerSpots.Hideout.GLASS:
			_draw_glare(at)


func _draw_hideout_front(at: Vector2) -> void:
	match _hideout:
		LurkerSpots.Hideout.KELP:
			for i: int in 5:
				var x: float = at.x - 36.0 + 18.0 * float(i)
				var height: float = 40.0 + 14.0 * float((i * 7) % 3)
				var last := Vector2(x, at.y + 44.0)
				for k: int in range(1, 9):
					var t: float = float(k) / 8.0
					var sway: float = sin(_time * 1.4 + float(i) * 1.7 + t * 3.0) * 9.0 * t
					var next := Vector2(x + sway, at.y + 44.0 - t * height)
					_front.draw_line(last, next, KELP, lerpf(7.0, 1.5, t))
					last = next
		LurkerSpots.Hideout.PORTHOLE:
			_front.draw_arc(at, 46.0, 0.0, TAU, 40, Color(0.55, 0.42, 0.2), 9.0)
			for k: int in 8:
				var bolt: Vector2 = at + Vector2.from_angle(TAU * float(k) / 8.0) * 46.0
				_front.draw_circle(bolt, 2.5, Color(0.3, 0.22, 0.1))
		LurkerSpots.Hideout.PIPE:
			_front.draw_arc(at, 46.0, 0.0, TAU, 40, Color(0.45, 0.5, 0.55), 12.0)
			_front.draw_arc(at, 40.0, PI * 1.1, PI * 1.6, 12, Color(0.8, 0.85, 0.9, 0.6), 3.0)
		LurkerSpots.Hideout.CURTAIN:
			# A noren: cloth strips over the top half.
			for i: int in 3:
				var strip := Rect2(
					at + Vector2(-48.0 + 32.0 * float(i), -44.0), Vector2(30.0, 34.0)
				)
				_front.draw_rect(strip, Color(0.12, 0.2, 0.42))
			_front.draw_line(
				at + Vector2(-52, -44), at + Vector2(52, -44), Color(0.35, 0.2, 0.1), 5.0
			)
		LurkerSpots.Hideout.ROCK:
			var rock := PackedVector2Array(
				[
					at + Vector2(-50, 40),
					at + Vector2(-44, 14),
					at + Vector2(-18, 4),
					at + Vector2(10, 10),
					at + Vector2(38, 2),
					at + Vector2(52, 24),
					at + Vector2(54, 40),
				]
			)
			_front.draw_colored_polygon(rock, Color(0.09, 0.08, 0.1))
		LurkerSpots.Hideout.GLASS:
			_front.draw_rect(
				Rect2(at - Vector2(50, 36), Vector2(100, 72)),
				Color(0.6, 0.8, 1.0, 0.35),
				false,
				3.0
			)


## The shine of the glass a lurker is pressed against.
func _draw_glare(at: Vector2) -> void:
	_front.draw_line(at + Vector2(-38, 26), at + Vector2(-14, -26), Color(1, 1, 1, 0.25), 6.0)
	_front.draw_line(at + Vector2(-24, 28), at + Vector2(-8, -6), Color(1, 1, 1, 0.18), 3.0)
