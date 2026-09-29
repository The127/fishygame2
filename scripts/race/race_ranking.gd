class_name RaceRanking
extends RefCounted
## Pure race ranking logic: finish order and timeout ranking. No physics or nodes.

var _ids: Array[int] = []
var _finish_order: Array[int] = []
var _finish_times: Dictionary = {}


func _init(ids: Array[int] = []) -> void:
	_ids = ids.duplicate()


## Records that a marble crossed the finish line. Returns its place (1-based),
## or 0 if the id is unknown or already finished.
func record_finish(id: int, time: float) -> int:
	if not _ids.has(id) or _finish_times.has(id):
		return 0
	_finish_order.append(id)
	_finish_times[id] = time
	return _finish_order.size()


func is_finished(id: int) -> bool:
	return _finish_times.has(id)


func finished_count() -> int:
	return _finish_order.size()


func total_count() -> int:
	return _ids.size()


func all_finished() -> bool:
	return not _ids.is_empty() and _finish_order.size() == _ids.size()


func get_unfinished_ids() -> Array[int]:
	var result: Array[int] = []
	for id: int in _ids:
		if not _finish_times.has(id):
			result.append(id)
	return result


## Full ranking. Finished marbles come first in finish order; the rest are
## ranked by `progress` (id -> float, higher is further along), ties by lower id.
## Each entry: {id, place, finished, time, progress}. time is -1.0 if unfinished.
func get_results(progress: Dictionary = {}) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for id: int in _finish_order:
		(
			results
			. append(
				{
					"id": id,
					"place": results.size() + 1,
					"finished": true,
					"time": _finish_times[id],
					"progress": float(progress.get(id, 1.0)),
				}
			)
		)
	var rest: Array[int] = get_unfinished_ids()
	rest.sort_custom(
		func(a: int, b: int) -> bool:
			var pa: float = float(progress.get(a, 0.0))
			var pb: float = float(progress.get(b, 0.0))
			if is_equal_approx(pa, pb):
				return a < b
			return pa > pb
	)
	for id: int in rest:
		(
			results
			. append(
				{
					"id": id,
					"place": results.size() + 1,
					"finished": false,
					"time": -1.0,
					"progress": float(progress.get(id, 0.0)),
				}
			)
		)
	return results
