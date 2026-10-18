class_name ReleaseSurpriseStore
extends RefCounted
## Remembers whether the fake "Fishy Marble Run 3" release surprise has already played.
## Web: the browser's localStorage, so every OBS browser source has its own flag.
## Desktop: a ConfigFile under user://.

const KEY: String = "fishygame2.fake_fishy_3_release"
const DEFAULT_PATH: String = "user://release_surprise.cfg"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## Whether the surprise already played (or was skipped) on this browser source.
func is_seen() -> bool:
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval(
			"(function(){try{return localStorage.getItem('%s')}catch(e){return null}})()" % KEY
		)
		return value != null and str(value) == "1"
	var file := ConfigFile.new()
	if file.load(_path) != OK:
		return false
	return file.get_value("surprise", "seen", false) == true


## Returns false when the flag could not be stored.
func set_seen(seen: bool) -> bool:
	if OS.has_feature("web"):
		var wanted: String = "1" if seen else "0"
		var ok: Variant = (
			JavaScriptBridge
			. eval(
				(
					"(function(){try{localStorage.setItem('%s','%s');return true}catch(e){return false}})()"
					% [KEY, wanted]
				)
			)
		)
		return ok == true and is_seen() == seen
	var file := ConfigFile.new()
	file.load(_path)
	file.set_value("surprise", "seen", seen)
	return file.save(_path) == OK
