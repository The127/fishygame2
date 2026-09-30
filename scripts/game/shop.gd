class_name Shop
extends Node
## Viewers spend points on how their fish looks: "#fish <species>", "#color <name>" and "#hat <name>".
## An item is bought once, the first time it is asked for, and afterwards equipping it
## is free. The equipped items are applied when a race starts (see [ShopCatalog]).
## "#shop" asks the game to list the options.

signal equipped(msg: ChatMessage, kind: String, item: String, price: int)
signal rejected(msg: ChatMessage, reason: String)
signal catalog_requested(msg: ChatMessage)

const DEFAULT_PATH: String = "user://shop.json"
## Words for "#hat" that take the accessory off.
const HAT_OFF: PackedStringArray = ["none", "off"]

@export var shop_path: String = DEFAULT_PATH
@export var species_price: int = 500
@export var color_price: int = 250
@export var hat_price: int = 200

## Set by the game so the shop spends from the same balances as betting.
var points: PointsStore = null
var store: ShopStore = null
## Set from the settings: color names in the catalog then carry the fish marking.
var colorblind: bool = false


func _ready() -> void:
	if store == null:
		store = ShopStore.new(shop_path)
		store.load_from_disk()


func handle_command(msg: ChatMessage, command: String, args: PackedStringArray) -> void:
	match command:
		"fish":
			choose(msg, args, ShopStore.KIND_SPECIES)
		"color":
			choose(msg, args, ShopStore.KIND_COLOR)
		"hat":
			choose(msg, args, ShopStore.KIND_HAT)
		"shop":
			catalog_requested.emit(msg)


func price_of(kind: String) -> int:
	match kind:
		ShopStore.KIND_SPECIES:
			return species_price
		ShopStore.KIND_HAT:
			return hat_price
	return color_price


## Chat entry point for "#fish <species>" and "#color <name>". Buys the item if the viewer
## does not own it yet, then equips it. Returns true if it was equipped.
func choose(msg: ChatMessage, args: PackedStringArray, kind: String) -> bool:
	var item: String = " ".join(args).to_lower()
	var reason: String = ""
	if kind == ShopStore.KIND_HAT and item in HAT_OFF:
		store.unequip(msg.user_id, kind)
		store.save_to_disk()
		equipped.emit(msg, kind, "none", 0)
		return true
	if args.is_empty():
		reason = "usage"
	elif not ShopCatalog.has_item(kind, item):
		reason = "unknown_" + kind if kind != ShopStore.KIND_SPECIES else "unknown_species"
	var price: int = 0
	if reason.is_empty() and not store.owns(msg.user_id, kind, item):
		price = price_of(kind)
		if not points.try_debit(msg.user_id, price):
			reason = "insufficient"
	if not reason.is_empty():
		rejected.emit(msg, reason)
		return false
	store.grant(msg.user_id, kind, item)
	store.equip(msg.user_id, kind, item)
	if price > 0:
		points.save_to_disk()
	store.save_to_disk()
	equipped.emit(msg, kind, item, price)
	return true


## One chat line with everything on sale.
func catalog_text() -> String:
	return (
		"Fish shop: #fish <%s> (%d points), #color <%s> (%d points). Bought once, then free to switch."
		% [
			"|".join(ShopCatalog.SPECIES_NAMES),
			species_price,
			"|".join(ShopCatalog.color_labels(colorblind)),
			color_price,
		]
	)


## One chat line with the accessories on sale.
func hat_catalog_text() -> String:
	return (
		"Accessories: #hat <%s> (%d points), #hat none takes it off. Cosmetic only."
		% ["|".join(ShopCatalog.HAT_NAMES), hat_price]
	)
