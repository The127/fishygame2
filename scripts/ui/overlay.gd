class_name Overlay
extends CanvasLayer
## Viewer-facing text: lobby list, countdown number, bets, notices, podium and payouts.
## Built from Controls on a CanvasLayer, so it draws the same over a 2D or a 3D race.
## Laid out for a 1920x1080 viewport; the podium and payouts share one column so they
## can never overlap.

const MARGIN: int = 48
const LOBBY_COLUMNS: int = 2

var _lobby_panel: PanelContainer
var _lobby_header: Label
var _lobby_status: Label
var _lobby_names: GridContainer
var _lobby_key: String = ""
var _big: Label
var _results_column: VBoxContainer
var _podium_panel: PanelContainer
var _podium_view: PodiumView
var _payouts_panel: PanelContainer
var _payouts_box: VBoxContainer
var _bets_panel: PanelContainer
var _bets: Label
var _notice_panel: PanelContainer
var _notice: Label
var _notice_timer: Timer


func _ready() -> void:
	_build_lobby()
	_build_countdown()
	_build_results()
	_build_bets()
	_build_notice()
	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.timeout.connect(_clear_notice)
	add_child(_notice_timer)
	clear()


func clear() -> void:
	_clear_lobby()
	_big.text = ""
	_podium_panel.visible = false
	_payouts_panel.visible = false
	_set_bets_text("")


func show_idle() -> void:
	clear()


func show_lobby(names: PackedStringArray, max_players: int, seconds_left: float) -> void:
	_big.text = ""
	_podium_panel.visible = false
	_payouts_panel.visible = false
	var header: String = "TYPE #JOIN TO RACE"
	var status: String = "%d/%d PLAYERS" % [names.size(), max_players]
	if seconds_left > 0.0:
		status += "   STARTS IN %d s" % ceili(seconds_left)
	# Called every frame while the lobby is open, so only rebuild when something changed.
	var key: String = header + status + "\n" + "\n".join(names)
	if key == _lobby_key and _lobby_panel.visible:
		return
	_lobby_key = key
	_lobby_header.text = header
	_lobby_status.text = status
	for child: Node in _lobby_names.get_children():
		_lobby_names.remove_child(child)
		child.queue_free()
	for player: String in names:
		_lobby_names.add_child(_make_label(player, 26, 600, UiStyle.TEXT))
	_lobby_names.visible = not names.is_empty()
	_lobby_panel.visible = true


func show_countdown(seconds_left: int) -> void:
	_clear_lobby()
	_big.text = str(seconds_left)


func show_racing() -> void:
	clear()


func show_podium(podium: Array[Dictionary]) -> void:
	clear()
	_podium_view.set_podium(podium)
	_podium_panel.visible = not podium.is_empty()


func show_bets(text: String) -> void:
	_set_bets_text(text)


## Lines of "name won 500 (bet on Alice)" / "name lost 100"; only the first few are shown.
func show_payouts(results: Array[Dictionary], max_lines: int = 8) -> void:
	for child: Node in _payouts_box.get_children():
		_payouts_box.remove_child(child)
		child.queue_free()
	var shown: int = 0
	for entry: Dictionary in results:
		if shown >= max_lines:
			break
		shown += 1
		if int(entry["payout"]) > 0:
			_payouts_box.add_child(
				_make_label(
					"%s won %d points" % [entry["name"], entry["payout"]], 28, 700, UiStyle.GOOD
				)
			)
		else:
			_payouts_box.add_child(
				_make_label(
					"%s lost %d points" % [entry["name"], entry["amount"]], 28, 600, UiStyle.BAD
				)
			)
	_payouts_panel.visible = shown > 0


## Short message near the top that clears itself.
func show_notice(text: String, seconds: float = 4.0) -> void:
	_notice.text = text
	_notice_panel.visible = text != ""
	_notice_timer.start(seconds)


func _clear_notice() -> void:
	_notice.text = ""
	_notice_panel.visible = false


func _clear_lobby() -> void:
	_lobby_key = ""
	_lobby_panel.visible = false


func _set_bets_text(text: String) -> void:
	_bets.text = text
	_bets_panel.visible = text != ""


func _build_lobby() -> void:
	_lobby_panel = _make_panel()
	_lobby_panel.position = Vector2(MARGIN, MARGIN)
	add_child(_lobby_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_lobby_panel.add_child(box)
	_lobby_header = _make_label("", 30, 800, UiStyle.CYAN, 3)
	box.add_child(_lobby_header)
	_lobby_status = _make_label("", 22, 700, UiStyle.MUTED, 2)
	box.add_child(_lobby_status)
	_lobby_names = GridContainer.new()
	_lobby_names.columns = LOBBY_COLUMNS
	_lobby_names.add_theme_constant_override("h_separation", 40)
	_lobby_names.add_theme_constant_override("v_separation", 2)
	box.add_child(_lobby_names)


func _build_countdown() -> void:
	_big = _make_label("", 260, 900, Color.WHITE)
	_big.material = UiStyle.gradient_material()
	_big.add_theme_color_override("font_shadow_color", Color(UiStyle.CYAN, 0.25))
	_big.add_theme_constant_override("shadow_outline_size", 18)
	add_child(_big)
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_results() -> void:
	_results_column = VBoxContainer.new()
	_results_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_column.add_theme_constant_override("separation", 24)
	_results_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_results_column)
	# Top-centered column, 1920 wide; the panels inside size to their content.
	_results_column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_results_column.offset_top = 96.0
	_podium_panel = _make_panel(false)
	_podium_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var podium_box := VBoxContainer.new()
	podium_box.add_theme_constant_override("separation", 12)
	_podium_panel.add_child(podium_box)
	var title: Label = _make_label("PODIUM", 56, 900, Color.WHITE, 8)
	title.material = UiStyle.gradient_material()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	podium_box.add_child(title)
	_podium_view = PodiumView.new()
	podium_box.add_child(_podium_view)
	_results_column.add_child(_podium_panel)
	_payouts_panel = _make_panel(false)
	_payouts_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_payouts_box = VBoxContainer.new()
	_payouts_box.add_theme_constant_override("separation", 2)
	_payouts_panel.add_child(_payouts_box)
	_results_column.add_child(_payouts_panel)


func _build_bets() -> void:
	_bets_panel = _make_panel()
	_bets = _make_label("", 28, 600, UiStyle.TEXT)
	_bets_panel.add_child(_bets)
	add_child(_bets_panel)
	# Bottom-left, growing upward when the text gets longer.
	_bets_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_bets_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bets_panel.offset_left = MARGIN
	_bets_panel.offset_bottom = -MARGIN


func _build_notice() -> void:
	_notice_panel = _make_panel()
	_notice_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_notice = _make_label("", 32, 700, UiStyle.TEXT)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_panel.add_child(_notice)
	_notice_panel.visible = false
	# A full-width strip at the top whose only child is centered, so the pill hugs its text.
	var strip := HBoxContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	strip.offset_top = 24.0
	add_child(strip)
	strip.add_child(_notice_panel)


func _make_panel(start_visible: bool = true) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = start_visible
	return panel


func _make_label(text: String, size: int, weight: int, color: Color, spacing: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.style_label(label, size, weight, color, spacing)
	return label
