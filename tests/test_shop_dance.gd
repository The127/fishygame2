extends GutTest
## "#dance" buys a victory dance for the podium; "#dance random" goes back to a surprise.

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


func test_buying_a_dance_costs_the_dance_price_and_random_takes_it_off() -> void:
	_shop.dance_price = 300
	_shop.handle_command(_msg("1"), "dance", PackedStringArray(["Floss"]))
	assert_eq(_points.get_balance("1"), 700)
	assert_eq(_shop.store.equipped("1", ShopStore.KIND_DANCE), "floss")
	_shop.handle_command(_msg("1"), "dance", PackedStringArray(["random"]))
	assert_eq(_shop.store.equipped("1", ShopStore.KIND_DANCE), "")
	assert_eq(_equipped[-1]["item"], "random")
	_shop.handle_command(_msg("1"), "dance", PackedStringArray(["macarena"]))
	assert_eq(_rejections, ["unknown_dance"] as Array[String])
	for dance: String in ShopCatalog.DANCE_NAMES:
		assert_string_contains(_shop.dance_catalog_text(), dance)


func test_random_is_not_a_way_to_take_off_a_hat() -> void:
	_shop.handle_command(_msg("1"), "hat", PackedStringArray(["random"]))
	assert_eq(_rejections, ["unknown_hat"] as Array[String])


func _msg(user_id: String) -> ChatMessage:
	return ChatMessage.create(user_id, "user" + user_id, "User" + user_id, "")
