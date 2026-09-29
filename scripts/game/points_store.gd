class_name PointsStore
extends RefCounted
## Viewer point balances keyed by Twitch user id, optionally persisted as JSON.
## A viewer without an entry has [member starting_balance]. A backend can replace
## this class later; callers only use the methods below.
##
## Saves are atomic (temp file, then rename) and keep the previous file as a backup.
## Stakes are points a viewer has bet but not yet settled: they are saved in the same
## write as the balances so a crash or refresh mid-round can refund them.

const FORMAT_VERSION: int = 1
## Balances are clamped to this so payouts can never overflow a 64-bit int.
const MAX_BALANCE: int = 1_000_000_000_000

var starting_balance: int = 1000
## Empty means in-memory only.
var save_path: String = ""

var _balances: Dictionary = {}
## user_id -> points currently held in open bets.
var _stakes: Dictionary = {}


func _init(p_save_path: String = "", p_starting_balance: int = 1000) -> void:
	save_path = p_save_path
	starting_balance = p_starting_balance


func get_balance(user_id: String) -> int:
	return int(_balances.get(user_id, starting_balance))


func set_balance(user_id: String, amount: int) -> void:
	_balances[user_id] = clampi(amount, 0, MAX_BALANCE)


## Adds (or with a negative amount, removes) points. Never goes below zero.
func add(user_id: String, amount: int) -> int:
	# Clamp first so the sum itself cannot overflow.
	set_balance(user_id, get_balance(user_id) + clampi(amount, -MAX_BALANCE, MAX_BALANCE))
	return get_balance(user_id)


## Removes points only if the viewer can afford it.
func try_debit(user_id: String, amount: int) -> bool:
	if amount < 0 or amount > get_balance(user_id):
		return false
	set_balance(user_id, get_balance(user_id) - amount)
	return true


## Records that [param amount] of the viewer's points are held in an open bet.
func add_stake(user_id: String, amount: int) -> void:
	_stakes[user_id] = int(_stakes.get(user_id, 0)) + amount


## Forgets the viewer's stake (the bet was settled or refunded by the caller).
func clear_stake(user_id: String) -> void:
	_stakes.erase(user_id)


func stake_of(user_id: String) -> int:
	return int(_stakes.get(user_id, 0))


## Gives every held stake back to its owner. Used on load: a round cannot be resumed
## after a refresh, so open bets are refunded. Returns the number of refunded viewers.
func refund_stakes() -> int:
	var count: int = _stakes.size()
	for user_id: String in _stakes:
		add(user_id, int(_stakes[user_id]))
	_stakes.clear()
	return count


## Loads balances from [member save_path]. A missing file is not an error (returns true).
## If the main file is unreadable the backup is used (returns true); if that fails too the
## unreadable file is moved aside, the store is left empty and false is returned.
func load_from_disk() -> bool:
	_balances.clear()
	_stakes.clear()
	if save_path.is_empty():
		return true
	if not FileAccess.file_exists(save_path) and not FileAccess.file_exists(_backup_path()):
		return true
	if _load_file(save_path):
		return true
	push_warning("Points file %s is unusable, trying recovery files" % save_path)
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
	var tmp: String = _tmp_path()
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s" % tmp)
		return false
	file.store_string(
		JSON.stringify({"version": FORMAT_VERSION, "balances": _balances, "stakes": _stakes})
	)
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		push_warning("Could not write %s" % tmp)
		return false
	# Only a readable current file is worth keeping as the backup.
	if _read(save_path).size() > 0:
		_remove(_backup_path())
		if DirAccess.rename_absolute(save_path, _backup_path()) != OK:
			push_warning("Could not back up %s" % save_path)
	else:
		_quarantine(save_path)
	if DirAccess.rename_absolute(tmp, save_path) != OK:
		push_warning("Could not replace %s" % save_path)
		return false
	return true


func _tmp_path() -> String:
	return save_path + ".tmp"


func _backup_path() -> String:
	return save_path + ".bak"


func _load_file(path: String) -> bool:
	var data: Dictionary = _read(path)
	if data.is_empty():
		return false
	_balances = _clean(data["balances"])
	_stakes = _clean(data.get("stakes", {}))
	return true


## Returns the parsed save data, or an empty dictionary if the file is missing or invalid.
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = json.data
	if not (parsed is Dictionary) or not (parsed.get("balances") is Dictionary):
		return {}
	if not (parsed.get("stakes", {}) is Dictionary):
		return {}
	return parsed


## Keeps only finite numeric values, clamped to the valid range.
func _clean(raw: Dictionary) -> Dictionary:
	var cleaned: Dictionary = {}
	for user_id: Variant in raw:
		var value: Variant = raw[user_id]
		if (value is float and is_finite(value)) or value is int:
			cleaned[str(user_id)] = clampi(
				int(clampf(float(value), 0.0, float(MAX_BALANCE))), 0, MAX_BALANCE
			)
	return cleaned


func _quarantine(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(
			path, "%s.corrupt-%d" % [path, int(Time.get_unix_time_from_system())]
		)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
