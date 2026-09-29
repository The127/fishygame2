class_name ShopCatalog
extends RefCounted
## What the fish shop sells: the fish species and the palette colors, by chat name.
## Colors are the hand-picked [constant Contestant.PALETTE], so any mix a lobby ends up
## with stays easy to tell apart. [method assign_loadouts] settles who gets which color.

## Chat names of the species, in the order of [constant FishVisual.SPECIES].
const SPECIES_NAMES: Array[String] = ["trout", "puffer", "pike", "angelfish"]
## Chat names of the colors, in the order of [constant Contestant.PALETTE].
const COLOR_NAMES: Array[String] = [
	"red",
	"green",
	"yellow",
	"blue",
	"orange",
	"purple",
	"cyan",
	"magenta",
	"lime",
	"pink",
	"teal",
	"lavender",
	"brown",
	"beige",
	"maroon",
	"mint",
	"olive",
	"apricot",
	"navy",
	"grey",
]


## The color names as the shop lists them. With [param colorblind] each name is followed by
## its marking, e.g. "red (solid)", since the fish is told apart by that rather than by hue.
## Chat still takes the plain name.
static func color_labels(colorblind: bool) -> Array[String]:
	if not colorblind:
		return COLOR_NAMES
	var labels: Array[String] = []
	for i: int in COLOR_NAMES.size():
		labels.append(
			"%s (%s)" % [COLOR_NAMES[i], FishPalette.pattern_name(FishPalette.pattern_of(i, true))]
		)
	return labels


## Whether [param item] (case does not matter) is on sale as a [param kind].
static func has_item(kind: String, item: String) -> bool:
	return index_of(kind, item) >= 0


## Index into the species list or the palette, or -1 for an unknown name.
static func index_of(kind: String, item: String) -> int:
	var wanted: String = item.to_lower()
	if kind == ShopStore.KIND_SPECIES:
		return SPECIES_NAMES.find(wanted)
	if kind == ShopStore.KIND_COLOR:
		return COLOR_NAMES.find(wanted)
	return -1


## Gives every contestant the species and color they equipped in [param store], in the
## colorblind look (see [FishPalette]) when [param colorblind] is set. The color names and
## what viewers own stay the same either way.
## A viewer keeps their color unless an earlier joiner already holds it; then, like
## everyone without a bought color, they get their join slot color or, if that is taken,
## the first palette color nobody has. So no two fish share a color while the palette lasts.
static func assign_loadouts(
	contestants: Array[Contestant], store: ShopStore, colorblind: bool = false
) -> void:
	var taken: Dictionary = {}
	var settled: Dictionary = {}
	for i: int in contestants.size():
		var contestant: Contestant = contestants[i]
		var species: int = index_of(
			ShopStore.KIND_SPECIES, store.equipped(contestant.user_id, ShopStore.KIND_SPECIES)
		)
		if species >= 0:
			contestant.species = species
		var color: int = index_of(
			ShopStore.KIND_COLOR, store.equipped(contestant.user_id, ShopStore.KIND_COLOR)
		)
		if color >= 0 and not taken.has(color):
			taken[color] = true
			settled[i] = true
			contestant.set_look(color, colorblind)
	for i: int in contestants.size():
		if settled.has(i):
			continue
		var slot_color: int = i if i < Contestant.PALETTE.size() else -1
		if slot_color >= 0 and not taken.has(slot_color):
			taken[slot_color] = true
			contestants[i].set_look(i, colorblind)
			continue
		for free: int in Contestant.PALETTE.size():
			if not taken.has(free):
				taken[free] = true
				contestants[i].set_look(free, colorblind)
				break
