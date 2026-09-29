class_name OnboardingStore
extends RefCounted
## Remembers whether the streamer has finished (or skipped) the first-run onboarding.
## Web: the browser's localStorage, so every OBS browser source has its own flag.
## Desktop: a ConfigFile under user://.

const KEY: String = "fishygame2.onboarding_done"
const DEFAULT_PATH: String = "user://onboarding.cfg"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


func is_done() -> bool:
	if OS.has_feature("web"):
		var storage: JavaScriptObject = JavaScriptBridge.get_interface("localStorage")
		if storage == null:
			return false
		return str(storage.getItem(KEY)) == "1"
	var file := ConfigFile.new()
	if file.load(_path) != OK:
		return false
	return file.get_value("onboarding", "done", false) == true


## Returns false when the flag could not be stored (the onboarding then shows again next time).
func set_done(done: bool) -> bool:
	if OS.has_feature("web"):
		var storage: JavaScriptObject = JavaScriptBridge.get_interface("localStorage")
		if storage == null:
			return false
		storage.setItem(KEY, "1" if done else "0")
		return is_done() == done
	var file := ConfigFile.new()
	file.load(_path)
	file.set_value("onboarding", "done", done)
	return file.save(_path) == OK
