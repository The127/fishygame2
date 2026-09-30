class_name Contestant
extends RefCounted
## A viewer who joined the lobby. Keyed by the stable Twitch user id.

## Hand-picked colors that stay easy to tell apart on a busy track. Assigned by join order.
const PALETTE: Array[Color] = [
	Color("e6194b"),
	Color("3cb44b"),
	Color("ffe119"),
	Color("4363d8"),
	Color("f58231"),
	Color("911eb4"),
	Color("42d4f4"),
	Color("f032e6"),
	Color("bfef45"),
	Color("fabed4"),
	Color("469990"),
	Color("dcbeff"),
	Color("9a6324"),
	Color("fffac8"),
	Color("800000"),
	Color("aaffc3"),
	Color("808000"),
	Color("ffd8b1"),
	Color("000075"),
	Color("a9a9a9"),
]

var user_id: String = ""
var display_name: String = ""
var color: Color = Color.WHITE
## Index into [constant FishVisual.SPECIES], wrapped.
var species: int = 0
## Slot in [constant PALETTE] (and the shop's color names) this fish wears.
var palette_slot: int = 0
## A [enum FishVisual.Pattern]; only marked in the colorblind look.
var pattern: int = 0
## A [enum FishSkin.Kind] from the shop's premium colors; 0 wears the palette color.
var skin: int = 0
## A [enum FishAccessory.Kind] from the shop; 0 is none.
var accessory: int = 0
## A [enum FishTrail.Kind] from the shop; 0 is the plain bubble trail.
var trail: int = 0


static func create(p_user_id: String, p_display_name: String, slot: int = 0) -> Contestant:
	var contestant := Contestant.new()
	contestant.user_id = p_user_id
	contestant.display_name = p_display_name
	contestant.set_look(slot, false)
	contestant.species = posmod(slot, FishVisual.SPECIES.size())
	return contestant


## Color for the n-th joiner of a lobby. Past the palette it repeats, darkened.
static func color_for_slot(slot: int) -> Color:
	var base: Color = PALETTE[posmod(slot, PALETTE.size())]
	return base.darkened(0.3) if slot >= PALETTE.size() else base


## Wears palette [param slot], in the colorblind look when [param colorblind] is set.
func set_look(slot: int, colorblind: bool) -> void:
	palette_slot = posmod(slot, PALETTE.size())
	color = FishPalette.color_of(slot, colorblind)
	pattern = FishPalette.pattern_of(slot, colorblind)
