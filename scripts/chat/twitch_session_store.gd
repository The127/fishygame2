class_name TwitchSessionStore
extends RefCounted
## Persists the streamer's login session and the last used client id.
## Web: the browser's localStorage (per origin, so an OBS browser source keeps its own).
## Desktop: a ConfigFile under user://. The token never leaves this device except to Twitch.

const SESSION_KEY: String = "fishygame2.twitch_session"
const STATE_KEY: String = "fishygame2.twitch_login_state"
const CLIENT_ID_KEY: String = "fishygame2.twitch_client_id"
const DEFAULT_PATH: String = "user://twitch_session.cfg"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


func load_session() -> Dictionary:
	var raw: String = _read(SESSION_KEY)
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	for key: String in ["client_id", "token", "user_id", "login", "expires_at"]:
		if not data.has(key):
			return {}
	return data


func save_session(session: Dictionary) -> void:
	_write(SESSION_KEY, JSON.stringify(session))


func clear_session() -> void:
	_remove(SESSION_KEY)


## Remembers the OAuth state and client id while the browser is away on twitch.tv.
func save_pending_login(state: String, client_id: String) -> void:
	_write(STATE_KEY, state)
	_write(CLIENT_ID_KEY, client_id)


## Returns the pending state and forgets it, so a state can only be used once.
func take_pending_state() -> String:
	var state: String = _read(STATE_KEY)
	_remove(STATE_KEY)
	return state


func load_client_id() -> String:
	return _read(CLIENT_ID_KEY)


func save_client_id(client_id: String) -> void:
	_write(CLIENT_ID_KEY, client_id)


func _read(key: String) -> String:
	if OS.has_feature("web"):
		var storage: JavaScriptObject = JavaScriptBridge.get_interface("localStorage")
		if storage == null:
			return ""
		var value: Variant = storage.getItem(key)
		return "" if value == null else str(value)
	var file := ConfigFile.new()
	if file.load(_path) != OK:
		return ""
	return str(file.get_value("store", key, ""))


func _write(key: String, value: String) -> void:
	if OS.has_feature("web"):
		var storage: JavaScriptObject = JavaScriptBridge.get_interface("localStorage")
		if storage != null:
			storage.setItem(key, value)
		return
	var file := ConfigFile.new()
	file.load(_path)
	file.set_value("store", key, value)
	file.save(_path)


func _remove(key: String) -> void:
	if OS.has_feature("web"):
		var storage: JavaScriptObject = JavaScriptBridge.get_interface("localStorage")
		if storage != null:
			storage.removeItem(key)
		return
	var file := ConfigFile.new()
	if file.load(_path) != OK:
		return
	if file.has_section_key("store", key):
		file.erase_section_key("store", key)
		file.save(_path)
