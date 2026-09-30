extends GutTest

var _shop: Shop
var _points: PointsStore
var _equipped: Array[Dictionary] = []
var _rejections: Array[String] = []


func before_each() -> void:
	_equipped.clear()
	_rejections.clear()
	_points = PointsStore.new("", 1000)
	_shop = Shop.new()
	_shop.store = ShopStore.new()
	_shop.points = _points
	_shop.species_price = 500
	_shop.color_price = 250
	_shop.equipped.connect(
		func(_msg: ChatMessage, kind: String, item: String, price: int) -> void:
			_equipped.append({"kind": kind, "item": item, "price": price})
	)
	_shop.rejected.connect(
		func(_msg: ChatMessage, reason: String) -> void: _rejections.append(reason)
	)
	add_child_autofree(_shop)


func test_buying_a_color_spends_and_equips() -> void:
	assert_true(_shop.choose(_msg("1"), PackedStringArray(["red"]), ShopStore.KIND_COLOR))
	assert_eq(_points.get_balance("1"), 750)
	assert_eq(_shop.store.equipped("1", ShopStore.KIND_COLOR), "red")
	assert_eq(_equipped, [{"kind": "color", "item": "red", "price": 250}] as Array[Dictionary])


func test_buying_a_species_costs_the_species_price() -> void:
	_shop.handle_command(_msg("1"), "fish", PackedStringArray(["Pike"]))
	assert_eq(_points.get_balance("1"), 500)
	assert_eq(_shop.store.equipped("1", ShopStore.KIND_SPECIES), "pike")


func test_switching_to_an_owned_item_is_free() -> void:
	_shop.handle_command(_msg("1"), "color", PackedStringArray(["red"]))
	_shop.handle_command(_msg("1"), "color", PackedStringArray(["blue"]))
	assert_eq(_points.get_balance("1"), 500)
	_shop.handle_command(_msg("1"), "color", PackedStringArray(["red"]))
	assert_eq(_points.get_balance("1"), 500, "red is owned, so switching back is free")
	assert_eq(_shop.store.equipped("1", ShopStore.KIND_COLOR), "red")
	assert_eq(_equipped[2]["price"], 0)


func test_too_poor_changes_nothing() -> void:
	_points.set_balance("1", 100)
	assert_false(_shop.choose(_msg("1"), PackedStringArray(["red"]), ShopStore.KIND_COLOR))
	assert_eq(_points.get_balance("1"), 100)
	assert_false(_shop.store.owns("1", ShopStore.KIND_COLOR, "red"))
	assert_eq(_rejections, ["insufficient"] as Array[String])


func test_unknown_names_and_missing_arguments_are_rejected() -> void:
	_shop.handle_command(_msg("1"), "fish", PackedStringArray(["shark"]))
	_shop.handle_command(_msg("1"), "color", PackedStringArray(["plaid"]))
	_shop.handle_command(_msg("1"), "color", PackedStringArray())
	assert_eq(_rejections, ["unknown_species", "unknown_color", "usage"] as Array[String])
	assert_eq(_points.get_balance("1"), 1000)


func test_a_species_name_is_not_a_color() -> void:
	assert_false(_shop.choose(_msg("1"), PackedStringArray(["pike"]), ShopStore.KIND_COLOR))
	assert_eq(_rejections, ["unknown_color"] as Array[String])


func test_free_prices_still_record_ownership() -> void:
	_shop.color_price = 0
	_shop.handle_command(_msg("1"), "color", PackedStringArray(["red"]))
	assert_true(_shop.store.owns("1", ShopStore.KIND_COLOR, "red"))
	assert_eq(_points.get_balance("1"), 1000)


func test_ownership_is_per_viewer() -> void:
	_shop.handle_command(_msg("1"), "color", PackedStringArray(["red"]))
	_shop.handle_command(_msg("2"), "color", PackedStringArray(["red"]))
	assert_eq(_points.get_balance("2"), 750, "another viewer pays for their own")


func test_shop_command_asks_for_the_listing() -> void:
	watch_signals(_shop)
	_shop.handle_command(_msg("1"), "shop", PackedStringArray())
	assert_signal_emitted(_shop, "catalog_requested")


func test_listing_shows_names_and_prices() -> void:
	var text: String = _shop.catalog_text()
	for name: String in ShopCatalog.SPECIES_NAMES + ShopCatalog.COLOR_NAMES:
		assert_string_contains(text, name)
	assert_string_contains(text, "500")
	assert_string_contains(text, "250")
	assert_lt(text.length(), 500, "fits in one Twitch message")


func _msg(user_id: String) -> ChatMessage:
	return ChatMessage.create(user_id, "user" + user_id, "User" + user_id, "")


func test_colorblind_listing_names_the_markings_and_still_fits_a_message() -> void:
	_shop.colorblind = true
	var text: String = _shop.catalog_text()
	assert_string_contains(text, "red (solid)")
	assert_lt(text.length(), 500, "fits in one Twitch message")


func test_buying_a_hat_costs_the_hat_price_and_equips_it() -> void:
	_shop.hat_price = 200
	_shop.handle_command(_msg("1"), "hat", PackedStringArray(["Crown"]))
	assert_eq(_points.get_balance("1"), 800)
	assert_eq(_shop.store.equipped("1", ShopStore.KIND_HAT), "crown")
	_shop.handle_command(_msg("1"), "hat", PackedStringArray(["duck"]))
	_shop.handle_command(_msg("1"), "hat", PackedStringArray(["crown"]))
	assert_eq(_points.get_balance("1"), 600, "crown is owned, so switching back is free")
	assert_eq(_shop.store.equipped("1", ShopStore.KIND_HAT), "crown")


func test_hat_none_takes_it_off_for_free_and_keeps_ownership() -> void:
	_shop.handle_command(_msg("1"), "hat", PackedStringArray(["flower"]))
	var balance: int = _points.get_balance("1")
	_shop.handle_command(_msg("1"), "hat", PackedStringArray(["none"]))
	assert_eq(_points.get_balance("1"), balance)
	assert_eq(_shop.store.equipped("1", ShopStore.KIND_HAT), "")
	assert_true(_shop.store.owns("1", ShopStore.KIND_HAT, "flower"))


func test_unknown_hat_and_missing_name_are_rejected() -> void:
	_shop.handle_command(_msg("1"), "hat", PackedStringArray(["red"]))
	_shop.handle_command(_msg("1"), "hat", PackedStringArray())
	assert_eq(_rejections, ["unknown_hat", "usage"] as Array[String])
	assert_eq(_points.get_balance("1"), 1000)


func test_hat_needs_enough_points() -> void:
	_shop.hat_price = 5000
	assert_false(_shop.choose(_msg("1"), PackedStringArray(["crown"]), ShopStore.KIND_HAT))
	assert_eq(_rejections, ["insufficient"] as Array[String])


func test_hat_catalog_lists_every_hat() -> void:
	for hat: String in ShopCatalog.HAT_NAMES:
		assert_string_contains(_shop.hat_catalog_text(), hat)
