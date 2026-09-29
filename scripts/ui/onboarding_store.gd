class_name OnboardingStore
extends RefCounted
## Remembers whether the streamer has finished (or skipped) the first-run onboarding.
## Web: the browser's localStorage, so every OBS browser source has its own flag.
## Desktop: a ConfigFile under user://.

const KEY: String = "fishygame2.onboarding_done"
const DEFAULT_PATH: String = "user://onboarding.cfg"

## Set when the streamer finishes or skips the guide, even if saving failed, so a broken
## storage costs one guide per page load instead of locking the streamer out of the home screen.
static var dismissed_this_session: bool = false

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## Whether the home screen should skip the guide: saved as done, or dismissed this session.
func is_done() -> bool:
	return dismissed_this_session or _saved_done()


func _saved_done() -> bool:
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval(
			"(function(){try{return localStorage.getItem('%s')}catch(e){return null}})()" % KEY
		)
		return value != null and str(value) == "1"
	var file := ConfigFile.new()
	if file.load(_path) != OK:
		return false
	return file.get_value("onboarding", "done", false) == true


## Returns false when the flag could not be stored (the onboarding then shows again next time).
func set_done(done: bool) -> bool:
	if OS.has_feature("web"):
		var wanted: String = "1" if done else "0"
		var ok: Variant = (
			JavaScriptBridge
			. eval(
				(
					"(function(){try{localStorage.setItem('%s','%s');return true}catch(e){return false}})()"
					% [KEY, wanted]
				)
			)
		)
		return ok == true and _saved_done() == done
	var file := ConfigFile.new()
	file.load(_path)
	file.set_value("onboarding", "done", done)
	return file.save(_path) == OK
