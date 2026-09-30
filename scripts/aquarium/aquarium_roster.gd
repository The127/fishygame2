class_name AquariumRoster
extends RefCounted
## Every fish that exists: one per viewer the saved shop, points and stats data knows about,
## wearing what they equipped. Nobody has to be in a lobby.


## Builds the fish of everyone in [param points], [param shop] or [param stats] (either may
## be null), sorted by name so the order is stable. Looks are settled like a lobby's
## (see [method ShopCatalog.assign_loadouts]).
static func build(
	points: PointsStore, shop: ShopStore, colorblind: bool = false
) -> Array[Contestant]:
	var ids: Array[String] = []
	var sources: Array[Array] = []
	if points != null:
		sources.append(points.user_ids())
		sources.append(points.stats.user_ids())
	if shop != null:
		sources.append(shop.user_ids())
	for source: Array in sources:
		for user_id: String in source:
			if not ids.has(user_id):
				ids.append(user_id)
	var names: Dictionary = {}
	for user_id: String in ids:
		names[user_id] = (
			points.get_name(user_id) if points != null else "Viewer %s" % user_id.right(4)
		)
	ids.sort_custom(
		func(a: String, b: String) -> bool:
			var an: String = (names[a] as String).to_lower()
			var bn: String = (names[b] as String).to_lower()
			return an < bn if an != bn else a < b
	)
	var fish: Array[Contestant] = []
	for i: int in ids.size():
		fish.append(Contestant.create(ids[i], names[ids[i]], i))
	if shop != null:
		ShopCatalog.assign_loadouts(fish, shop, colorblind)
	return fish


## What a fish is, for the hover label: "angelfish, red, tophat".
static func describe(who: Contestant) -> String:
	var color_name: String = FishSkin.name_of(who.skin)
	if color_name.is_empty():
		color_name = ShopCatalog.COLOR_NAMES[posmod(
			who.palette_slot, ShopCatalog.COLOR_NAMES.size()
		)]
	var parts: Array[String] = [
		ShopCatalog.SPECIES_NAMES[posmod(who.species, ShopCatalog.SPECIES_NAMES.size())], color_name
	]
	if who.accessory > 0:
		parts.append(ShopCatalog.HAT_NAMES[(who.accessory - 1) % ShopCatalog.HAT_NAMES.size()])
	if who.trail > 0:
		parts.append(
			ShopCatalog.TRAIL_NAMES[(who.trail - 1) % ShopCatalog.TRAIL_NAMES.size()] + " trail"
		)
	return ", ".join(parts)
