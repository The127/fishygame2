class_name FishPalette
extends RefCounted
## The colors and markings a fish can wear, by palette slot (the order of
## [constant Contestant.PALETTE] and [constant ShopCatalog.COLOR_NAMES]).
## The standard look is the hand-picked palette. The colorblind look gives every slot its
## own combination of one of four colors, chosen to stay apart under deuteranopia,
## protanopia and tritanopia, and one of five markings, so no two slots look alike even
## with color removed entirely. Slots that share a color differ in marking.

## Marking names, in the order of [enum FishVisual.Pattern].
const PATTERN_NAMES: Array[String] = ["solid", "striped", "spotted", "lined", "chevron"]

## The four colors of the colorblind look (blue, yellow, vermillion, pale grey): they differ
## in lightness as well as hue.
const BLUE: Color = Color("0072b2")
const YELLOW: Color = Color("f0e442")
const VERMILLION: Color = Color("d55e00")
const PALE: Color = Color("e8e8e8")

## Per slot: which color and which [enum FishVisual.Pattern]. Slots are grouped by the hue
## family of their name, so "navy" and "teal" both stay blue and "red" stays warm.
const COLORBLIND_LOOKS: Array[Dictionary] = [
	{"color": VERMILLION, "pattern": 0},  # red
	{"color": YELLOW, "pattern": 1},  # green
	{"color": YELLOW, "pattern": 0},  # yellow
	{"color": BLUE, "pattern": 0},  # blue
	{"color": VERMILLION, "pattern": 1},  # orange
	{"color": BLUE, "pattern": 1},  # purple
	{"color": BLUE, "pattern": 2},  # cyan
	{"color": PALE, "pattern": 1},  # magenta
	{"color": YELLOW, "pattern": 2},  # lime
	{"color": PALE, "pattern": 0},  # pink
	{"color": BLUE, "pattern": 3},  # teal
	{"color": PALE, "pattern": 2},  # lavender
	{"color": VERMILLION, "pattern": 2},  # brown
	{"color": YELLOW, "pattern": 3},  # beige
	{"color": VERMILLION, "pattern": 3},  # maroon
	{"color": PALE, "pattern": 3},  # mint
	{"color": YELLOW, "pattern": 4},  # olive
	{"color": VERMILLION, "pattern": 4},  # apricot
	{"color": BLUE, "pattern": 4},  # navy
	{"color": PALE, "pattern": 4},  # grey
]


## The fish color of a palette [param slot], wrapped. Past the standard palette a slot
## is darkened, as [method Contestant.color_for_slot] does.
static func color_of(slot: int, colorblind: bool) -> Color:
	if not colorblind:
		return Contestant.color_for_slot(slot)
	var base: Color = COLORBLIND_LOOKS[posmod(slot, COLORBLIND_LOOKS.size())]["color"]
	return base.darkened(0.3) if slot >= COLORBLIND_LOOKS.size() else base


## The [enum FishVisual.Pattern] of a palette [param slot]. The standard look is unmarked.
static func pattern_of(slot: int, colorblind: bool) -> int:
	if not colorblind:
		return FishVisual.Pattern.SOLID
	return COLORBLIND_LOOKS[posmod(slot, COLORBLIND_LOOKS.size())]["pattern"]


## Name of a marking, for chat.
static func pattern_name(pattern: int) -> String:
	return PATTERN_NAMES[posmod(pattern, PATTERN_NAMES.size())]
