extends Node
## Autoload "Sound": the one audio service. It creates the Music, Ambience and SFX buses under
## Master, loops the ambient music and plays one-shot effects from a small player pool.
## Each map has its own music theme (see [member MUSIC_PATHS]); [method set_music_theme]
## crossfades to it. Volumes and mute come from [AudioSettings] and are saved shortly after
## each change.
##
## Web export: browsers keep audio suspended until the first click or key press. Godot
## resumes it on that input and the already playing music simply becomes audible, so
## nothing needs unlocking here. An OBS browser source can be allowed to autoplay.

enum Sfx { JOIN, TICK, GO, BOOST, CURSE, SPLASH, WIN, MEOW }

## Theme played on the home screen and whenever a theme id is unknown.
const HOME_THEME: String = "home"
## Music theme by id: "home" plus one per map id in [TrackCatalog].
const MUSIC_PATHS: Dictionary = {
	HOME_THEME: "res://assets/audio/music_ambient.wav",
	"zigzag": "res://assets/audio/music_zigzag.wav",
	"pachinko": "res://assets/audio/music_pachinko.wav",
	"wreck": "res://assets/audio/music_wreck.wav",
	"whirlpool": "res://assets/audio/music_whirlpool.wav",
	"jelly": "res://assets/audio/music_jelly.wav",
	"abyss": "res://assets/audio/music_abyss.wav",
	"vents": "res://assets/audio/music_vents.wav",
	"coral": "res://assets/audio/music_coral.wav",
	"kraken": "res://assets/audio/music_kraken.wav",
	"gravity": "res://assets/audio/music_gravity.wav",
}
## Quiet looping sound bed by map id (the home screen has none).
const AMBIENCE_PATHS: Dictionary = {
	"zigzag": "res://assets/audio/ambience_zigzag.wav",
	"pachinko": "res://assets/audio/ambience_pachinko.wav",
	"wreck": "res://assets/audio/ambience_wreck.wav",
	"whirlpool": "res://assets/audio/ambience_whirlpool.wav",
	"jelly": "res://assets/audio/ambience_jelly.wav",
	"abyss": "res://assets/audio/ambience_abyss.wav",
	"vents": "res://assets/audio/ambience_vents.wav",
	"coral": "res://assets/audio/ambience_coral.wav",
	"kraken": "res://assets/audio/ambience_kraken.wav",
	"gravity": "res://assets/audio/ambience_gravity.wav",
}
## Podium jingle by map id.
const JINGLE_PATHS: Dictionary = {
	"zigzag": "res://assets/audio/jingle_zigzag.wav",
	"pachinko": "res://assets/audio/jingle_pachinko.wav",
	"wreck": "res://assets/audio/jingle_wreck.wav",
	"whirlpool": "res://assets/audio/jingle_whirlpool.wav",
	"jelly": "res://assets/audio/jingle_jelly.wav",
	"abyss": "res://assets/audio/jingle_abyss.wav",
	"vents": "res://assets/audio/jingle_vents.wav",
	"coral": "res://assets/audio/jingle_coral.wav",
	"kraken": "res://assets/audio/jingle_kraken.wav",
	"gravity": "res://assets/audio/jingle_gravity.wav",
}
const SFX_PATHS: Dictionary = {
	Sfx.JOIN: "res://assets/audio/sfx_join.wav",
	Sfx.TICK: "res://assets/audio/sfx_tick.wav",
	Sfx.GO: "res://assets/audio/sfx_go.wav",
	Sfx.BOOST: "res://assets/audio/sfx_boost.wav",
	Sfx.CURSE: "res://assets/audio/sfx_curse.wav",
	Sfx.SPLASH: "res://assets/audio/sfx_splash.wav",
	Sfx.WIN: "res://assets/audio/sfx_win.wav",
	Sfx.MEOW: "res://assets/audio/sfx_meow.wav",
}
const POOL_SIZE: int = 8
## The same effect is not restarted within this many milliseconds (20 fish can finish together).
const MIN_REPEAT_MSEC: int = 40
const PITCH_JITTER: float = 0.04
const MUSIC_FADE_IN: float = 3.0
## Seconds the old theme fades out while the new one fades in.
const MUSIC_CROSSFADE: float = 2.0
const SILENT_DB: float = -80.0
## Seconds after the last change before settings are written.
const SAVE_DELAY: float = 0.5

var settings: AudioSettings = AudioSettings.new(AudioSettings.DEFAULT_PATH)

## False without an audio device (headless runs and tests): nothing is played, and no
## playing stream is left behind for the mixer at shutdown.
var _audible: bool = DisplayServer.get_name() != "headless"
var _sfx_streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}
var _music: CrossfadeLoop
var _ambience: CrossfadeLoop
var _music_streams: Dictionary = {}
var _ambience_streams: Dictionary = {}
var _jingle_streams: Dictionary = {}
var _theme: String = HOME_THEME
var _dirty: bool = false
var _save_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	settings.load_settings()
	_ensure_buses()
	_apply_all()
	for sfx: int in SFX_PATHS:
		_sfx_streams[sfx] = load(SFX_PATHS[sfx])
	for i: int in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = AudioSettings.BUS_SFX
		add_child(player)
		_players.append(player)
	_music = CrossfadeLoop.new(AudioSettings.BUS_MUSIC)
	_ambience = CrossfadeLoop.new(AudioSettings.BUS_AMBIENCE)
	add_child(_music)
	add_child(_ambience)
	if _audible:
		_music.fade_to(_music_stream(_theme), MUSIC_FADE_IN)


func _process(delta: float) -> void:
	if _dirty:
		_save_timer -= delta
		if _save_timer <= 0.0:
			save_now()


func _input(event: InputEvent) -> void:
	# Covers a music player that was stopped by the platform before the first interaction.
	if not (
		event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch
	):
		return
	_music.resume_if_stopped()
	_ambience.resume_if_stopped()


func _notification(what: int) -> void:
	# The web build gets no close request, so losing focus also flushes a pending save.
	var leaving: bool = (
		what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT
	)
	if leaving and _dirty:
		save_now()


## Crossfades to the music theme with this id (a map id or [constant HOME_THEME]). Unknown
## ids fall back to the home theme; asking for the theme already playing does nothing.
func set_music_theme(id: String) -> void:
	if not MUSIC_PATHS.has(id):
		id = HOME_THEME
	if id == _theme:
		return
	_theme = id
	if not _audible:
		return
	_music.fade_to(_music_stream(id), MUSIC_CROSSFADE)
	if AMBIENCE_PATHS.has(id):
		_ambience.fade_to(_ambience_stream(id), MUSIC_CROSSFADE)
	else:
		_ambience.fade_out(MUSIC_CROSSFADE)


## Id of the music theme that is playing (or fading in).
func get_music_theme() -> String:
	return _theme


## Plays a one-shot effect. Silently skipped when repeated too fast or the pool is busy.
func play(sfx: Sfx) -> void:
	_play_stream(sfx, _sfx_streams.get(sfx), PITCH_JITTER)


## Plays the podium sting of the current map, or the generic win sound when the theme has none.
func play_win() -> void:
	if not JINGLE_PATHS.has(_theme):
		play(Sfx.WIN)
		return
	if not _jingle_streams.has(_theme):
		_jingle_streams[_theme] = load(JINGLE_PATHS[_theme])
	_play_stream(_theme, _jingle_streams[_theme], 0.0)


## Sets a bus volume (linear 0..1) and schedules a save.
func set_volume(bus: String, value: float) -> void:
	if not settings.set_volume(bus, value):
		return
	_apply_bus(bus)
	_mark_dirty()


func set_muted(muted: bool) -> void:
	settings.muted = muted
	_apply_all()
	_mark_dirty()


## Writes the settings now instead of waiting for the delay.
func save_now() -> void:
	_dirty = false
	settings.save()


## The dB value a bus gets for a linear volume; zero is fully silent.
static func volume_to_db(value: float) -> float:
	if value <= 0.001:
		return SILENT_DB
	return maxf(linear_to_db(value), SILENT_DB)


func _play_stream(key: Variant, stream: AudioStream, jitter: float) -> void:
	if stream == null or not _audible:
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(key, -MIN_REPEAT_MSEC)) < MIN_REPEAT_MSEC:
		return
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			_last_played[key] = now
			player.stream = stream
			player.pitch_scale = 1.0 + _rng.randf_range(-jitter, jitter)
			player.play()
			return


func _music_stream(id: String) -> AudioStreamWAV:
	if not _music_streams.has(id):
		_music_streams[id] = make_loop(load(MUSIC_PATHS[id]))
	return _music_streams[id]


func _ambience_stream(id: String) -> AudioStreamWAV:
	if not _ambience_streams.has(id):
		_ambience_streams[id] = make_loop(load(AMBIENCE_PATHS[id]))
	return _ambience_streams[id]


func _mark_dirty() -> void:
	_dirty = true
	_save_timer = SAVE_DELAY


func _ensure_buses() -> void:
	for bus: String in [AudioSettings.BUS_MUSIC, AudioSettings.BUS_AMBIENCE, AudioSettings.BUS_SFX]:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, AudioSettings.BUS_MASTER)


func _apply_all() -> void:
	for bus: String in AudioSettings.BUSES:
		_apply_bus(bus)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioSettings.BUS_MASTER), settings.muted)


func _apply_bus(bus: String) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index != -1:
		AudioServer.set_bus_volume_db(index, volume_to_db(settings.get_volume(bus)))


## Loops the whole clip. loop_end counts sample frames, and the imported data may be
## compressed, so it comes from the length rather than the byte size.
static func make_loop(stream: AudioStreamWAV) -> AudioStreamWAV:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream
