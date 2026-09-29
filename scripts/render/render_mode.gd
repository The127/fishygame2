class_name RenderMode
extends RefCounted
## Whether the race is drawn as an underwater 3D scene instead of the flat 2D look.
## Off by default. Web: add ?3d=1 to the URL. Elsewhere: pass --3d after `--`.
## F1-panel users can also flip it at runtime with F2.

static var _cached: int = -1


static func is_3d() -> bool:
	if _cached < 0:
		_cached = 1 if _detect() else 0
	return _cached == 1


## Overrides detection, for tests and the runtime toggle.
static func set_3d(value: bool) -> void:
	_cached = 1 if value else 0


static func _detect() -> bool:
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('3d')"
		)
		return value != null and str(value) in ["1", "true"]
	return "--3d" in OS.get_cmdline_user_args()
