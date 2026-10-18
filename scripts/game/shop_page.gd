class_name ShopPage
extends RefCounted
## The static shop page published next to the web build as shop.html: every item on sale with a
## preview, the chat command that buys it and its default price. It is built from [ShopCatalog]
## and the [Shop] defaults when the build is made (tools/render_shop_page.gd), so it can't drift
## from the catalog. Animated previews are horizontal strips of frames, played with CSS.

## Folder of the preview images, next to shop.html.
const IMAGE_DIR: String = "shop"
## Lossy WebP quality of the preview images; the animated strips would be large as PNG.
const IMAGE_QUALITY: float = 0.8
## Preview size on the page in CSS pixels. Images are rendered at twice this for sharp screens.
const PREVIEW_WIDTH: int = 144
const PREVIEW_HEIGHT: int = 108
## Frames per second of the animated previews.
const FPS: int = 10
## Seconds a premium color or trail preview loops over.
const LOOP_SECONDS: float = 1.6
## Seconds of each dance, in the order of [constant ShopCatalog.DANCE_NAMES]: one full cycle,
## so the strip loops without a jump (see [method FishDance.pose]).
const DANCE_SECONDS: Array[float] = [0.9, 2.8, 3.2, 4.8, 1.6]
## Page and preview background.
const BACKGROUND: Color = Color("0a1a2f")
## The page up to the first section; {bg}, {w} and {h} are filled in by [method html].
const HEAD_HTML: String = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fish Shop</title>
<style>
:root { color-scheme: dark; }
body { margin: 0; background: {bg}; color: #e8f1ff; font: 16px/1.4 system-ui, sans-serif; }
main { max-width: 1100px; margin: 0 auto; padding: 24px 16px 48px; }
h1 { margin: 0 0 8px; font-size: 28px; }
h2 { margin: 32px 0 4px; font-size: 22px; }
p { margin: 0 0 8px; color: #a9bdd6; }
.grid { list-style: none; margin: 12px 0 0; padding: 0; display: grid; gap: 12px;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); }
.card { background: #102641; border: 1px solid #1d3a5e; border-radius: 10px; padding: 8px;
  display: flex; flex-direction: column; align-items: center; text-align: center; }
.preview { width: {w}px; height: {h}px; background-size: auto 100%; background-repeat: no-repeat;
  border-radius: 6px; }
.anim { animation: play var(--dur) steps(var(--n)) infinite; }
@keyframes play { to { background-position-x: calc(var(--n) * -{w}px); } }
@media (prefers-reduced-motion: reduce) { .anim { animation: none; } }
.name { margin-top: 6px; font-weight: 600; text-transform: capitalize; }
code { margin-top: 4px; padding: 2px 6px; border-radius: 4px; background: #061220; color: #9fe3ff;
  font-size: 14px; user-select: all; }
.price { margin-top: 4px; color: #ffd36b; font-size: 14px; }
</style>
</head>
<body>
<main>
<h1>Fish Shop</h1>
<p>Spend your points on how your fish looks. Type the command in the stream's chat. Each item is
bought once. After that, switching back to it is free.</p>
<p>Prices are the defaults. The streamer can change them, so <code>#shop</code> in chat has the
prices for this stream.</p>
"""

const FOOT_HTML: String = """</main>
</body>
</html>
"""


## The sections of the page in order, each {"title", "note", "items"}, priced by [param shop]
## (a fresh one has the default prices). An item is {"kind", "name", "command", "price",
## "image" (path relative to shop.html), "frames" (1 for a still)} plus what the renderer
## draws: "species", "color", "skin", "hat", "trail" or "dance".
static func sections(shop: Shop) -> Array[Dictionary]:
	var species: Array[Dictionary] = []
	for i: int in ShopCatalog.SPECIES_NAMES.size():
		var item: Dictionary = _item(ShopStore.KIND_SPECIES, ShopCatalog.SPECIES_NAMES[i], shop)
		item["species"] = i
		species.append(item)
	var colors: Array[Dictionary] = []
	for i: int in ShopCatalog.COLOR_NAMES.size():
		var item: Dictionary = _item(ShopStore.KIND_COLOR, ShopCatalog.COLOR_NAMES[i], shop)
		item["color"] = i
		colors.append(item)
	var premium: Array[Dictionary] = []
	for i: int in ShopCatalog.PREMIUM_NAMES.size():
		var item: Dictionary = _item(ShopStore.KIND_COLOR, ShopCatalog.PREMIUM_NAMES[i], shop)
		item["skin"] = i + 1
		item["frames"] = roundi(LOOP_SECONDS * FPS)
		premium.append(item)
	var hats: Array[Dictionary] = []
	for i: int in ShopCatalog.HAT_NAMES.size():
		var item: Dictionary = _item(ShopStore.KIND_HAT, ShopCatalog.HAT_NAMES[i], shop)
		item["hat"] = i + 1
		hats.append(item)
	var trails: Array[Dictionary] = []
	for i: int in ShopCatalog.TRAIL_NAMES.size():
		var item: Dictionary = _item(ShopStore.KIND_TRAIL, ShopCatalog.TRAIL_NAMES[i], shop)
		item["trail"] = i + 1
		item["frames"] = roundi(LOOP_SECONDS * FPS)
		trails.append(item)
	var dances: Array[Dictionary] = []
	for i: int in ShopCatalog.DANCE_NAMES.size():
		var item: Dictionary = _item(ShopStore.KIND_DANCE, ShopCatalog.DANCE_NAMES[i], shop)
		item["dance"] = i + 1
		item["frames"] = roundi(DANCE_SECONDS[i] * FPS)
		dances.append(item)
	return [
		{"title": "Fish", "note": "The shape of your fish.", "items": species},
		{"title": "Colors", "note": "No two fish in a race share a color.", "items": colors},
		{"title": "Premium colors", "note": "Animated looks, worn like a color.", "items": premium},
		{"title": "Accessories", "note": "Type #hat none to take it off.", "items": hats},
		{"title": "Trails", "note": "Type #trail none to take it off.", "items": trails},
		{
			"title": "Victory dances",
			"note": "Done on the podium when you win. #dance random goes back to a surprise.",
			"items": dances
		},
	]


static func _item(kind: String, item_name: String, shop: Shop) -> Dictionary:
	return {
		"kind": kind,
		"name": item_name,
		"command": "#%s %s" % [_command_of(kind), item_name],
		"price": shop.price_of(kind, item_name),
		"image": "%s/%s-%s.webp" % [IMAGE_DIR, kind, item_name],
		"frames": 1,
	}


## The chat command for a kind: "#fish" buys a species, the rest are named after their kind.
static func _command_of(kind: String) -> String:
	return "fish" if kind == ShopStore.KIND_SPECIES else kind


## Every item of [param page_sections] in page order.
static func items(page_sections: Array[Dictionary]) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for section: Dictionary in page_sections:
		for item: Dictionary in section["items"]:
			all.append(item)
	return all


## The whole page for [param page_sections] (see [method sections]).
static func html(page_sections: Array[Dictionary]) -> String:
	var body: PackedStringArray = []
	for section: Dictionary in page_sections:
		body.append(
			(
				'<section>\n<h2>%s</h2>\n<p class="note">%s</p>\n<ul class="grid">\n'
				% [_esc(section["title"]), _esc(section["note"])]
			)
		)
		for item: Dictionary in section["items"]:
			body.append(_card(item))
		body.append("</ul>\n</section>\n")
	return (
		(
			HEAD_HTML
			. replace("{bg}", "#" + BACKGROUND.to_html(false))
			. replace("{w}", str(PREVIEW_WIDTH))
			. replace("{h}", str(PREVIEW_HEIGHT))
		)
		+ "".join(body)
		+ FOOT_HTML
	)


static func _card(item: Dictionary) -> String:
	var frames: int = item["frames"]
	var preview: String = (
		'<div class="preview" role="img" aria-label="%s" style="background-image:url(\'%s\')"></div>'
		% [_esc(item["name"]), _esc(item["image"])]
	)
	if frames > 1:
		preview = (
			(
				'<div class="preview anim" role="img" aria-label="%s" '
				+ "style=\"background-image:url('%s');--n:%d;--dur:%.1fs\"></div>"
			)
			% [_esc(item["name"]), _esc(item["image"]), frames, float(frames) / FPS]
		)
	return (
		'<li class="card">%s<div class="name">%s</div><code>%s</code><div class="price">%d points</div></li>\n'
		% [preview, _esc(item["name"]), _esc(item["command"]), item["price"]]
	)


static func _esc(text: String) -> String:
	return text.xml_escape(true)
