class_name RaceRounds
extends RefCounted
## Pure lap and elimination logic for a looping map: counts how often each fish has crossed the
## lap line and decides who is cut after each lap. No physics or nodes.
##
## A fish is fed its position on the loop as a fraction in [0, 1) of one lap (0 is the lap line).
## A jump from the end of the loop to the start is a crossing of the line, a jump the other way is
## a crossing backwards. After lap `r` (for r below [member laps]) the slowest third of the fish
## still racing are cut: as soon as everyone else has crossed the line `r` times, the rest are out.
## The last lap is a plain finish: a fish that has completed [member laps] laps is done.

## Laps to race. One means no rounds at all.
var laps: int = 1

var _ids: Array[int] = []
## id -> laps completed (net crossings of the line). A fish that has not crossed yet has 0.
var _done: Dictionary[int, int] = {}
var _fraction: Dictionary[int, float] = {}
## id -> round after which the fish was cut (1 is the first cut).
var _cut_in: Dictionary[int, int] = {}
var _round: int = 1


func _init(ids: Array[int] = [], p_laps: int = 1) -> void:
	_ids = ids.duplicate()
	laps = maxi(p_laps, 1)


## How many of `alive` fish the next cut removes: a third, rounded down, and never the last two.
static func cut_count(alive: int) -> int:
	return alive / 3 if alive >= 3 else 0


## Feeds the fish's current position on the loop. Returns true if it crossed the line forwards.
## A fish seen for the first time starts wherever it is, so a grid behind the line counts nothing.
func update(id: int, fraction: float) -> bool:
	var crossed: bool = false
	if _fraction.has(id):
		var before: float = _fraction[id]
		if before > 0.75 and fraction < 0.25:
			_done[id] = _done.get(id, 0) + 1
			crossed = true
		elif before < 0.25 and fraction > 0.75:
			_done[id] = _done.get(id, 0) - 1
	else:
		_done[id] = 0
	_fraction[id] = fraction
	return crossed


## Laps the fish has completed so far.
func laps_done(id: int) -> int:
	return _done.get(id, 0)


## Laps plus the part of the current lap, so it rises steadily along the whole race.
func total(id: int) -> float:
	return float(_done.get(id, 0)) + float(_fraction.get(id, 0.0))


## Whether the fish has completed every lap.
func has_finished(id: int) -> bool:
	return _done.get(id, 0) >= laps


## The round whose cut is next (1 after the first lap), or 0 once no cut is left.
func next_round() -> int:
	return _round if _round < laps else 0


## Whether the fish was cut, and after which round (0 if it was not).
func cut_round(id: int) -> int:
	return _cut_in.get(id, 0)


func is_cut(id: int) -> bool:
	return _cut_in.has(id)


## Decides whether the cut of the next round is due. `racing` is every fish still in the race
## (not cut, not out for another reason). Returns the ids that are cut now, in rising order, or
## an empty array. Call it after feeding the frame's positions.
func take_cut(racing: Array[int]) -> Array[int]:
	var cut: Array[int] = []
	var round_number: int = next_round()
	if round_number == 0:
		return cut
	var keep: int = racing.size() - cut_count(racing.size())
	var through: int = 0
	for id: int in racing:
		if laps_done(id) >= round_number:
			through += 1
	if keep >= racing.size() or through < keep:
		return cut
	for id: int in racing:
		if laps_done(id) < round_number:
			cut.append(id)
			_cut_in[id] = round_number
	cut.sort()
	_round += 1
	return cut
