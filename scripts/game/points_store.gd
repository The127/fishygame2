class_name PointsStore
extends RefCounted
## Viewer point balances keyed by Twitch user id, optionally persisted as JSON.
## A viewer without an entry has [member starting_balance]. A backend can replace
## this class later; callers only use the methods below.

const FORMAT_VERSION: int = 1

var starting_balance: int = 1000
## Empty means in-memory only.
var save_path: String = ""

var _balances: Dictionary = {}


func _init(p_save_path: String = "", p_starting_balance: int = 1000) -> void:
	save_path = p_save_path
	starting_balance = p_starting_balance


func get_balance(user_id: String) -> int:
	return int(_balances.get(user_id, starting_balance))


func set_balance(user_id: String, amount: int) -> void:
	_balances[user_id] = maxi(amount, 0)


## Adds (or with a negative amount, removes) points. Never goes below zero.
func add(user_id: String, amount: int) -> int:
	set_balance(user_id, get_balance(user_id) + amount)
	return get_balance(user_id)


## Removes points only if the viewer can afford it.
func try_debit(user_id: String, amount: int) -> bool:
	if amount < 0 or amount > get_balance(user_id):
		return false
	set_balance(user_id, get_balance(user_id) - amount)
	return true


## Loads balances from [member save_path]. A missing file is not an error (returns true);
## an unreadable or corrupt one leaves the store empty and returns false.
func load_from_disk() -> bool:
	_balances.clear()
	if save_path.is_empty() or not FileAccess.file_exists(save_path):
		return true
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Could not read %s" % save_path)
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("Ignoring corrupt points file %s" % save_path)
		return false
	var parsed: Variant = json.data
	if not (parsed is Dictionary) or not (parsed.get("balances") is Dictionary):
		push_warning("Ignoring corrupt points file %s" % save_path)
		return false
	var balances: Dictionary = parsed["balances"]
	for user_id: Variant in balances:
		var value: Variant = balances[user_id]
		if value is float or value is int:
			_balances[str(user_id)] = maxi(int(value), 0)
	return true


func save_to_disk() -> bool:
	if save_path.is_empty():
		return true
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s" % save_path)
		return false
	file.store_string(JSON.stringify({"version": FORMAT_VERSION, "balances": _balances}))
	return true
