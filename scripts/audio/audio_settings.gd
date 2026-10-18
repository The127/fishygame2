class_name AudioSettings
extends RefCounted
## Streamer sound choices: a linear 0..1 volume per bus, a mute switch and the music options,
## persisted as a ConfigFile (user:// is IndexedDB in the web export, so it survives reloads).

const DEFAULT_PATH: String = "user://audio.cfg"
const SECTION: String = "audio"
const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_AMBIENCE: String = "Ambience"
const BUS_SFX: String = "SFX"
const BUSES: Array[String] = [BUS_MASTER, BUS_MUSIC, BUS_AMBIENCE, BUS_SFX]
const DEFAULT_VOLUMES: Dictionary = {
	BUS_MASTER: 0.8, BUS_MUSIC: 0.5, BUS_AMBIENCE: 0.5, BUS_SFX: 0.8
}
## Values of [member music_mode]: each map's own theme, or the home theme everywhere.
const MUSIC_PER_MAP: int = 0
const MUSIC_HOME: int = 1
const DEFAULT_CROSSFADE: float = 2.0
const MAX_CROSSFADE: float = 10.0

var muted: bool = false
## Off silences the Music bus only; ambience and effects keep playing.
var music_enabled: bool = true
var music_mode: int = MUSIC_PER_MAP
## Off plays the generic win sound instead of the map's podium jingle.
var jingles: bool = true
## Seconds the old theme fades out while the new one fades in.
var crossfade: float = DEFAULT_CROSSFADE
## Empty means in-memory only.
var save_path: String = ""

var _volumes: Dictionary = DEFAULT_VOLUMES.duplicate()


func _init(p_save_path: String = "") -> void:
	save_path = p_save_path


## Linear volume 0..1 of a bus. Unknown buses read as full volume.
func get_volume(bus: String) -> float:
	return float(_volumes.get(bus, 1.0))


## Stores a volume clamped to 0..1. Returns false for a bus this class does not manage.
func set_volume(bus: String, value: float) -> bool:
	if not BUSES.has(bus):
		return false
	_volumes[bus] = clampf(value, 0.0, 1.0)
	return true


func set_music_mode(mode: int) -> void:
	music_mode = clampi(mode, MUSIC_PER_MAP, MUSIC_HOME)


func set_crossfade(seconds: float) -> void:
	crossfade = clampf(seconds, 0.0, MAX_CROSSFADE)


## Puts every choice back to its default.
func reset_to_defaults() -> void:
	_volumes = DEFAULT_VOLUMES.duplicate()
	muted = false
	music_enabled = true
	music_mode = MUSIC_PER_MAP
	jingles = true
	crossfade = DEFAULT_CROSSFADE


## A copy of every bus volume, for building UI.
func get_volumes() -> Dictionary:
	return _volumes.duplicate()


## Loads the saved choices; missing or malformed values keep their defaults.
func load_settings() -> void:
	if save_path == "":
		return
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	for bus: String in BUSES:
		if not file.has_section_key(SECTION, bus):
			continue
		var value: Variant = file.get_value(SECTION, bus)
		if value is float or value is int:
			set_volume(bus, float(value))
	muted = _saved_bool(file, "muted", false)
	music_enabled = _saved_bool(file, "music_enabled", true)
	jingles = _saved_bool(file, "jingles", true)
	var mode: Variant = file.get_value(SECTION, "music_mode", MUSIC_PER_MAP)
	if mode is int and mode >= MUSIC_PER_MAP and mode <= MUSIC_HOME:
		music_mode = mode
	var fade: Variant = file.get_value(SECTION, "crossfade", DEFAULT_CROSSFADE)
	if fade is float or fade is int:
		set_crossfade(float(fade))


## Writes the choices. Returns false when there is no path or the write failed.
func save() -> bool:
	if save_path == "":
		return false
	var file := ConfigFile.new()
	for bus: String in BUSES:
		file.set_value(SECTION, bus, get_volume(bus))
	file.set_value(SECTION, "muted", muted)
	file.set_value(SECTION, "music_enabled", music_enabled)
	file.set_value(SECTION, "music_mode", music_mode)
	file.set_value(SECTION, "jingles", jingles)
	file.set_value(SECTION, "crossfade", crossfade)
	return file.save(save_path) == OK


## A saved yes/no value, or `fallback` when it is missing or not a bool.
static func _saved_bool(file: ConfigFile, key: String, fallback: bool) -> bool:
	var value: Variant = file.get_value(SECTION, key, fallback)
	return value if value is bool else fallback
