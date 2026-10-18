class_name ParticipationTrophy
extends CanvasLayer
## Panel right of the podium for the occasional participation trophy. Feed it
## GameFlow.participation_trophy and GameFlow.state_changed; it hides when the podium ends.

## The participation prize is this many times the 1st place reward.
const PRIZE_FACTOR: int = 3
## Narrower than the Overlay margin so the panel clears the centered podium at 1920 wide.
const MARGIN: float = 32.0
## Same top as the podium column of [Overlay].
const TOP: float = 96.0

var _frame: Control
var _panel: PanelContainer
var _view: ParticipationTrophyView


# Built in _init: the game may set the play fraction before this enters the tree.
func _init() -> void:
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_frame.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -MARGIN
	_panel.offset_top = TOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "PARTICIPATION\nTROPHY"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(title, 32, 900, Color.WHITE, 4)
	title.material = UiStyle.gradient_material()
	box.add_child(title)
	_view = ParticipationTrophyView.new()
	box.add_child(_view)


## Keeps the panel inside `fraction` of the screen, like [method Overlay.set_play_fraction].
func set_play_fraction(fraction: Rect2) -> void:
	_frame.anchor_left = fraction.position.x
	_frame.anchor_top = fraction.position.y
	_frame.anchor_right = fraction.end.x
	_frame.anchor_bottom = fraction.end.y
	_frame.offset_left = 0.0
	_frame.offset_top = 0.0
	_frame.offset_right = 0.0
	_frame.offset_bottom = 0.0


## `entry` is a podium entry (name, place, color and the fish look).
func show_trophy(entry: Dictionary) -> void:
	_view.show_entry(entry)
	_panel.visible = true


func on_state_changed(new_state: GameFlow.State, _old_state: GameFlow.State) -> void:
	if new_state != GameFlow.State.PODIUM:
		_panel.visible = false
		_view.stop()


func is_showing() -> bool:
	return _panel.visible
