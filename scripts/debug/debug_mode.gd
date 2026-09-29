class_name DebugMode
extends RefCounted
## Debug-only features (fake players, fake chat) are hidden unless this is on.
## Web: add ?debug=1 to the URL. Elsewhere: on in the editor and debug builds.

static var _cached: int = -1


static func is_enabled() -> bool:
	if _cached < 0:
		_cached = 1 if _detect() else 0
	return _cached == 1


## Overrides detection, for tests.
static func set_enabled(value: bool) -> void:
	_cached = 1 if value else 0


static func _detect() -> bool:
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('debug')"
		)
		return value != null and str(value) in ["1", "true"]
	return OS.is_debug_build()
