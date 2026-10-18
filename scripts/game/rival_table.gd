class_name RivalTable
extends RefCounted
## Who is whose rival, keyed by Twitch user id (see [Rivals]). Saved inside the points file
## (see PointsStore), so it shares that file's atomic writes, backup and localStorage mirror.

## user_id -> user_id of the viewer's rival.
var _rivals: Dictionary = {}


## The user id of the viewer's rival, or "" when they have none.
func get_rival(user_id: String) -> String:
	return str(_rivals.get(user_id, ""))


## Makes [param rival_id] the viewer's rival, replacing any earlier one. An empty id clears it.
func set_rival(user_id: String, rival_id: String) -> void:
	if rival_id.is_empty():
		_rivals.erase(user_id)
	else:
		_rivals[user_id] = rival_id


func to_dict() -> Dictionary:
	return _rivals.duplicate()


## Replaces the table. Keeps only non-empty string ids, and no viewer as their own rival.
func load_dict(raw: Variant) -> void:
	_rivals = {}
	if not raw is Dictionary:
		return
	for user_id: Variant in raw:
		var value: Variant = raw[user_id]
		if value is String and not (value as String).is_empty() and value != str(user_id):
			_rivals[str(user_id)] = value
