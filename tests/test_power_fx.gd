extends GutTest
## The streamer power effects: hook timing, net animation states, blast phases, camera punch.


func test_hook_drops_hangs_then_reels() -> void:
	var hook: HookFx = HookFx.new()
	add_child_autofree(hook)
	assert_almost_eq(hook.hook_offset(), -HookFx.LINE_HEIGHT, 0.01)
	hook._process(HookFx.DROP_SECONDS + 0.01)
	assert_almost_eq(hook.hook_offset(), 0.0, 0.01)
	hook._process(HookFx.HOLD_SECONDS * 0.5)
	assert_almost_eq(hook.hook_offset(), 0.0, 0.01)
	hook._process(HookFx.HOLD_SECONDS * 0.5 + HookFx.REEL_SECONDS * 0.5)
	assert_lt(hook.hook_offset(), -HookFx.LINE_HEIGHT * 0.4)


func test_hook_swings_only_after_landing_and_settles() -> void:
	var hook: HookFx = HookFx.new()
	add_child_autofree(hook)
	hook._process(HookFx.DROP_SECONDS * 0.5)
	assert_eq(hook.swing(), 0.0)
	hook._process(HookFx.DROP_SECONDS * 0.5 + 0.05)
	assert_ne(hook.swing(), 0.0)
	assert_true(absf(hook.swing()) <= HookFx.SWING_PIXELS)


func test_hook_glints_while_hanging() -> void:
	var hook: HookFx = HookFx.new()
	add_child_autofree(hook)
	assert_eq(hook.glint(), 0.0)
	var peak: float = 0.0
	for i: int in 10:
		hook._process(HookFx.DROP_SECONDS / 10.0 + 0.02)
		peak = maxf(peak, hook.glint())
	assert_gt(peak, 0.0)
	assert_true(peak <= 1.0)


func test_hook_frees_itself_when_done() -> void:
	var hook: HookFx = HookFx.new()
	add_child(hook)
	hook._process(HookFx.DROP_SECONDS + HookFx.HOLD_SECONDS + HookFx.REEL_SECONDS + 0.1)
	assert_true(hook.is_queued_for_deletion())
	hook.free()


func test_net_spreads_out_and_ends_full_size() -> void:
	var net: NetZone = NetZone.new()
	add_child_autofree(net)
	assert_lt(net.spread(), 0.5)
	net._process(NetZone.CAST_SECONDS)
	assert_almost_eq(net.spread(), 1.0, 0.001)
	assert_eq(net.cast_progress(), 1.0)


func test_net_ripple_moves_rope_sideways_not_at_the_centre() -> void:
	var net: NetZone = NetZone.new()
	add_child_autofree(net)
	net._process(1.0)
	assert_eq(net.ripple(Vector2.ZERO), Vector2.ZERO)
	assert_gt(net.ripple(Vector2(100.0, 0.0)).length(), 0.0)


func test_net_tightens_for_a_moment_after_a_catch() -> void:
	var net: NetZone = NetZone.new()
	add_child_autofree(net)
	net._process(1.0)
	assert_eq(net.tighten_scale(), 1.0)
	net.tighten()
	net._process(NetZone.TIGHTEN_SECONDS * 0.5)
	assert_lt(net.tighten_scale(), 1.0)
	net._process(NetZone.TIGHTEN_SECONDS)
	assert_eq(net.tighten_scale(), 1.0)


func test_net_reports_each_fish_once() -> void:
	var net: NetZone = NetZone.new()
	add_child_autofree(net)
	assert_true(net.catch_fish(3))
	assert_false(net.catch_fish(3))
	assert_true(net.catch_fish(4))


func test_net_radius_and_strength_are_unchanged_by_the_animation() -> void:
	var net: NetZone = NetZone.new()
	net.radius = 170.0
	add_child_autofree(net)
	net._process(0.1)
	assert_true(net.contains(net.global_position + Vector2(169.0, 0.0)))
	assert_false(net.contains(net.global_position + Vector2(171.0, 0.0)))
	assert_eq(net.strength(), 1.0)


func test_blast_charges_then_flashes() -> void:
	var blast: BlastFx = BlastFx.new()
	add_child_autofree(blast)
	assert_true(blast.is_charging())
	assert_eq(blast.flash_alpha(), 0.0)
	blast._process(BlastFx.CHARGE_SECONDS + 0.01)
	assert_false(blast.is_charging())
	assert_gt(blast.flash_alpha(), 0.8)
	blast._process(BlastFx.FLASH_SECONDS)
	assert_eq(blast.flash_alpha(), 0.0)


func test_blast_spawns_its_rings_once_it_goes_off() -> void:
	var host: Node2D = Node2D.new()
	add_child_autofree(host)
	var blast: BlastFx = BlastFx.new()
	host.add_child(blast)
	var before: int = host.get_child_count()
	blast._process(BlastFx.CHARGE_SECONDS + 0.01)
	# Two rings and one burst.
	assert_eq(host.get_child_count(), before + 3)
	blast._process(0.05)
	assert_eq(host.get_child_count(), before + 3)


func test_shock_ring_grows_and_frees_itself() -> void:
	var host: Node2D = Node2D.new()
	add_child_autofree(host)
	var ring: ShockRing = ShockRing.spawn(host, Vector2(10.0, 20.0), 100.0, 0.4, Color.WHITE)
	assert_eq(ring.global_position, Vector2(10.0, 20.0))
	assert_eq(ring.current_radius(), 0.0)
	ring._process(0.1)
	var early: float = ring.current_radius()
	ring._process(0.1)
	assert_gt(ring.current_radius(), early)
	assert_true(ring.current_radius() <= 100.0)
	ring._process(0.5)
	assert_true(ring.is_queued_for_deletion())


func test_shock_ring_waits_for_its_delay() -> void:
	var host: Node2D = Node2D.new()
	add_child_autofree(host)
	var ring: ShockRing = ShockRing.spawn(host, Vector2.ZERO, 100.0, 0.4, Color.WHITE, 3.0, 0.2)
	ring._process(0.1)
	assert_eq(ring.progress(), 0.0)


func test_camera_punch_shakes_then_settles() -> void:
	var camera: RaceCamera = RaceCamera.new()
	add_child_autofree(camera)
	camera.punch(14.0)
	assert_eq(camera.punch_strength(), 14.0)
	camera._process(0.016)
	assert_true(camera.offset.length() <= 14.0 * sqrt(2.0))
	for i: int in 120:
		camera._process(0.05)
	assert_eq(camera.punch_strength(), 0.0)
	assert_eq(camera.offset, Vector2.ZERO)


func test_camera_punch_keeps_the_stronger_shake() -> void:
	var camera: RaceCamera = RaceCamera.new()
	add_child_autofree(camera)
	camera.punch(10.0)
	camera.punch(4.0)
	assert_eq(camera.punch_strength(), 10.0)


func test_every_power_sound_has_a_file() -> void:
	for sfx: int in [
		Sound.Sfx.ROD_CAST,
		Sound.Sfx.ROD_CATCH,
		Sound.Sfx.NET_CAST,
		Sound.Sfx.NET_CATCH,
		Sound.Sfx.BLAST_CAST,
		Sound.Sfx.BLAST_HIT
	]:
		assert_true(ResourceLoader.exists(Sound.SFX_PATHS[sfx]), "missing sfx %d" % sfx)
