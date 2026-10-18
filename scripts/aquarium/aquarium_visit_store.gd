class_name AquariumVisitStore
extends RefCounted
## Remembers whether the streamer has opened the aquarium at least once, so the home screen
## can make its button blink until then.
## Web: the browser's localStorage, so every OBS browser source has its own flag.
## Desktop: a ConfigFile under user://.

const KEY: String = "fishygame2.aquarium_visited"
const DEFAULT_PATH: String = "user://aquarium_visit.cfg"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## Whether the aquarium was opened before on this browser source.
func is_visited() -> bool:
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval(
			"(function(){try{return localStorage.getItem('%s')}catch(e){return null}})()" % KEY
		)
		return value != null and str(value) == "1"
	var file := ConfigFile.new()
	if file.load(_path) != OK:
		return false
	return file.get_value("aquarium", "visited", false) == true


## Returns false when the flag could not be stored (the button then blinks again next time).
func set_visited(visited: bool) -> bool:
	if OS.has_feature("web"):
		var wanted: String = "1" if visited else "0"
		var ok: Variant = (
			JavaScriptBridge
			. eval(
				(
					"(function(){try{localStorage.setItem('%s','%s');return true}catch(e){return false}})()"
					% [KEY, wanted]
				)
			)
		)
		return ok == true and is_visited() == visited
	var file := ConfigFile.new()
	file.load(_path)
	file.set_value("aquarium", "visited", visited)
	return file.save(_path) == OK
