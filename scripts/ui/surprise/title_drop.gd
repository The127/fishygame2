class_name TitleDrop
extends SubViewportContainer
## Transparent 3D layer over the home screen title for the fake sequel joke: the "II" of
## the title turns into a 3D letter, a red 3 falls on it and squishes it flat, then a D
## lands next to the 3, making "3D". The letters are physics bodies in their own world,
## seen by an orthographic camera matched to the title label so they line up with it.
## Later a violet 4 can fall on the 3 the same way, making "4D".

signal finished
## The 4 squished the 3 and came to rest.
signal four_finished

## World units per screen pixel of title text at the size the drop started with.
const PIXEL_SIZE: float = 0.01
const DEPTH: float = 0.32
const RED: Color = Color(0.93, 0.12, 0.16)
const VIOLET: Color = Color(0.62, 0.22, 1.0)
## Height above the top of the screen the letters fall from, in world units.
const DROP_HEIGHT: float = 0.8
## Seconds between the 3 landing and the D dropping.
const D_DELAY: float = 0.7
## Longest wait for the 3 to land before the D drops anyway, in seconds.
const LANDING_TIMEOUT: float = 4.0
## Seconds after the D drops before [signal finished] fires.
const SETTLE_SECONDS: float = 1.6
## Gap between the 3 and the D, as a fraction of the font size.
const LETTER_GAP: float = 0.08
## Turn of the 3D letters, so their extruded sides show.
const YAW: float = deg_to_rad(-16.0)

var viewport: SubViewport
var camera: Camera3D
## The title's "II", the 3 and the D, once they exist.
var two: SquishyLetter
var three: SquishyLetter
var d: SquishyLetter
var four: SquishyLetter

var _world: Node3D
var _font: Font
var _font_size: int = 96
var _start_rect: Rect2
var _rect: Rect2
var _two_color: Color = Color.WHITE
var _letter_material: StandardMaterial3D
var _waiting_for_three: bool = false
var _three_landed: bool = false


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.handle_input_locally = false
	viewport.physics_object_picking = false
	add_child(viewport)
	_world = Node3D.new()
	viewport.add_child(_world)
	_world.add_child(_make_environment())
	_world.add_child(_make_light())
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.05
	camera.far = 50.0
	_world.add_child(camera)
	_letter_material = StandardMaterial3D.new()
	_letter_material.albedo_color = RED
	_letter_material.roughness = 0.35
	_letter_material.emission_enabled = true
	_letter_material.emission = RED * 0.25
	resized.connect(_reframe)


func _physics_process(_delta: float) -> void:
	if _waiting_for_three and three.bottom_y() <= two.top_y():
		_waiting_for_three = false
		two.flatten()
		two.collision_layer = 1
		Sound.play(Sound.Sfx.BLAST_HIT)
	elif not _three_landed and three != null and not _waiting_for_three:
		if three.linear_velocity.y > -0.05 and three.bottom_y() < two.top_y() + 0.3:
			_three_landed = true


## Builds the letters over [param rect], the screen rectangle of the title's "II" (its line
## box, as [method Label.get_character_bounds] reports it). [param color] is the title color
## there. With [param animate] the 3 and D fall in; otherwise they start where they come to rest.
func setup(rect: Rect2, font: Font, font_size: int, color: Color, animate: bool) -> void:
	_start_rect = rect
	_rect = rect
	_font = font
	_font_size = font_size
	_two_color = color
	_reframe()
	_add_floor()
	two = _make_two()
	if animate:
		_play()
	else:
		_settle_at_once()


## Moves the camera so the letters follow the title to [param rect] (its "II" box) after the
## window or title font size changed.
func frame(rect: Rect2) -> void:
	_rect = rect
	_reframe()


## Screen pixels per world unit right now.
func pixels_per_unit() -> float:
	var scale: float = _rect.size.y / maxf(_start_rect.size.y, 1.0)
	return scale / PIXEL_SIZE


## World y of the title's baseline.
func baseline_y() -> float:
	return -_font.get_ascent(_font_size) * PIXEL_SIZE


func _play() -> void:
	three = _make_letter("3", Vector2(0.0, _drop_y()))
	_waiting_for_three = true
	var deadline: int = Time.get_ticks_msec() + roundi(LANDING_TIMEOUT * 1000.0)
	while not _three_landed and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if not is_inside_tree():
			return
	await get_tree().create_timer(D_DELAY).timeout
	d = _make_letter("D", Vector2(_d_x(), _drop_y()))
	await get_tree().create_timer(SETTLE_SECONDS).timeout
	finished.emit()


## Drops a violet 4 on the 3 and squishes it flat, like the 3 did to the "II". Emits
## [signal four_finished] once the 4 has settled.
func drop_four() -> void:
	var material := _letter_material.duplicate() as StandardMaterial3D
	material.albedo_color = VIOLET
	material.emission = VIOLET * 0.3
	four = SquishyLetter.new("4", _font, _font_size, PIXEL_SIZE, DEPTH, material)
	four.name = "4"
	four.position = Vector3(three.position.x, _drop_y(), 0.0)
	four.set_yaw(YAW)
	# Falls through everything until it reaches the 3; it collides once the 3 is squished.
	four.collision_layer = 0
	four.collision_mask = 0
	_world.add_child(four)
	var deadline: int = Time.get_ticks_msec() + roundi(LANDING_TIMEOUT * 1000.0)
	while four.bottom_y() > three.top_y() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if not is_inside_tree():
			return
	three.flatten()
	four.collision_layer = 1
	four.collision_mask = 1
	Sound.play(Sound.Sfx.BLAST_HIT)
	await get_tree().create_timer(SETTLE_SECONDS).timeout
	if is_inside_tree():
		four_finished.emit()


func _settle_at_once() -> void:
	two.set_flat()
	two.collision_layer = 1
	three = _make_letter("3", Vector2.ZERO)
	# Sits on the squished "II": its ink bottom goes to the pancake's top.
	three.position.y = two.top_y() - three.ink().position.y + 0.01
	d = _make_letter("D", Vector2(_d_x(), 0.0))
	d.position.y = baseline_y() - d.ink().position.y + 0.01
	_three_landed = true


func _d_x() -> float:
	return three.position.x + three.ink().end.x + _font_size * PIXEL_SIZE * LETTER_GAP


func _make_two() -> SquishyLetter:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _two_color
	var letter := SquishyLetter.new("II", _font, _font_size, PIXEL_SIZE, DEPTH, material)
	letter.name = "Two"
	letter.freeze = true
	letter.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	# The 3 must reach the "II" before anything stops it; the collider comes with the squish.
	letter.collision_layer = 0
	_world.add_child(letter)
	return letter


func _make_letter(text: String, at: Vector2) -> SquishyLetter:
	var letter := SquishyLetter.new(text, _font, _font_size, PIXEL_SIZE, DEPTH, _letter_material)
	letter.name = text
	letter.position = Vector3(at.x, at.y, 0.0)
	letter.set_yaw(YAW)
	_world.add_child(letter)
	return letter


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 1.0, 4.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, baseline_y() - 0.5, 0.0)
	_world.add_child(floor_body)


## World y the letters fall from: above the top edge of the screen, and always a good bit
## above the title, even when the title sits near the top.
func _drop_y() -> float:
	var top: float = camera.position.y + camera.size * 0.5
	return maxf(top, _font_size * PIXEL_SIZE * 2.0) + DROP_HEIGHT


## Places the orthographic camera so the world origin (the top-left of the "II" box when
## the drop started) shows at the top-left of the current "II" box, at the current scale.
func _reframe() -> void:
	# Added this frame, the container may not have its size yet; it will fill its parent.
	var view: Vector2 = size if size.y > 0.0 else get_parent_area_size()
	if camera == null or view.y <= 0.0 or _start_rect.size.y <= 0.0:
		return
	var ppu: float = pixels_per_unit()
	camera.size = view.y / ppu
	camera.position = Vector3(
		-(_rect.position.x - view.x * 0.5) / ppu, (_rect.position.y - view.y * 0.5) / ppu, 10.0
	)


func _make_environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.6
	var holder := WorldEnvironment.new()
	holder.environment = env
	return holder


func _make_light() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -40.0, 0.0)
	light.light_energy = 1.3
	return light
