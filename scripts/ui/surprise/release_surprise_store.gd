class_name ReleaseSurpriseStore
extends RefCounted
## Remembers whether the fake "Fishy Marble Run 3" release surprise has already played.
## Web: the browser's localStorage, so every OBS browser source has its own flag.
## Desktop: a ConfigFile under user://.

const KEY: String = "fishygame2.fake_fishy_3_release"
## Set the first time the surprise plays and never cleared again, not even by a re-arm.
const PLAYED_KEY: String = "fishygame2.fake_fishy_3_played"
const DEFAULT_PATH: String = "user://release_surprise.cfg"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## Whether the surprise already played (or was skipped) on this browser source.
func is_seen() -> bool:
	return _get_flag(KEY, "seen")


## Returns false when the flag could not be stored.
func set_seen(seen: bool) -> bool:
	return _set_flag(KEY, "seen", seen)


## Whether the fake 3D sequel has ever played on this browser source. Unlocks RTX. A store
## from before this flag existed counts a seen surprise as played.
func has_played() -> bool:
	return _get_flag(PLAYED_KEY, "played") or is_seen()


## Returns false when the flag could not be stored.
func set_played() -> bool:
	return _set_flag(PLAYED_KEY, "played", true)


func _get_flag(web_key: String, file_key: String) -> bool:
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval(
			"(function(){try{return localStorage.getItem('%s')}catch(e){return null}})()" % web_key
		)
		return value != null and str(value) == "1"
	var file := ConfigFile.new()
	if file.load(_path) != OK:
		return false
	return file.get_value("surprise", file_key, false) == true


func _set_flag(web_key: String, file_key: String, on: bool) -> bool:
	if OS.has_feature("web"):
		var wanted: String = "1" if on else "0"
		var ok: Variant = (
			JavaScriptBridge
			. eval(
				(
					"(function(){try{localStorage.setItem('%s','%s');return true}catch(e){return false}})()"
					% [web_key, wanted]
				)
			)
		)
		return ok == true and _get_flag(web_key, file_key) == on
	var file := ConfigFile.new()
	file.load(_path)
	file.set_value("surprise", file_key, on)
	return file.save(_path) == OK
