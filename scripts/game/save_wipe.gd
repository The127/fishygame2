class_name SaveWipe
extends RefCounted
## Deletes a persisted save: the file, its temp and backup copies, quarantined corrupt copies
## and (in the web build) the localStorage mirror, which would otherwise win on the next load.


## Removes everything stored for [param path] ("user://points.json" and so on).
## [param mirror_key] is the localStorage key of the mirror, "" if the save has none.
static func erase(path: String, mirror_key: String = "") -> void:
	var dir: String = path.get_base_dir()
	var prefix: String = path.get_file()
	for file: String in DirAccess.get_files_at(dir):
		if file == prefix or file.begins_with(prefix + "."):
			DirAccess.remove_absolute(dir.path_join(file))
	if not mirror_key.is_empty() and OS.has_feature("web"):
		# JSON.stringify of a string is a valid JavaScript string literal.
		JavaScriptBridge.eval(
			"try { window.localStorage.removeItem(%s); } catch (e) {}" % JSON.stringify(mirror_key)
		)
