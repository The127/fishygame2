class_name CardboardCutouts
extends RefCounted
## Filler racers for a thin field: flat cardboard cutout fish that take the empty slots when
## only a few viewers joined. They tumble down the course with real physics (see
## [member Marble.cardboard]).
##
## Like the [ImpostorDuck] they are nobody: bets, prizes, rivals, stats and the tournament are
## settled from [method settle], the results without them. Only the podium shows where they
## really placed ([method podium_with_cutouts]).

## Cutouts only fill in when fewer viewers than this joined.
const BELOW_VIEWERS: int = 3
const NAMES: Array[String] = [
	"Cardboard Carl",
	"Boxy Barb",
	"Flat Fred",
	"Corrugated Cora",
	"Tape Tim",
	"Flimsy Phil",
	"Cutout Cathy",
	"Recycled Rick",
	"Soggy Sam",
	"Papier Pierre",
]
## Their look in a podium entry, like a viewer's fish.
const COLOR: Color = Color("d2a46c")

## Marble id -> name of every cutout in the current race.
var names: Dictionary[int, String] = {}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _results: Array[Dictionary] = []


func _init() -> void:
	_rng.randomize()


## Lines up the cutouts for a race of [param field] fish, [param viewers] of them viewers, and
## returns the new field size. They take the ids after [param field], with names drawn at random.
## [param target] is the field size to fill up to, 0 for none.
func line_up(field: int, viewers: int, target: int, max_players: int) -> int:
	names.clear()
	var picked: Array[String] = NAMES.duplicate()
	for i: int in range(picked.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: String = picked[i]
		picked[i] = picked[j]
		picked[j] = swap
	var count: int = mini(count_for(viewers, target, max_players), picked.size())
	for i: int in count:
		names[field + i] = picked[i]
	return field + count


## Makes [param marble] a cardboard cutout when it is one. Returns whether it was.
func dress(marble: Marble) -> bool:
	if not names.has(marble.id):
		return false
	marble.cardboard = true
	marble.color = COLOR
	marble.label_text = names[marble.id]
	return true


## Keeps [param results] for [method podium_with_cutouts] and returns them without the cutouts,
## every place behind one moved up.
func settle(results: Array[Dictionary]) -> Array[Dictionary]:
	_results = results
	var scored: Array[Dictionary] = results
	for id: int in names:
		scored = ImpostorDuck.scored(scored, id)
	return scored


## [param podium] (from the settled results) with every cutout put back where it finished.
func podium_with_cutouts(podium: Array[Dictionary], size: int) -> Array[Dictionary]:
	# Best placed first, so each one goes in among fish that were all ahead of it or behind.
	var placed: Array[Dictionary] = _results.filter(
		func(r: Dictionary) -> bool: return names.has(int(r["id"]))
	)
	var shown: Array[Dictionary] = podium
	for r: Dictionary in placed:
		var id: int = int(r["id"])
		shown = ImpostorDuck.display_podium(shown, _results, id, size, entry.bind(names[id]))
	return shown


## How many cutouts join [param viewers] real racers to fill the field up to [param target]
## fish, never past [param max_players]. 0 when [param target] is 0 (off) or enough viewers
## joined.
static func count_for(viewers: int, target: int, max_players: int) -> int:
	if target <= 0 or viewers >= BELOW_VIEWERS:
		return 0
	return maxi(mini(target, max_players) - viewers, 0)


## A podium entry for a cutout, shaped like the ones [GameFlow] builds for viewers. Its user_id
## is empty: it is nobody.
static func entry(id: int, place: int, time: float, name: String) -> Dictionary:
	return {
		"id": id,
		"place": place,
		"user_id": "",
		"name": name,
		"color": COLOR,
		"species": 0,
		"pattern": 0,
		"accessory": 0,
		"skin": 0,
		"cardboard": true,
		"time": time,
		"finished": true,
	}
