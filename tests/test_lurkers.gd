extends GutTest
## "#lurk": eye styles, staying a lurker until "#join", the silent point per race, and saving.

const SHOP_PATH: String = "user://test_lurkers_shop.json"

var _lurkers: Lurkers
var _points: PointsStore
var _store: ShopStore
var _changes: Array = []


func before_each() -> void:
	_remove_files()
	_points = PointsStore.new()
	_store = ShopStore.new(SHOP_PATH)
	_lurkers = Lurkers.new()
	_lurkers.points = _points
	_lurkers.store = _store
	_changes = []
	_lurkers.lurkers_changed.connect(func(w: Array[Dictionary]) -> void: _changes.append(w))
	add_child_autofree(_lurkers)


func after_each() -> void:
	_remove_files()


func _remove_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = ProjectSettings.globalize_path(SHOP_PATH + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _msg(user_id: String) -> ChatMessage:
	return ChatMessage.create(user_id, "user" + user_id, "User" + user_id, "#lurk")


func _contestant(user_id: String) -> Contestant:
	return Contestant.create(user_id, "User" + user_id)


func test_lurk_hands_out_a_random_eye_style_for_good() -> void:
	_lurkers.handle_command(_msg("a"), "lurk", PackedStringArray())
	assert_true(_store.is_lurking("a"))
	var style: String = _store.equipped("a", ShopStore.KIND_EYES)
	assert_has(LurkerEyes.STYLES, style)
	assert_eq(_changes.size(), 1)
	assert_eq(_changes[0][0]["eyes"], style)
	# Joining and lurking again keeps the same eyes.
	_lurkers.add_contestant(_contestant("a"))
	_lurkers.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.PODIUM)
	for i: int in 20:
		_lurkers.rng.seed = i
		_lurkers.lurk("a", "Usera")
		_store.set_lurking("a", false)
	assert_eq(_store.equipped("a", ShopStore.KIND_EYES), style)


func test_every_style_shows_up() -> void:
	var seen: Dictionary = {}
	for i: int in 200:
		_lurkers.rng.seed = i
		_lurkers.lurk(str(i), "")
		seen[_store.equipped(str(i), ShopStore.KIND_EYES)] = true
	assert_eq(seen.size(), LurkerEyes.STYLES.size())


func test_lurking_again_changes_nothing() -> void:
	assert_true(_lurkers.lurk("a", "A"))
	assert_false(_lurkers.lurk("a", "A"))
	assert_eq(_changes.size(), 1)


func test_lurker_stays_until_they_join() -> void:
	_lurkers.lurk("a", "A")
	for i: int in 3:
		_lurkers.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.PODIUM)
		_lurkers.on_podium_ready([])
		assert_true(_store.is_lurking("a"), "still lurking after race %d" % i)
	_lurkers.add_contestant(_contestant("a"))
	assert_false(_store.is_lurking("a"))
	assert_true(_lurkers.watchers().is_empty())


func test_a_lurker_racing_this_race_is_not_watching_it() -> void:
	_lurkers.add_contestant(_contestant("a"))
	# "#lurk" from the lobby takes effect from the next race.
	_lurkers.lurk("a", "A")
	assert_true(_lurkers.watchers().is_empty())
	_lurkers.on_podium_ready([])
	assert_eq(_points.get_balance("a"), _points.starting_balance, "no lurk point for racing")
	_lurkers.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.PODIUM)
	assert_eq(_lurkers.watchers().size(), 1)


func test_one_point_per_race_lurked() -> void:
	_lurkers.lurk("a", "A")
	_lurkers.lurk("b", "B")
	_lurkers.add_contestant(_contestant("c"))
	_lurkers.on_podium_ready([])
	_lurkers.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.PODIUM)
	_lurkers.on_podium_ready([])
	assert_eq(_points.get_balance("a"), _points.starting_balance + 2)
	assert_eq(_points.get_balance("b"), _points.starting_balance + 2)
	assert_eq(_points.get_balance("c"), _points.starting_balance)


func test_watchers_carry_the_shop_species() -> void:
	_store.grant("a", ShopStore.KIND_SPECIES, ShopCatalog.SPECIES_NAMES[3])
	_store.equip("a", ShopStore.KIND_SPECIES, ShopCatalog.SPECIES_NAMES[3])
	_lurkers.lurk("a", "A")
	_lurkers.lurk("b", "B")
	var watchers: Array[Dictionary] = _lurkers.watchers()
	assert_eq(watchers.size(), 2)
	assert_eq(watchers[0]["species"], 3)
	assert_between(int(watchers[1]["species"]), 0, FishVisual.SPECIES.size() - 1)


func test_lurking_and_eyes_survive_a_restart() -> void:
	_lurkers.lurk("a", "A")
	var style: String = _store.equipped("a", ShopStore.KIND_EYES)
	var reloaded := ShopStore.new(SHOP_PATH)
	assert_true(reloaded.load_from_disk())
	assert_true(reloaded.is_lurking("a"))
	assert_eq(reloaded.equipped("a", ShopStore.KIND_EYES), style)
	_lurkers.add_contestant(_contestant("a"))
	reloaded = ShopStore.new(SHOP_PATH)
	reloaded.load_from_disk()
	assert_false(reloaded.is_lurking("a"), "joining is saved too")
