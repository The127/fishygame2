class_name RaceTreasures
extends RefCounted
## The treasures lying on a [Race]'s map: placing them and handing them to the first fish in reach.

## A fish picked up a treasure worth `value` points. `kind` is a [enum Treasure.Kind].
signal collected(id: int, kind: int, value: int)

var treasures: Array[Treasure] = []

var _host: Node2D
var _marbles: Dictionary
## Callable(id: int) -> Marble, null when the fish is not racing.
var _live_marble: Callable


func _init(host: Node2D, marbles: Dictionary, live_marble: Callable) -> void:
	_host = host
	_marbles = marbles
	_live_marble = live_marble


## Lays out the track's treasures from `treasure_seed`.
func place(track: Track, treasure_seed: int) -> void:
	for spot: Dictionary in track.treasure_spots(treasure_seed):
		var treasure: Treasure = Treasure.new()
		treasure.kind = spot["kind"]
		_host.add_child(treasure)
		treasure.global_position = spot["position"]
		treasures.append(treasure)


func clear() -> void:
	for treasure: Treasure in treasures:
		if is_instance_valid(treasure):
			_host.remove_child(treasure)
			treasure.queue_free()
	treasures.clear()


## Treasures still lying on the map.
func left() -> int:
	return treasures.filter(func(t: Treasure) -> bool: return not t.collected).size()


## The first fish within reach takes each treasure (the lowest id if several touch at once).
func collect() -> void:
	for treasure: Treasure in treasures:
		if treasure.collected:
			continue
		var finder: Marble = null
		for id: int in _marbles:
			var marble: Marble = _live_marble.call(id)
			if (
				marble != null
				and marble.global_position.distance_to(treasure.global_position) <= Treasure.REACH
			):
				finder = marble
				break
		if finder != null:
			treasure.collect()
			collected.emit(finder.id, treasure.kind, treasure.value())
