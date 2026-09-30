class_name Overlay
extends CanvasLayer
## Viewer-facing text: lobby list, countdown number, bets, notices, podium and payouts.
## Built from Controls on a CanvasLayer, so it draws the same over a 2D or a 3D race.
## Laid out for a 1920x1080 viewport; the podium and payouts share one column so they
## can never overlap.

const MARGIN: int = 48
## Most DNF names listed under the podium.
const DNF_SHOWN: int = 8
const LOBBY_COLUMNS: int = 2

var _mask: BlockedMask
var _frame: Control
var _lobby_panel: PanelContainer
var _lobby_header: Label
var _lobby_status: Label
var _lobby_names: GridContainer
var _lobby_key: String = ""
var _board_panel: PanelContainer
var _board: LeaderboardPanel
var _board_has_rows: bool = false
var _help_panel: PanelContainer
var _big: Label
var _results_column: VBoxContainer
var _podium_panel: PanelContainer
var _podium_view: PodiumView
var _dnf_panel: PanelContainer
var _dnf_label: Label
var _timer_panel: PanelContainer
var _timer_label: Label
var _timer_shown: int = -1
var _payouts_panel: PanelContainer
var _payouts_box: VBoxContainer
var _bets_panel: PanelContainer
var _bets: Label
var _notice_panel: PanelContainer
var _notice: Label
var _notice_timer: Timer
var _replay_badge: PanelContainer
var _fader: ColorRect
var _fade_tween: Tween
var _badge_tween: Tween
var _wheel_panel: PanelContainer
var _wheel: WheelView
var _wheel_result: Label
var _event_panel: PanelContainer
var _event_label: Label


func _ready() -> void:
	_mask = BlockedMask.new()
	add_child(_mask)
	# Everything is laid out inside this frame, which streamer padding shrinks.
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	_build_lobby()
	_build_board()
	_build_help()
	_build_countdown()
	_build_results()
	_build_bets()
	_build_notice()
	_build_replay_badge()
	_build_timer()
	_build_event()
	_build_fader()
	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.timeout.connect(_clear_notice)
	add_child(_notice_timer)
	clear()


## Keeps the UI inside `fraction` of the screen (fractions of the viewport).
func set_play_fraction(fraction: Rect2) -> void:
	_mask.set_play_fraction(fraction)
	_frame.anchor_left = fraction.position.x
	_frame.anchor_top = fraction.position.y
	_frame.anchor_right = fraction.end.x
	_frame.anchor_bottom = fraction.end.y
	_frame.offset_left = 0.0
	_frame.offset_top = 0.0
	_frame.offset_right = 0.0
	_frame.offset_bottom = 0.0


func clear() -> void:
	_replay_badge.visible = false
	_kill_fade()
	_fader.modulate.a = 0.0
	_clear_lobby()
	_big.text = ""
	_podium_panel.visible = false
	_dnf_panel.visible = false
	_timer_panel.visible = false
	_timer_shown = -1
	_payouts_panel.visible = false
	_set_bets_text("")
	hide_event_wheel()
	show_event_badge("")


func show_idle() -> void:
	clear()


## All-time board shown next to the lobby (see PointsStore.top_by_points and top_by_wins).
func set_leaderboard(points_rows: Array[Dictionary], wins_rows: Array[Dictionary]) -> void:
	_board_has_rows = _board.set_rows(points_rows, wins_rows)
	if _lobby_panel.visible:
		_board_panel.visible = _board_has_rows


## [param players] holds one dictionary per joined player: "name", plus the "color",
## "species", "pattern" and "accessory" of the fish they will race with.
func show_lobby(players: Array[Dictionary], max_players: int, seconds_left: float) -> void:
	_big.text = ""
	_podium_panel.visible = false
	_payouts_panel.visible = false
	var header: String = "TYPE #JOIN TO RACE"
	var status: String = "%d/%d PLAYERS" % [players.size(), max_players]
	if seconds_left > 0.0:
		status += "   STARTS IN %d s" % ceili(seconds_left)
	# Called every frame while the lobby is open, so only rebuild when something changed.
	var key: String = header + status
	for player: Dictionary in players:
		key += (
			"\n%s|%s|%s|%s|%s"
			% [
				player["name"],
				player["color"].to_html(),
				player["species"],
				player["pattern"],
				player["accessory"],
			]
		)
	if key == _lobby_key and _lobby_panel.visible:
		return
	_lobby_key = key
	_lobby_header.text = header
	_lobby_status.text = status
	for child: Node in _lobby_names.get_children():
		_lobby_names.remove_child(child)
		child.queue_free()
	for player: Dictionary in players:
		_lobby_names.add_child(_make_lobby_row(player))
	_lobby_names.visible = not players.is_empty()
	_lobby_panel.visible = true
	_board_panel.visible = _board_has_rows
	_help_panel.visible = true


func show_countdown(seconds_left: int) -> void:
	_clear_lobby()
	_big.text = str(seconds_left)


## Spins the random-event wheel so slice `index` of `slices` ends under the pointer after
## `seconds`. `result` is what the label under the wheel shows once it stops.
func show_event_wheel(slices: Array[String], index: int, seconds: float, result: String) -> void:
	_wheel_result.text = ""
	_wheel.spin(slices, index, seconds)
	_wheel_panel.visible = true
	get_tree().create_timer(seconds).timeout.connect(_show_wheel_result.bind(result))


func hide_event_wheel() -> void:
	_wheel_panel.visible = false


## Persistent tag for the race's event, e.g. "LOW GRAVITY: Fish sink slowly". Empty hides it.
func show_event_badge(text: String) -> void:
	_event_label.text = text
	_event_panel.visible = text != ""


func show_racing() -> void:
	clear()


func show_podium(podium: Array[Dictionary]) -> void:
	clear()
	_podium_view.set_podium(podium)
	_podium_panel.visible = not podium.is_empty()


## Shows the seconds left before the race time limit, or hides the timer for a negative value.
func show_race_timer(seconds_left: int) -> void:
	if seconds_left == _timer_shown:
		return
	_timer_shown = seconds_left
	_timer_panel.visible = seconds_left >= 0
	if seconds_left < 0:
		return
	_timer_label.text = "0:%02d" % seconds_left
	_timer_label.add_theme_color_override(
		"font_color", UiStyle.TEXT if seconds_left > 5 else Color(1.0, 0.45, 0.4)
	)


## Lists the fish that did not finish under the podium; hidden when there are none.
func show_dnf(names: PackedStringArray) -> void:
	_dnf_panel.visible = not names.is_empty()
	if names.is_empty():
		return
	var shown: PackedStringArray = names.slice(0, DNF_SHOWN)
	var text: String = "DNF: " + ", ".join(shown)
	if names.size() > DNF_SHOWN:
		text += " +%d more" % (names.size() - DNF_SHOWN)
	_dnf_label.text = text


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
		# A wrong free pick costs nothing, so only the winning ones are listed.
		if entry.get("kind", "bet") == "pick" and int(entry["payout"]) <= 0:
			continue
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


## The REPLAY badge while a finish replay plays. It slides in and pops when shown.
func show_replay(shown: bool) -> void:
	if _badge_tween != null:
		_badge_tween.kill()
	_replay_badge.visible = shown
	if not shown:
		return
	var badge_size: Vector2 = _replay_badge.get_combined_minimum_size()
	_replay_badge.pivot_offset = badge_size * 0.5
	_replay_badge.position = Vector2(-badge_size.x - 40.0, float(MARGIN))
	_replay_badge.scale = Vector2(1.3, 1.3)
	_badge_tween = create_tween().set_parallel(true)
	(
		_badge_tween
		. tween_property(_replay_badge, "position:x", float(MARGIN), 0.45)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_badge_tween
		. tween_property(_replay_badge, "scale", Vector2.ONE, 0.45)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


## Fades the whole picture to dark over `seconds`. Returns the tween to await.
func fade_out(seconds: float) -> Tween:
	return _fade_to(1.0, seconds)


## Fades back in from dark over `seconds`, starting fully dark.
func fade_in(seconds: float) -> Tween:
	_kill_fade()
	_fader.modulate.a = 1.0
	return _fade_to(0.0, seconds)


func _fade_to(alpha: float, seconds: float) -> Tween:
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fader, "modulate:a", alpha, seconds)
	return _fade_tween


func _kill_fade() -> void:
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null


func _build_fader() -> void:
	_fader = ColorRect.new()
	_fader.color = Color(0.0, 0.02, 0.05)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fader.modulate.a = 0.0
	# Not in the padded frame: the dip covers the whole screen.
	add_child(_fader)


func _build_replay_badge() -> void:
	_replay_badge = _make_panel(false)
	_replay_badge.position = Vector2(float(MARGIN), float(MARGIN))
	_replay_badge.add_child(_make_label("REPLAY", 44, 800, UiStyle.CYAN, 4))
	_frame.add_child(_replay_badge)


func _show_wheel_result(result: String) -> void:
	# Skipped when the wheel was hidden, or a newer spin is still turning.
	if _wheel_panel.visible and _wheel.is_settled():
		_wheel_result.text = result


func _clear_notice() -> void:
	_notice.text = ""
	_notice_panel.visible = false


func _clear_lobby() -> void:
	_lobby_key = ""
	_lobby_panel.visible = false
	_board_panel.visible = false
	_help_panel.visible = false


func _set_bets_text(text: String) -> void:
	_bets.text = text
	_bets_panel.visible = text != ""


func _build_lobby() -> void:
	_lobby_panel = _make_panel()
	_lobby_panel.position = Vector2(MARGIN, MARGIN)
	_frame.add_child(_lobby_panel)
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


func _build_board() -> void:
	_board_panel = _make_panel(false)
	add_child(_board_panel)
	_board = LeaderboardPanel.new()
	_board_panel.add_child(_board)
	# Top-right, growing to the left and down with its content.
	_board_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_board_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_board_panel.offset_top = MARGIN
	_board_panel.offset_right = -MARGIN


func _build_help() -> void:
	_help_panel = _make_panel(false)
	_frame.add_child(_help_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_help_panel.add_child(box)
	box.add_child(_make_label(HelpText.TITLE, 24, 800, UiStyle.CYAN, 3))
	for line: String in HelpText.LINES:
		box.add_child(_make_label(line, 22, 600, UiStyle.MUTED))
	# Bottom-right, growing up and to the left; the bets panel owns the bottom-left.
	_help_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_help_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help_panel.offset_right = -MARGIN
	_help_panel.offset_bottom = -MARGIN


func _build_countdown() -> void:
	_big = _make_label("", 260, 900, Color.WHITE)
	_big.material = UiStyle.gradient_material()
	_big.add_theme_color_override("font_shadow_color", Color(UiStyle.CYAN, 0.25))
	_big.add_theme_constant_override("shadow_outline_size", 18)
	_frame.add_child(_big)
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_results() -> void:
	_results_column = VBoxContainer.new()
	_results_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_column.add_theme_constant_override("separation", 24)
	_results_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	_frame.add_child(_results_column)
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
	_dnf_panel = _make_panel(false)
	_dnf_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dnf_label = _make_label("", 28, 700, UiStyle.MUTED)
	_dnf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dnf_panel.add_child(_dnf_label)
	_results_column.add_child(_dnf_panel)
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
	_frame.add_child(_bets_panel)
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
	_frame.add_child(strip)
	strip.add_child(_notice_panel)


func _build_timer() -> void:
	_timer_panel = _make_panel(false)
	_timer_label = _make_label("", 72, 900, UiStyle.TEXT)
	_timer_panel.add_child(_timer_label)
	_frame.add_child(_timer_panel)
	# Top-right corner, growing left and down with its text.
	_timer_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_timer_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_timer_panel.offset_top = MARGIN
	_timer_panel.offset_right = -MARGIN


func _build_event() -> void:
	_wheel_panel = _make_panel(false)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_wheel_panel.add_child(box)
	box.add_child(_centered(_make_label("RANDOM EVENT", 26, 800, UiStyle.CYAN, 3)))
	_wheel = WheelView.new()
	box.add_child(_wheel)
	_wheel_result = _make_label("", 28, 800, UiStyle.TEXT)
	_wheel_result.custom_minimum_size.y = 40.0
	box.add_child(_centered(_wheel_result))
	_event_panel = _make_panel(false)
	_event_label = _make_label("", 28, 800, UiStyle.TEXT, 2)
	_event_panel.add_child(_event_label)
	# Top-centered strips like the notice: both below the notice line.
	_frame.add_child(_top_strip(_wheel_panel, 96.0))
	_frame.add_child(_top_strip(_event_panel, 90.0))


func _top_strip(child: Control, top: float) -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	strip.offset_top = top
	strip.add_child(child)
	return strip


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_panel(start_visible: bool = true) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = start_visible
	return panel


func _make_lobby_row(player: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(FishIcon.new(player))
	var label: Label = _make_label(str(player["name"]), 26, 600, UiStyle.TEXT)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return row


func _make_label(text: String, size: int, weight: int, color: Color, spacing: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.style_label(label, size, weight, color, spacing)
	return label
