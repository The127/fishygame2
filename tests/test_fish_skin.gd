extends GutTest
## Premium fish colors: names, pricing through the color flow, loadouts and drawing.


func _make_marble() -> Marble:
	return (load("res://scenes/marble.tscn") as PackedScene).instantiate() as Marble


func _msg(user_id: String) -> ChatMessage:
	return ChatMessage.create(user_id, "user" + user_id, "User" + user_id, "")


func _shop(balance: int) -> Shop:
	var shop: Shop = Shop.new()
	shop.store = ShopStore.new()
	shop.points = PointsStore.new("", balance)
	add_child_autofree(shop)
	return shop


func test_every_kind_has_a_name_an_accent_and_a_material() -> void:
	assert_eq(FishSkin.NAMES.size(), FishSkin.Kind.size() - 1)
	assert_eq(FishSkin.ACCENTS.size(), FishSkin.NAMES.size())
	for kind: int in range(1, FishSkin.Kind.size()):
		assert_eq(FishSkin.kind_of(FishSkin.name_of(kind)), kind)
		assert_not_null(FishSkin.material_of(kind))
	assert_null(FishSkin.material_of(FishSkin.Kind.NONE))


func test_names_do_not_clash_with_palette_colors() -> void:
	for name: String in FishSkin.NAMES:
		assert_false(ShopCatalog.COLOR_NAMES.has(name))


func test_aliases_and_case_resolve() -> void:
	assert_eq(FishSkin.canonical("Missing Texture"), "missing")
	assert_eq(FishSkin.kind_of("NEON"), FishSkin.Kind.NEON)
	assert_eq(FishSkin.kind_of("red"), FishSkin.Kind.NONE)


func test_premium_color_costs_the_premium_price() -> void:
	var shop: Shop = _shop(5000)
	assert_true(shop.choose(_msg("1"), PackedStringArray(["Neon"]), ShopStore.KIND_COLOR))
	assert_eq(shop.points.get_balance("1"), 5000 - shop.premium_color_price)
	assert_eq(shop.store.equipped("1", ShopStore.KIND_COLOR), "neon")
	assert_gt(shop.premium_color_price, shop.color_price * 2)


func test_missing_texture_can_be_typed_with_a_space() -> void:
	var shop: Shop = _shop(5000)
	assert_true(shop.choose(_msg("1"), PackedStringArray(["missing", "texture"]), "color"))
	assert_eq(shop.store.equipped("1", ShopStore.KIND_COLOR), "missing")


func test_premium_is_bought_once_and_needs_the_points() -> void:
	var shop: Shop = _shop(1500)
	shop.choose(_msg("1"), PackedStringArray(["gold"]), ShopStore.KIND_COLOR)
	var after: int = shop.points.get_balance("1")
	shop.choose(_msg("1"), PackedStringArray(["red"]), ShopStore.KIND_COLOR)
	shop.choose(_msg("1"), PackedStringArray(["gold"]), ShopStore.KIND_COLOR)
	assert_eq(shop.points.get_balance("1"), after - shop.color_price)
	var rejections: Array[String] = []
	shop.rejected.connect(func(_m: ChatMessage, reason: String) -> void: rejections.append(reason))
	shop.points.set_balance("2", 10)
	assert_false(shop.choose(_msg("2"), PackedStringArray(["lava"]), ShopStore.KIND_COLOR))
	assert_eq(rejections, ["insufficient"] as Array[String])


func test_listing_names_every_premium_color_in_one_message() -> void:
	var text: String = _shop(0).premium_catalog_text()
	for name: String in FishSkin.NAMES:
		assert_string_contains(text, name)
	assert_lt(text.length(), 500)


func test_premium_fish_wear_the_skin_and_take_no_palette_color() -> void:
	var store: ShopStore = ShopStore.new()
	store.grant("a", ShopStore.KIND_COLOR, "rainbow")
	store.equip("a", ShopStore.KIND_COLOR, "rainbow")
	var roster: Array[Contestant] = []
	for i: int in 20:
		roster.append(Contestant.create(str(i) if i > 0 else "a", "P%d" % i, i))
	ShopCatalog.assign_loadouts(roster, store)
	assert_eq(roster[0].skin, FishSkin.Kind.RAINBOW)
	assert_eq(roster[1].skin, FishSkin.Kind.NONE)
	var seen: Dictionary = {}
	for i: int in range(1, 20):
		assert_false(seen.has(roster[i].color), "player %d keeps a unique color" % i)
		seen[roster[i].color] = true


func test_every_skin_draws_on_a_fish_and_takes_the_shader() -> void:
	var fish: FishVisual = FishVisual.new()
	add_child_autofree(fish)
	for kind: int in FishSkin.Kind.size():
		fish.skin = kind
		await wait_frames(2)
		assert_eq(fish.material, FishSkin.material_of(kind))


func test_marbles_pass_the_skin_to_their_fish() -> void:
	var marble: Marble = _make_marble()
	marble.skin = FishSkin.Kind.GHOST
	add_child_autofree(marble)
	var fish: FishVisual = marble.find_children("*", "FishVisual", false, false)[0]
	assert_eq(fish.skin, FishSkin.Kind.GHOST)
	marble.skin = FishSkin.Kind.MATRIX
	assert_eq(fish.skin, FishSkin.Kind.MATRIX)


func test_aquarium_describes_the_premium_color() -> void:
	var who: Contestant = Contestant.create("1", "One", 0)
	who.skin = FishSkin.Kind.ATOMIC
	assert_string_contains(AquariumRoster.describe(who), "atomic")
