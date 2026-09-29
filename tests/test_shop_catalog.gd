extends GutTest


func test_names_match_the_art() -> void:
	assert_eq(ShopCatalog.SPECIES_NAMES.size(), FishVisual.SPECIES.size())
	assert_eq(ShopCatalog.COLOR_NAMES.size(), Contestant.PALETTE.size())
	var seen: Dictionary = {}
	for name: String in ShopCatalog.SPECIES_NAMES + ShopCatalog.COLOR_NAMES:
		assert_false(seen.has(name), "%s is unique" % name)
		seen[name] = true


func test_lookup_ignores_case() -> void:
	assert_eq(ShopCatalog.index_of(ShopStore.KIND_COLOR, "Blue"), 3)
	assert_eq(ShopCatalog.index_of(ShopStore.KIND_SPECIES, "PIKE"), 2)
	assert_eq(ShopCatalog.index_of(ShopStore.KIND_COLOR, "pike"), -1)
	assert_false(ShopCatalog.has_item("hat", "red"))


func test_default_loadout_is_the_slot() -> void:
	var roster: Array[Contestant] = _roster(3)
	ShopCatalog.assign_loadouts(roster, ShopStore.new())
	for i: int in roster.size():
		assert_eq(roster[i].color, Contestant.PALETTE[i])
		assert_eq(roster[i].species, i)


func test_equipped_species_and_color_are_applied() -> void:
	var store := _store_with({"1": {"color": "blue", "species": "pike"}})
	var roster: Array[Contestant] = _roster(3)
	ShopCatalog.assign_loadouts(roster, store)
	assert_eq(roster[1].color, Contestant.PALETTE[3])
	assert_eq(roster[1].species, 2)
	assert_eq(roster[0].color, Contestant.PALETTE[0])


func test_bought_color_beats_a_default_of_someone_else() -> void:
	# Viewer 0 buys viewer 2's default color (yellow); viewer 2 moves to a free one.
	var store := _store_with({"0": {"color": "yellow"}})
	var roster: Array[Contestant] = _roster(3)
	ShopCatalog.assign_loadouts(roster, store)
	assert_eq(roster[0].color, Contestant.PALETTE[2])
	assert_ne(roster[2].color, roster[0].color)
	_assert_all_distinct(roster)


func test_same_color_twice_gives_it_to_the_earlier_joiner() -> void:
	var store := _store_with({"0": {"color": "teal"}, "1": {"color": "teal"}})
	var roster: Array[Contestant] = _roster(2)
	ShopCatalog.assign_loadouts(roster, store)
	assert_eq(roster[0].color, Contestant.PALETTE[10])
	assert_ne(roster[1].color, roster[0].color)
	assert_true(Contestant.PALETTE.has(roster[1].color), "falls back to a palette color")


func test_full_race_stays_distinct_whatever_is_bought() -> void:
	var wishes: Dictionary = {}
	for i: int in 20:
		# Everybody wants one of three colors.
		wishes[str(i)] = {"color": ["red", "green", "navy"][i % 3]}
	var roster: Array[Contestant] = _roster(20)
	ShopCatalog.assign_loadouts(roster, _store_with(wishes))
	_assert_all_distinct(roster)


func test_assigning_twice_changes_nothing() -> void:
	var store := _store_with({"3": {"color": "red"}})
	var roster: Array[Contestant] = _roster(5)
	ShopCatalog.assign_loadouts(roster, store)
	var first: Array[Color] = []
	for contestant: Contestant in roster:
		first.append(contestant.color)
	ShopCatalog.assign_loadouts(roster, store)
	for i: int in roster.size():
		assert_eq(roster[i].color, first[i])


func _roster(count: int) -> Array[Contestant]:
	var roster: Array[Contestant] = []
	for i: int in count:
		roster.append(Contestant.create(str(i), "P%d" % i, i))
	return roster


## Builds a store where each viewer owns and has equipped the given {kind: item} choices.
func _store_with(loadouts: Dictionary) -> ShopStore:
	var store := ShopStore.new()
	for user_id: String in loadouts:
		for kind: String in loadouts[user_id]:
			store.grant(user_id, kind, loadouts[user_id][kind])
			store.equip(user_id, kind, loadouts[user_id][kind])
	return store


func _assert_all_distinct(roster: Array[Contestant]) -> void:
	var seen: Dictionary = {}
	for contestant: Contestant in roster:
		assert_false(seen.has(contestant.color), "%s has its own color" % contestant.display_name)
		seen[contestant.color] = true
