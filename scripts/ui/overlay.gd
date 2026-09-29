class_name Overlay
extends CanvasLayer
## Viewer-facing text: lobby list, countdown number and podium.

var _lobby: Label
var _big: Label
var _podium: Label
var _payouts: Label
var _bets: Label
var _notice: Label
var _notice_timer: Timer


func _ready() -> void:
	_lobby = _make_label(28, Vector2(60, 40), HORIZONTAL_ALIGNMENT_LEFT)
	_big = _make_label(220, Vector2(0, 280), HORIZONTAL_ALIGNMENT_CENTER)
	_big.size = Vector2(1920, 300)
	_podium = _make_label(56, Vector2(0, 260), HORIZONTAL_ALIGNMENT_CENTER)
	_podium.size = Vector2(1920, 500)
	_payouts = _make_label(32, Vector2(0, 640), HORIZONTAL_ALIGNMENT_CENTER)
	_payouts.size = Vector2(1920, 300)
	_bets = _make_label(28, Vector2(60, 980), HORIZONTAL_ALIGNMENT_LEFT)
	_notice = _make_label(32, Vector2(0, 40), HORIZONTAL_ALIGNMENT_CENTER)
	_notice.size = Vector2(1920, 50)
	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.timeout.connect(func() -> void: _notice.text = "")
	add_child(_notice_timer)
	clear()


func clear() -> void:
	_lobby.text = ""
	_big.text = ""
	_podium.text = ""
	_payouts.text = ""
	_bets.text = ""


func show_idle() -> void:
	clear()


func show_lobby(names: PackedStringArray, max_players: int, seconds_left: float) -> void:
	_big.text = ""
	_podium.text = ""
	_payouts.text = ""
	var header: String = "Type #join to race! %d/%d" % [names.size(), max_players]
	if seconds_left > 0.0:
		header += "  (starts in %d s)" % ceili(seconds_left)
	_lobby.text = header + "\n" + "\n".join(names)


func show_countdown(seconds_left: int) -> void:
	_lobby.text = ""
	_big.text = str(seconds_left)


func show_racing() -> void:
	clear()


func show_podium(podium: Array[Dictionary]) -> void:
	clear()
	var lines: PackedStringArray = ["Podium"]
	for entry: Dictionary in podium:
		var time_text: String = "%.1fs" % entry["time"] if entry["finished"] else "did not finish"
		lines.append("%d. %s  %s" % [entry["place"], entry["name"], time_text])
	_podium.text = "\n".join(lines)


func show_bets(text: String) -> void:
	_bets.text = text


## Lines of "name won 500 (bet on Alice)" / "name lost 100"; only the first few are shown.
func show_payouts(results: Array[Dictionary], max_lines: int = 8) -> void:
	var lines: PackedStringArray = []
	for entry: Dictionary in results:
		if lines.size() >= max_lines:
			break
		if int(entry["payout"]) > 0:
			lines.append("%s won %d points" % [entry["name"], entry["payout"]])
		else:
			lines.append("%s lost %d points" % [entry["name"], entry["amount"]])
	_payouts.text = "\n".join(lines)


## Short message near the top that clears itself.
func show_notice(text: String, seconds: float = 4.0) -> void:
	_notice.text = text
	_notice_timer.start(seconds)


func _make_label(font_size: int, pos: Vector2, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = pos
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
