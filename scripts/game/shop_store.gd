class_name ShopStore
extends RefCounted
## What each viewer owns in the fish shop and has equipped, keyed by Twitch user id and
## optionally persisted as JSON. Items are chat names (see [ShopCatalog]).
##
## Saves are atomic (temp file, then rename) and keep the previous file as a backup; an
## unreadable file is moved aside instead of being overwritten.
##
## On the web the file lives in IndexedDB, which the engine flushes a few seconds after a
## write, so every save is also mirrored to localStorage and the newer copy wins on load.

const KIND_SPECIES: String = "species"
const KIND_COLOR: String = "color"
const KIND_HAT: String = "hat"
const KINDS: Array[String] = [KIND_SPECIES, KIND_COLOR, KIND_HAT]

## Empty means in-memory only.
var save_path: String = ""

## user_id -> {kind: Array[String]}
var _owned: Dictionary = {}
## user_id -> {kind: String}
var _equipped: Dictionary = {}
## Viewers who already got their free first-race hat, as a set of user ids.
var _welcomed: Dictionary = {}
## Save time (unix seconds) of the copy that was loaded last; 0 if it had none.
var _loaded_at: float = 0.0
## Whether a saved copy was loaded from the files.
var _loaded: bool = false


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


## Whether the viewer already got their free first-race hat.
func was_welcomed(user_id: String) -> bool:
	return _welcomed.has(user_id)


func mark_welcomed(user_id: String) -> void:
	_welcomed[user_id] = true


## Equips an item the viewer owns. Returns false (and changes nothing) otherwise.
func equip(user_id: String, kind: String, item: String) -> bool:
	if not owns(user_id, kind, item):
		return false
	var by_kind: Dictionary = _equipped.get_or_add(user_id, {})
	by_kind[kind] = item
	return true


## Takes off whatever the viewer has equipped as [param kind].
func unequip(user_id: String, kind: String) -> void:
	if _equipped.has(user_id):
		_equipped[user_id].erase(kind)


## Every viewer id with anything owned or equipped.
func user_ids() -> Array[String]:
	var ids: Array[String] = []
	for source: Dictionary in [_owned, _equipped]:
		for user_id: String in source:
			if not ids.has(user_id):
				ids.append(user_id)
	return ids


## The equipped item, or "" if the viewer has not equipped one.
func equipped(user_id: String, kind: String) -> String:
	return String(_equipped.get(user_id, {}).get(kind, ""))


## Loads the saved data. A missing file is not an error (returns true). If the main file is
## unreadable the temp file or backup is used (returns true); if those fail too the unreadable
## files are moved aside (never overwritten by the next save), the store is left empty and
## false is returned.
func load_from_disk() -> bool:
	_owned.clear()
	_equipped.clear()
	_welcomed.clear()
	_loaded_at = 0.0
	_loaded = false
	if save_path.is_empty():
		return true
	var ok: bool = _load_files()
	# The mirror can hold a save the browser had not flushed to IndexedDB yet.
	var mirrored: Dictionary = _parse(_mirror_read())
	if not mirrored.is_empty() and (not _loaded or _saved_at(mirrored) > _loaded_at):
		_owned.clear()
		_equipped.clear()
		_welcomed.clear()
		_apply(mirrored)
		return true
	return ok


func _load_files() -> bool:
	if not FileAccess.file_exists(save_path) and not FileAccess.file_exists(_backup_path()):
		return true
	if _load_file(save_path):
		return true
	push_warning("Shop file %s is unusable, trying recovery files" % save_path)
	# A finished temp file means the save was interrupted between the two renames.
	if _load_file(_tmp_path()) or _load_file(_backup_path()):
		_quarantine(save_path)
		return true
	_quarantine(save_path)
	_quarantine(_tmp_path())
	_quarantine(_backup_path())
	return false


## Writes to a temp file first, then swaps it in, keeping the previous file as backup.
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
				"welcomed": _welcomed.keys(),
			}
		)
	)
	_mirror_write(text)
	var tmp: String = _tmp_path()
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
	# Only a readable current file is worth keeping as the backup.
	if not _parse(_read(save_path)).is_empty():
		_remove(_backup_path())
		if DirAccess.rename_absolute(save_path, _backup_path()) != OK:
			push_warning("Could not back up %s" % save_path)
	else:
		_quarantine(save_path)
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


func _tmp_path() -> String:
	return save_path + ".tmp"


func _backup_path() -> String:
	return save_path + ".bak"


func _load_file(path: String) -> bool:
	var data: Dictionary = _parse(_read(path))
	if data.is_empty():
		return false
	_owned.clear()
	_equipped.clear()
	_welcomed.clear()
	_apply(data)
	return true


func _quarantine(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(
			path, "%s.corrupt-%d" % [path, int(Time.get_unix_time_from_system())]
		)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


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
	_loaded = true
	_loaded_at = _saved_at(data)
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
	var welcomed: Variant = data.get("welcomed", [])
	if welcomed is Array:
		for user_id: Variant in welcomed:
			if user_id is String:
				mark_welcomed(user_id)
	var equipped_data: Dictionary = data.get("equipped", {})
	for user_id: Variant in equipped_data:
		if not (equipped_data[user_id] is Dictionary):
			continue
		for kind: String in KINDS:
			var item: Variant = equipped_data[user_id].get(kind, "")
			if item is String:
				equip(str(user_id), kind, item)
