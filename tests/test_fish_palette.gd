extends GutTest
## The colorblind look: every slot is distinguishable by color or by marking, and the four
## colors stay apart when color vision is reduced.

## Machado et al. (2009) severity 1.0 matrices for linear RGB.
const DEUTAN: Array = [
	[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]
]
const PROTAN: Array = [
	[0.152286, 1.052583, -0.204868],
	[0.114503, 0.786281, 0.099216],
	[-0.003882, -0.048116, 1.051998]
]
const TRITAN: Array = [
	[1.255528, -0.076749, -0.178779],
	[-0.078411, 0.930809, 0.147602],
	[0.004733, 0.691367, 0.303900]
]
const MIN_SEPARATION: float = 0.15


func test_there_is_one_look_per_shop_color() -> void:
	assert_eq(FishPalette.COLORBLIND_LOOKS.size(), Contestant.PALETTE.size())
	assert_eq(FishPalette.COLORBLIND_LOOKS.size(), ShopCatalog.COLOR_NAMES.size())


func test_every_slot_has_a_unique_color_and_pattern_combination() -> void:
	var seen: Dictionary = {}
	for slot: int in FishPalette.COLORBLIND_LOOKS.size():
		var key: String = (
			"%s/%d"
			% [FishPalette.color_of(slot, true).to_html(), FishPalette.pattern_of(slot, true)]
		)
		assert_false(seen.has(key), "slot %d is unique" % slot)
		seen[key] = true


func test_slots_sharing_a_color_differ_in_pattern() -> void:
	for a: int in FishPalette.COLORBLIND_LOOKS.size():
		for b: int in range(a + 1, FishPalette.COLORBLIND_LOOKS.size()):
			if FishPalette.color_of(a, true) == FishPalette.color_of(b, true):
				assert_ne(FishPalette.pattern_of(a, true), FishPalette.pattern_of(b, true))


func test_patterns_are_valid_and_all_used() -> void:
	var used: Dictionary = {}
	for slot: int in FishPalette.COLORBLIND_LOOKS.size():
		var pattern: int = FishPalette.pattern_of(slot, true)
		assert_between(pattern, 0, FishVisual.Pattern.size() - 1)
		used[pattern] = true
	assert_eq(used.size(), FishVisual.Pattern.size())
	assert_eq(FishPalette.PATTERN_NAMES.size(), FishVisual.Pattern.size())


func test_standard_look_is_the_old_palette_without_markings() -> void:
	for slot: int in Contestant.PALETTE.size():
		assert_eq(FishPalette.color_of(slot, false), Contestant.PALETTE[slot])
		assert_eq(FishPalette.pattern_of(slot, false), FishVisual.Pattern.SOLID)


func test_slots_past_the_palette_wrap_and_darken() -> void:
	var n: int = FishPalette.COLORBLIND_LOOKS.size()
	assert_eq(FishPalette.pattern_of(n + 2, true), FishPalette.pattern_of(2, true))
	assert_eq(FishPalette.color_of(n + 2, true), FishPalette.color_of(2, true).darkened(0.3))


func test_colors_stay_apart_under_each_kind_of_color_blindness() -> void:
	var colors: Array[Color] = [
		FishPalette.BLUE, FishPalette.YELLOW, FishPalette.VERMILLION, FishPalette.PALE
	]
	for matrix: Array in [DEUTAN, PROTAN, TRITAN, [[1, 0, 0], [0, 1, 0], [0, 0, 1]]]:
		for a: int in colors.size():
			for b: int in range(a + 1, colors.size()):
				var gap: float = _distance(
					_simulate(colors[a], matrix), _simulate(colors[b], matrix)
				)
				assert_gt(gap, MIN_SEPARATION, "colors %d and %d under %s" % [a, b, matrix])


func test_pattern_names_cover_every_pattern() -> void:
	assert_eq(FishPalette.pattern_name(0), "solid")
	assert_eq(FishPalette.pattern_name(FishVisual.Pattern.CHEVRONS), "chevron")


func _simulate(color: Color, matrix: Array) -> Color:
	var rgb: Color = color.srgb_to_linear()
	var v: Array[float] = [rgb.r, rgb.g, rgb.b]
	var out: Array[float] = []
	for row: Array in matrix:
		out.append(clampf(row[0] * v[0] + row[1] * v[1] + row[2] * v[2], 0.0, 1.0))
	return Color(out[0], out[1], out[2]).linear_to_srgb()


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
