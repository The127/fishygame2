extends SceneTree
## Writes the static shop page (see [ShopPage]) and a preview image for every item. Run it
## through tools/render_shop_page.sh, which starts it under Xvfb: it needs a real renderer, so
## it can't run --headless. Its --fixed-fps must match [constant ShopPage.FPS] so each frame of
## a strip is one step of time.

## Scale of the fish in a preview frame.
const ZOOM: float = 4.4
## How fast the fish swims in a trail preview, in world pixels per second.
const SWIM_SPEED: float = 80.0
## A neutral fish wears the accessories, trails and dances: a blue trout.
const MODEL_COLOR: int = 3

var _frame_size := Vector2i(ShopPage.PREVIEW_WIDTH * 2, ShopPage.PREVIEW_HEIGHT * 2)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_shop_page.gd needs a renderer; run it under xvfb-run without --headless")
		quit(1)
		return
	var out: String = "build/web"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	seed(421)
	DirAccess.make_dir_recursive_absolute(out.path_join(ShopPage.IMAGE_DIR))
	var shop := Shop.new()
	var sections: Array[Dictionary] = ShopPage.sections(shop)
	shop.free()
	for item: Dictionary in ShopPage.items(sections):
		var strip: Image = await _render(item)
		var path: String = out.path_join(item["image"])
		if strip.save_webp(path, true, ShopPage.IMAGE_QUALITY) != OK:
			push_error("could not write %s" % path)
			quit(1)
			return
	var page := FileAccess.open(out.path_join("shop.html"), FileAccess.WRITE)
	if page == null:
		push_error("could not write shop.html in %s" % out)
		quit(1)
		return
	page.store_string(ShopPage.html(sections))
	page.close()
	# Let the last preview's viewport be freed before quitting.
	await process_frame
	print("Shop page: %d items in %s" % [ShopPage.items(sections).size(), out])
	quit()


## Renders [param item] into one frame, or a horizontal strip of its frames.
func _render(item: Dictionary) -> Image:
	var viewport := SubViewport.new()
	viewport.size = _frame_size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.color = ShopPage.BACKGROUND
	backdrop.size = Vector2(_frame_size)
	var back_layer := CanvasLayer.new()
	back_layer.layer = -1
	back_layer.add_child(backdrop)
	viewport.add_child(back_layer)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * ZOOM
	viewport.add_child(camera)

	var fish := FishVisual.new()
	fish.species = int(item.get("species", 0))
	var slot: int = int(item.get("color", MODEL_COLOR))
	fish.color = FishPalette.color_of(slot, false)
	fish.skin = int(item.get("skin", FishSkin.Kind.NONE))
	fish.accessory = int(item.get("hat", 0))
	var trail: CPUParticles2D = null
	if item.has("dance"):
		var dancer := FishDance.new()
		dancer.kind = int(item["dance"])
		dancer.fish = fish
		viewport.add_child(dancer)
		camera.position = Vector2(0.0, -3.0)
	else:
		# The fish follows its parent (see [method FishVisual.face]), so it swims on a mover.
		var mover := Node2D.new()
		mover.add_child(fish)
		viewport.add_child(mover)
		if item.has("trail"):
			trail = FishTrail.make(int(item["trail"]))
			trail.emitting = true
			viewport.add_child(trail)

	var frames: int = item["frames"]
	var step: float = 1.0 / ShopPage.FPS
	# Let the trail fill in and the shaders warm up before the first captured frame.
	var warmup: int = ShopPage.FPS if trail != null else 2
	var strip := Image.create(_frame_size.x * frames, _frame_size.y, false, Image.FORMAT_RGBA8)
	for f: int in warmup + frames:
		if trail != null:
			var mover: Node2D = fish.get_parent()
			mover.position.x += SWIM_SPEED * step
			fish.face(Vector2(SWIM_SPEED, 0.0), step)
			trail.position = mover.position - Vector2(12.0, 0.0)
			camera.position = mover.position - Vector2(16.0, 0.0)
		await RenderingServer.frame_post_draw
		if f < warmup:
			continue
		var frame: Image = viewport.get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(
			frame, Rect2i(Vector2i.ZERO, _frame_size), Vector2i(_frame_size.x * (f - warmup), 0)
		)
	viewport.queue_free()
	return strip
