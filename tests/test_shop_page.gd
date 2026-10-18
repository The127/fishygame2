extends GutTest

const KINDS: Array[String] = [
	ShopStore.KIND_SPECIES,
	ShopStore.KIND_COLOR,
	ShopStore.KIND_HAT,
	ShopStore.KIND_TRAIL,
	ShopStore.KIND_DANCE,
]

var _shop: Shop


func before_each() -> void:
	_shop = autofree(Shop.new())


func _catalog(kind: String) -> Array[String]:
	match kind:
		ShopStore.KIND_SPECIES:
			return ShopCatalog.SPECIES_NAMES
		ShopStore.KIND_COLOR:
			return ShopCatalog.COLOR_NAMES + ShopCatalog.PREMIUM_NAMES
		ShopStore.KIND_HAT:
			return ShopCatalog.HAT_NAMES
		ShopStore.KIND_TRAIL:
			return ShopCatalog.TRAIL_NAMES
	return ShopCatalog.DANCE_NAMES


func test_every_catalog_item_is_on_the_page_once() -> void:
	var listed: Dictionary = {}
	for item: Dictionary in ShopPage.items(ShopPage.sections(_shop)):
		var key: String = "%s/%s" % [item["kind"], item["name"]]
		assert_false(listed.has(key), "%s is listed once" % key)
		listed[key] = true
	var expected: int = 0
	for kind: String in KINDS:
		for item_name: String in _catalog(kind):
			expected += 1
			assert_true(
				listed.has("%s/%s" % [kind, item_name]), "%s %s is listed" % [kind, item_name]
			)
	assert_eq(listed.size(), expected)


func test_prices_and_commands_match_the_shop() -> void:
	for item: Dictionary in ShopPage.items(ShopPage.sections(_shop)):
		assert_eq(item["price"], _shop.price_of(item["kind"], item["name"]), item["name"])
		var words: PackedStringArray = String(item["command"]).split(" ")
		var command: String = words[0].trim_prefix("#")
		assert_eq(command, "fish" if item["kind"] == ShopStore.KIND_SPECIES else item["kind"])
		assert_true(ShopCatalog.has_item(item["kind"], words[1]), item["command"])


func test_html_has_every_preview_command_and_price() -> void:
	var sections: Array[Dictionary] = ShopPage.sections(_shop)
	var page: String = ShopPage.html(sections)
	assert_true(page.begins_with("<!doctype html>"))
	assert_string_contains(page, 'name="viewport"')
	for item: Dictionary in ShopPage.items(sections):
		assert_string_contains(page, "url('%s')" % item["image"])
		assert_string_contains(page, "<code>%s</code>" % item["command"])
	assert_string_contains(page, "%d points" % _shop.hat_price)


func test_animated_strips_fit_in_one_image() -> void:
	# WebP images are at most 16383 pixels wide; previews render at twice the page size.
	for item: Dictionary in ShopPage.items(ShopPage.sections(_shop)):
		assert_lt(int(item["frames"]) * ShopPage.PREVIEW_WIDTH * 2, 16384, item["name"])
