class_name AquariumScreen
extends Control
## Every fish that exists, swimming in an aquarium. Opened from the home screen.

const HOME_SCENE: String = "res://scenes/ui/home_screen.tscn"

## Fish to show; built from the saved data when left null (tests set it first).
var roster: Array[Contestant] = []
var _tank: AquariumTank
var _count: Label
var _empty: Label


func _ready() -> void:
	Sound.set_music_theme(Sound.HOME_THEME)
	if roster.is_empty():
		roster = _load_roster()
	_tank = AquariumTank.new()
	_tank.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_tank)
	_tank.set_roster(roster)
	_build_ui()


func _load_roster() -> Array[Contestant]:
	var points := PointsStore.new(PointsStore.DEFAULT_PATH)
	points.load_from_disk()
	var shop := ShopStore.new(Shop.DEFAULT_PATH)
	shop.load_from_disk()
	var settings := GameSettings.new(GameSettings.DEFAULT_PATH)
	settings.load_settings()
	return AquariumRoster.build(points, shop, settings.colorblind)


func _build_ui() -> void:
	var back := Button.new()
	back.name = "Back"
	back.text = "BACK"
	back.position = Vector2(24.0, 24.0)
	back.pressed.connect(_on_back_pressed)
	UiStyle.style_button(back, 22)
	add_child(back)
	_count = Label.new()
	_count.name = "Count"
	_count.text = "%d fish" % roster.size()
	_count.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_count.position = Vector2(-160.0, 28.0)
	_count.custom_minimum_size = Vector2(136.0, 0.0)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.style_label(_count, 22, 700, UiStyle.MUTED)
	add_child(_count)
	_empty = Label.new()
	_empty.name = "Empty"
	_empty.text = "No fish yet. Viewers who join a lobby or shop show up here."
	_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.visible = roster.is_empty()
	UiStyle.style_label(_empty, 28, 600, UiStyle.MUTED)
	add_child(_empty)
	back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)
