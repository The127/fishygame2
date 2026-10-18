class_name ImpostorDuck
extends RefCounted
## The impostor duck: now and then a rubber duck lines up with the fish and races as one, with
## real physics. The game never admits it is a duck.
##
## It is no viewer, so it earns nothing: bets, prizes, rivals, stats and the tournament are
## settled from [method scored], the results without it. Only the podium shows where it really
## placed ([method display_podium]), with a straight face.

## The name on its label and on the podium.
const NAME: String = "DefinitelyAFish"
## Its look in a podium entry, like a viewer's fish.
const COLOR: Color = Color(0.95, 0.78, 0.16)

## Marble id of the duck in the current race, -1 when it is not racing.
var id: int = -1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _results: Array[Dictionary] = []


func _init() -> void:
	_rng.randomize()


## Decides whether the duck races with [param roster] fish and returns the field size. It lines
## up last, after every roster id. [param forced] true or false overrides the settings' chance.
## Never when the roster already fills the largest field the maps are tested with.
func line_up(roster: int, settings: GameSettings, forced: Variant = null) -> int:
	var racing: bool = settings.impostor_duck and joins(_rng, settings.impostor_chance)
	if forced != null:
		racing = bool(forced)
	elif roster >= int(GameSettings.field_of("max_players")["max"]):
		racing = false
	id = roster if racing else -1
	return roster + (1 if racing else 0)


## Makes [param marble] look like the duck when it is the duck. Returns whether it was.
func dress(marble: Marble) -> bool:
	if marble.id != id:
		return false
	marble.impostor = true
	marble.color = COLOR
	marble.label_text = NAME
	return true


## Keeps the race's full [param results] for [method show_podium] and returns them without
## the duck, for everything that settles points.
func settle(results: Array[Dictionary]) -> Array[Dictionary]:
	_results = results
	return scored(results, id)


## [param podium] (from the settled results) with the duck put back where it finished.
func podium_with_duck(podium: Array[Dictionary], size: int) -> Array[Dictionary]:
	return display_podium(podium, _results, id, size)


## Whether the duck races this time, at [param chance_percent] (0 never, 100 always).
static func joins(rng: RandomNumberGenerator, chance_percent: int) -> bool:
	return chance_percent > 0 and rng.randi_range(1, 100) <= chance_percent


## [param results] (from [signal Race.race_finished]) without the duck's entry, every place
## behind it moved up one. [param duck_id] below 0 means no duck raced.
static func scored(results: Array[Dictionary], duck_id: int) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	for r: Dictionary in results:
		if int(r["id"]) == duck_id:
			continue
		var entry: Dictionary = r.duplicate()
		entry["place"] = kept.size() + 1
		kept.append(entry)
	return kept


## The podium as shown: [param podium] (built from the scored results) with the duck put back
## in its real place when it finished in the top [param size], the fish behind it moved down
## one and any pushed past the last step dropped.
static func display_podium(
	podium: Array[Dictionary], results: Array[Dictionary], duck_id: int, size: int
) -> Array[Dictionary]:
	if duck_id < 0:
		return podium
	var place: int = 0
	var time: float = 0.0
	for r: Dictionary in results:
		if int(r["id"]) == duck_id:
			place = int(r["place"]) if bool(r["finished"]) else 0
			time = float(r["time"])
			break
	if place < 1 or place > size:
		return podium
	var shown: Array[Dictionary] = []
	for fish: Dictionary in podium:
		var moved: Dictionary = fish.duplicate()
		if int(moved["place"]) >= place:
			moved["place"] = int(moved["place"]) + 1
		if int(moved["place"]) <= size:
			shown.append(moved)
	shown.insert(mini(place - 1, shown.size()), entry(duck_id, place, time))
	return shown


## A podium entry for the duck, shaped like the ones [GameFlow] builds for viewers. Its
## user_id is empty: it is nobody.
static func entry(duck_id: int, place: int, time: float) -> Dictionary:
	return {
		"id": duck_id,
		"place": place,
		"user_id": "",
		"name": NAME,
		"color": COLOR,
		"species": 0,
		"pattern": 0,
		"accessory": 0,
		"skin": 0,
		"impostor": true,
		"time": time,
		"finished": true,
	}
