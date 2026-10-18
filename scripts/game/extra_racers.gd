class_name ExtraRacers
extends RefCounted
## The racers that are nobody: the [ImpostorDuck] and the [CardboardCutouts]. They line up after
## the viewers' fish, race with real physics and stand on the podium where they finished, but
## bets, prizes, rivals, stats and the tournament are settled as if they had not raced.

var duck: ImpostorDuck = ImpostorDuck.new()
var cutouts: CardboardCutouts = CardboardCutouts.new()


## Lines up the duck (now and then, or as [param forced_duck] says) and the cutouts behind
## [param roster] viewers and returns the field size.
func line_up(roster: int, settings: GameSettings, forced_duck: Variant = null) -> int:
	var field: int = duck.line_up(roster, settings, forced_duck)
	return cutouts.line_up(field, roster, settings.cardboard_target(), settings.max_players)


## Dresses [param marble] as the duck or a cutout when it is one. Returns whether it was.
func dress(marble: Marble) -> bool:
	return duck.dress(marble) or cutouts.dress(marble)


## The race's [param results] without the extra racers, for everything that settles points.
func settle(results: Array[Dictionary]) -> Array[Dictionary]:
	return cutouts.settle(duck.settle(results))


## [param podium] (from the settled results) with the extra racers back where they finished.
func shown_podium(podium: Array[Dictionary], size: int) -> Array[Dictionary]:
	return duck.podium_with_duck(cutouts.podium_with_cutouts(podium, size), size)


## The name of the extra racer with marble [param id], or "" when it is a viewer's fish.
func name_of(id: int) -> String:
	if id >= 0 and id == duck.id:
		return ImpostorDuck.NAME
	return cutouts.names.get(id, "")


## The overlay line that says cutouts filled in this race, or "" when none did.
func cutout_notice() -> String:
	match cutouts.names.size():
		0:
			return ""
		1:
			return "A cardboard fish filled the empty slot"
	return "%d cardboard fish filled the empty slots" % cutouts.names.size()
