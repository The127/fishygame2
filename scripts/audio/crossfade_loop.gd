class_name CrossfadeLoop
extends Node
## Two looping players on one bus that trade places: [method fade_to] brings a new stream in
## while the previous one fades out, so themes and ambience beds never cut off abruptly.

const SILENT_DB: float = -80.0

var _current: AudioStreamPlayer
var _fading: AudioStreamPlayer
var _tween: Tween


func _init(bus: String = "Master") -> void:
	_current = _make_player(bus)
	_fading = _make_player(bus)


## Crossfades to [param stream] over [param seconds]. It must already loop (see [method Sound.make_loop]).
func fade_to(stream: AudioStreamWAV, seconds: float) -> void:
	if _tween != null:
		_tween.kill()
	# The player that was still fading out is reused below, so cut it off.
	_fading.stop()
	var outgoing: AudioStreamPlayer = _current
	_current = _fading
	_fading = outgoing
	_current.stream = stream
	_current.volume_db = SILENT_DB
	_current.play()
	# Quad easing keeps both streams audible mid-fade instead of dipping to silence.
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_current, "volume_db", 0.0, seconds).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_fading, "volume_db", SILENT_DB, seconds).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_fading.stop)


## Fades whatever is playing out to silence.
func fade_out(seconds: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
	for player: AudioStreamPlayer in [_current, _fading]:
		_tween.tween_property(player, "volume_db", SILENT_DB, seconds).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_stop_all)


## Restarts the stream if the platform stopped it (the web build before the first input).
func resume_if_stopped() -> void:
	if _current.stream != null and not _current.playing and _current.volume_db > SILENT_DB:
		_current.play()


func _stop_all() -> void:
	_current.stop()
	_fading.stop()


func _make_player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player
