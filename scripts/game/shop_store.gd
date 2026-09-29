class_name ShopStore
extends RefCounted
## What each viewer owns in the fish shop and has equipped, keyed by Twitch user id and
## optionally persisted as JSON. Items are chat names (see [ShopCatalog]).
##
## On the web the file lives in IndexedDB, which the engine flushes a few seconds after a
## write, so every save is also mirrored to localStorage and the newer copy wins on load.

const KIND_SPECIES: String = "species"
const KIND_COLOR: String = "color"
const KINDS: Array[String] = [KIND_SPECIES, KIND_COLOR]

## Empty means in-memory only.
var save_path: String = ""

## user_id -> {kind: Array[String]}
var _owned: Dictionary = {}
## user_id -> {kind: String}
var _equipped: Dictionary = {}


func _init(p_save_path: String = "") -> void:
	save_path = p_save_path


func owns(user_id: String, kind: String, item: String) -> bool:
	var items: Array = _owned.get(user_id, {}).get(kind, [])
	return items.has(item)


func grant(user_id: String, kind: String, item: String) -> void:
	if owns(user_id, kind, item) or not KINDS.has(kind):
		return
	var by_kind: Dictionary = _owned.get_or_add(user_id, {})
	var items: Array = by_kind.get_or_add(kind, [])
	items.append(item)


## Equips an item the viewer owns. Returns false (and changes nothing) otherwise.
func equip(user_id: String, kind: String, item: String) -> bool:
	if not owns(user_id, kind, item):
		return false
	var by_kind: Dictionary = _equipped.get_or_add(user_id, {})
	by_kind[kind] = item
	return true


## The equipped item, or "" if the viewer has not equipped one.
func equipped(user_id: String, kind: String) -> String:
	return String(_equipped.get(user_id, {}).get(kind, ""))


## Loads the saved data. A missing file is not an error (returns true); an unreadable
## one leaves the store empty and returns false.
func load_from_disk() -> bool:
	_owned.clear()
	_equipped.clear()
	if save_path.is_empty():
		return true
	var file_data: Dictionary = _parse(_read(save_path))
	var mirrored: Dictionary = _parse(_mirror_read())
	var file_time: float = _saved_at(file_data)
	if not mirrored.is_empty() and (file_data.is_empty() or _saved_at(mirrored) > file_time):
		file_data = mirrored
	if file_data.is_empty():
		return not FileAccess.file_exists(save_path)
	_apply(file_data)
	return true


func save_to_disk() -> bool:
	if save_path.is_empty():
		return true
	var text: String = (
		JSON
		. stringify(
			{
				"version": 1,
				"saved_at": Time.get_unix_time_from_system(),
				"owned": _owned,
				"equipped": _equipped,
			}
		)
	)
	_mirror_write(text)
	var tmp: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s" % tmp)
		return false
	file.store_string(text)
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		push_warning("Could not write %s" % tmp)
		return false
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if DirAccess.rename_absolute(tmp, save_path) != OK:
		push_warning("Could not replace %s" % save_path)
		return false
	return true


func _mirror_enabled() -> bool:
	return OS.has_feature("web")


func _mirror_key() -> String:
	return "fishygame2.shop:" + save_path


func _mirror_write(text: String) -> void:
	if not _mirror_enabled():
		return
	# JSON.stringify of a string is a valid JavaScript string literal.
	JavaScriptBridge.eval(
		(
			"try { window.localStorage.setItem(%s, %s); } catch (e) {}"
			% [JSON.stringify(_mirror_key()), JSON.stringify(text)]
		)
	)


func _mirror_read() -> String:
	if not _mirror_enabled():
		return ""
	var value: Variant = (
		JavaScriptBridge
		. eval(
			(
				"(function () { try { return window.localStorage.getItem(%s) || ''; } catch (e) { return ''; } })()"
				% JSON.stringify(_mirror_key())
			)
		)
	)
	return value if value is String else ""


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


## Returns the parsed data, or an empty dictionary if the text is empty or not a save.
func _parse(text: String) -> Dictionary:
	var json := JSON.new()
	if text.is_empty() or json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	if not (parsed is Dictionary) or not (parsed.get("owned") is Dictionary):
		return {}
	if not (parsed.get("equipped", {}) is Dictionary):
		return {}
	return parsed


func _saved_at(data: Dictionary) -> float:
	var value: Variant = data.get("saved_at", 0.0)
	return float(value) if value is float or value is int else 0.0


## Copies the data over, dropping anything that is not the expected shape.
func _apply(data: Dictionary) -> void:
	var owned: Dictionary = data["owned"]
	for user_id: Variant in owned:
		if not (owned[user_id] is Dictionary):
			continue
		for kind: String in KINDS:
			var items: Variant = owned[user_id].get(kind, [])
			if not (items is Array):
				continue
			for item: Variant in items:
				if item is String:
					grant(str(user_id), kind, item)
	var equipped_data: Dictionary = data.get("equipped", {})
	for user_id: Variant in equipped_data:
		if not (equipped_data[user_id] is Dictionary):
			continue
		for kind: String in KINDS:
			var item: Variant = equipped_data[user_id].get(kind, "")
			if item is String:
				equip(str(user_id), kind, item)
