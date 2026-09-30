class_name PointsStore
extends RefCounted
## Viewer point balances keyed by Twitch user id, optionally persisted as JSON.
## A viewer without an entry has [member starting_balance]. A backend can replace
## this class later; callers only use the methods below.
##
## Saves are atomic (temp file, then rename) and keep the previous file as a backup.
## Stakes are points a viewer has bet or spent on chaos this round but not yet settled: they are saved in the same
## write as the balances so a crash or refresh mid-round can refund them.
##
## On the web the file lives in IndexedDB, which the engine flushes a few seconds after a write,
## so a reload right after settlement could lose it. Every save is therefore also mirrored to
## localStorage (synchronous) and the newer of the two copies wins on load.
##
## Also keeps the all-time leaderboard data: race wins per viewer and the last display name
## seen for each viewer. Version 1 files have neither; they load with no wins and no names.
## Version 3 adds [member stats], the per-viewer counters for "#stats"; older files load with none.

const FORMAT_VERSION: int = 3
const DEFAULT_PATH: String = "user://points.json"
## Longest display name kept for the leaderboard.
const MAX_NAME_LENGTH: int = 32
## Balances are clamped to this so payouts can never overflow a 64-bit int.
const MAX_BALANCE: int = 1_000_000_000_000

var starting_balance: int = 1000
## Lifetime counters per viewer, saved in the same file as the balances.
var stats: ViewerStats = ViewerStats.new()
## Empty means in-memory only.
var save_path: String = ""

var _balances: Dictionary = {}
## user_id -> points currently held in open bets.
var _stakes: Dictionary = {}
## Save time (unix seconds) of the copy that was loaded last; 0 if it had none.
var _loaded_at: float = 0.0
## user_id -> races won.
var _wins: Dictionary = {}
## user_id -> last known display name.
var _names: Dictionary = {}


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


## Releases [param amount] of the viewer's stake (it was settled or refunded by the caller).
## Bets and chaos spend both add to the same stake, so each releases only its own part.
func release_stake(user_id: String, amount: int) -> void:
	var left: int = stake_of(user_id) - amount
	if left > 0:
		_stakes[user_id] = left
	else:
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


func get_wins(user_id: String) -> int:
	return int(_wins.get(user_id, 0))


func add_win(user_id: String) -> int:
	# A winner is always ranked on the points board, even without ever betting.
	_balances[user_id] = get_balance(user_id)
	_wins[user_id] = mini(get_wins(user_id) + 1, MAX_BALANCE)
	return get_wins(user_id)


## Remembers how to show the viewer on the leaderboard. Empty names are ignored.
## Returns true if the stored name changed.
func set_name(user_id: String, display_name: String) -> bool:
	var trimmed: String = display_name.strip_edges().left(MAX_NAME_LENGTH)
	if trimmed.is_empty() or _names.get(user_id, "") == trimmed:
		return false
	_names[user_id] = trimmed
	return true


## The id of the viewer last seen under this name (ignoring case and a leading "@"), or "".
## If several viewers share a name the lowest id wins, so the answer is stable.
func find_by_name(display_name: String) -> String:
	var wanted: String = display_name.strip_edges().trim_prefix("@").to_lower()
	if wanted.is_empty():
		return ""
	var found: String = ""
	for user_id: String in _names:
		if str(_names[user_id]).to_lower() == wanted and (found.is_empty() or user_id < found):
			found = user_id
	return found


## Whether the viewer is ranked on a board (has a balance or a win).
func has_entry(user_id: String) -> bool:
	return _balances.has(user_id) or _wins.has(user_id)


## The last name seen for the viewer, or "Viewer 1234" (last digits of the id) if none was
## ever recorded, so the board never shows a raw Twitch id.
func get_name(user_id: String) -> String:
	if _names.has(user_id):
		return str(_names[user_id])
	return "Viewer %s" % user_id.right(4)


## Viewers with the most points, best first: [{user_id, name, points, wins}].
## Only viewers the store has an entry for (they bet or won at least once) are ranked.
func top_by_points(count: int) -> Array[Dictionary]:
	return _top(_balances, "points", count)


## Viewers with the most race wins, best first. Viewers without a win are left out.
func top_by_wins(count: int) -> Array[Dictionary]:
	return _top(_wins, "wins", count)


## Loads balances from [member save_path]. A missing file is not an error (returns true).
## If the main file is unreadable the backup is used (returns true); if that fails too the
## unreadable file is moved aside, the store is left empty and false is returned.
func load_from_disk() -> bool:
	_balances.clear()
	_stakes.clear()
	_loaded_at = 0.0
	_wins.clear()
	_names.clear()
	stats.load_dict({})
	if save_path.is_empty():
		return true
	var ok: bool = _load_files()
	# The mirror can hold a save the browser had not flushed to IndexedDB yet.
	var mirrored: Dictionary = _parse(_mirror_read())
	if not mirrored.is_empty() and _saved_at(mirrored) > _loaded_at:
		_apply(mirrored)
		return true
	return ok


func _load_files() -> bool:
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
	var text: String = (
		JSON
		. stringify(
			{
				"version": FORMAT_VERSION,
				"saved_at": Time.get_unix_time_from_system(),
				"balances": _balances,
				"stakes": _stakes,
				"wins": _wins,
				"names": _names,
				"stats": stats.to_dict(),
			}
		)
	)
	_mirror_write(text)
	file.store_string(text)
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


## Whether saves are mirrored to localStorage. Only true in the web build.
func _mirror_enabled() -> bool:
	return OS.has_feature("web")


func _mirror_key() -> String:
	return "fishygame2.points:" + save_path


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
	var data: Dictionary = _read(path)
	if data.is_empty():
		return false
	_apply(data)
	return true


func _saved_at(data: Dictionary) -> float:
	var value: Variant = data.get("saved_at", 0.0)
	return float(value) if value is float or value is int else 0.0


func _apply(data: Dictionary) -> void:
	_balances = _clean(data["balances"])
	_stakes = _clean(data.get("stakes", {}))
	_loaded_at = _saved_at(data)
	# Cosmetic data: a bad value here must not cost anyone their balance.
	var wins: Variant = data.get("wins", {})
	_wins = _clean(wins) if wins is Dictionary else {}
	var names: Variant = data.get("names", {})
	_names = _clean_names(names) if names is Dictionary else {}
	stats.load_dict(data.get("stats", {}))


## Returns the parsed save data, or an empty dictionary if the file is missing or invalid.
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	return _parse(file.get_as_text())


## Returns the parsed save data, or an empty dictionary if the text is empty or invalid.
func _parse(text: String) -> Dictionary:
	var json := JSON.new()
	if text.is_empty() or json.parse(text) != OK:
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


func _clean_names(raw: Dictionary) -> Dictionary:
	var cleaned: Dictionary = {}
	for user_id: Variant in raw:
		var value: Variant = raw[user_id]
		if value is String and not (value as String).strip_edges().is_empty():
			cleaned[str(user_id)] = (value as String).strip_edges().left(MAX_NAME_LENGTH)
	return cleaned


## Ranks the ids of [param source] by [param key] ("points" or "wins"), then name, then id.
## Rows with nothing to show (a win count of zero) are left out.
func _top(source: Dictionary, key: String, count: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for user_id: String in source:
		var row: Dictionary = {
			"user_id": user_id,
			"name": get_name(user_id),
			"points": get_balance(user_id),
			"wins": get_wins(user_id),
		}
		if key == "points" or int(row[key]) > 0:
			rows.append(row)
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a[key] != b[key]:
				return a[key] > b[key]
			var a_name: String = (a["name"] as String).to_lower()
			var b_name: String = (b["name"] as String).to_lower()
			if a_name != b_name:
				return a_name < b_name
			return (a["user_id"] as String) < (b["user_id"] as String)
	)
	return rows.slice(0, maxi(count, 0))


func _quarantine(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(
			path, "%s.corrupt-%d" % [path, int(Time.get_unix_time_from_system())]
		)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
