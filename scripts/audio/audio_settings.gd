class_name AudioSettings
extends RefCounted
## Streamer volume choices: a linear 0..1 volume per bus plus a mute switch, persisted
## as a ConfigFile (user:// is IndexedDB in the web export, so it survives reloads).

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

var muted: bool = false
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
	var saved_mute: Variant = file.get_value(SECTION, "muted", false)
	muted = saved_mute is bool and saved_mute


## Writes the choices. Returns false when there is no path or the write failed.
func save() -> bool:
	if save_path == "":
		return false
	var file := ConfigFile.new()
	for bus: String in BUSES:
		file.set_value(SECTION, bus, get_volume(bus))
	file.set_value(SECTION, "muted", muted)
	return file.save(save_path) == OK
