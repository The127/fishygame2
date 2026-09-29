extends GutTest

var _chaos: Chaos
var _chat: Node
var _source: DebugChatSource
var _requests: Array[Array] = []
var _rejections: Array[String] = []


func before_each() -> void:
	_requests.clear()
	_rejections.clear()
	_chaos = Chaos.new()
	_chaos.points = PointsStore.new("", 1000)
	add_child_autofree(_chaos)
	_chat = load("res://scripts/chat/chat.gd").new()
	add_child_autofree(_chat)
	_source = DebugChatSource.new()
	_chat.set_source(_source)
	_chat.command_received.connect(_chaos.handle_command)
	_chaos.effect_requested.connect(
		func(id: int, kind: Chaos.Kind) -> void: _requests.append([id, kind])
	)
	_chaos.effect_rejected.connect(
		func(_msg: ChatMessage, reason: String) -> void: _rejections.append(reason)
	)
	_chaos.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.IDLE)
	_chaos.add_contestant(Contestant.create("a", "Alice"))
	_chaos.add_contestant(Contestant.create("b", "Bob"))
	_chaos.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)


func _say(user_id: String, text: String) -> void:
	_source.inject(user_id, user_id, text)


func _balance(user_id: String) -> int:
	return _chaos.points.get_balance(user_id)


func test_boost_charges_and_requests_effect() -> void:
	_say("v", "#boost bob")
	assert_eq(_requests, [[1, Chaos.Kind.BOOST]] as Array[Array])
	assert_eq(_balance("v"), 1000 - _chaos.boost_cost)


func test_curse_costs_more_and_accepts_at_prefix() -> void:
	_say("v", "#curse @Alice")
	assert_eq(_requests, [[0, Chaos.Kind.CURSE]] as Array[Array])
	assert_eq(_balance("v"), 1000 - _chaos.curse_cost)


func test_rejected_outside_race() -> void:
	_chaos.on_state_changed(GameFlow.State.PODIUM, GameFlow.State.RACING)
	_say("v", "#boost bob")
	assert_eq(_rejections, ["closed"] as Array[String])
	assert_eq(_balance("v"), 1000)


func test_usage_and_unknown_fish_are_free() -> void:
	_say("v", "#boost")
	_say("v", "#boost nobody")
	assert_eq(_rejections, ["usage", "unknown_fish"] as Array[String])
	assert_eq(_balance("v"), 1000)
	assert_eq(_requests.size(), 0)


func test_insufficient_points() -> void:
	_chaos.points.set_balance("v", 50)
	_say("v", "#boost bob")
	assert_eq(_rejections, ["insufficient"] as Array[String])
	assert_eq(_balance("v"), 50)
	assert_eq(_requests.size(), 0)


func test_viewer_cooldown() -> void:
	_say("v", "#boost bob")
	_chaos.tick(_chaos.fish_lockout + 0.1)
	_say("v", "#boost alice")
	assert_eq(_rejections, ["cooldown"] as Array[String])
	assert_eq(_requests.size(), 1)
	_chaos.tick(_chaos.viewer_cooldown)
	_say("v", "#boost alice")
	assert_eq(_requests.size(), 2)


func test_fish_lockout_applies_across_viewers() -> void:
	_say("v", "#curse bob")
	_say("w", "#curse bob")
	assert_eq(_rejections, ["fish_busy"] as Array[String])
	assert_eq(_balance("w"), 1000)
	_chaos.tick(_chaos.fish_lockout)
	_say("w", "#curse bob")
	assert_eq(_requests.size(), 2)


func test_finished_fish_cannot_be_targeted() -> void:
	_chaos.on_marble_finished(1, 1)
	_say("v", "#boost bob")
	assert_eq(_rejections, ["finished"] as Array[String])
	assert_eq(_balance("v"), 1000)


func test_new_race_resets_cooldowns() -> void:
	_say("v", "#boost bob")
	_chaos.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.PODIUM)
	_chaos.add_contestant(Contestant.create("a", "Alice"))
	_chaos.add_contestant(Contestant.create("b", "Bob"))
	_chaos.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	_say("v", "#boost bob")
	assert_eq(_requests.size(), 2)


func test_command_after_race_finished_is_free() -> void:
	_chaos.on_race_finished([] as Array[Dictionary])
	_say("v", "#boost bob")
	assert_eq(_rejections, ["closed"] as Array[String])
	assert_eq(_requests.size(), 0)
	assert_eq(_balance("v"), 1000)


func test_abort_mid_race_refunds_spend() -> void:
	_say("v", "#boost bob")
	_say("w", "#curse alice")
	_chaos.on_state_changed(GameFlow.State.IDLE, GameFlow.State.RACING)
	assert_eq(_balance("v"), 1000)
	assert_eq(_balance("w"), 1000)
	_chaos.on_state_changed(GameFlow.State.IDLE, GameFlow.State.LOBBY)
	assert_eq(_balance("v"), 1000)


func test_finished_race_keeps_spend() -> void:
	_say("v", "#boost bob")
	_chaos.on_state_changed(GameFlow.State.PODIUM, GameFlow.State.RACING)
	_chaos.on_state_changed(GameFlow.State.IDLE, GameFlow.State.PODIUM)
	assert_eq(_balance("v"), 1000 - _chaos.boost_cost)


func test_marble_effects_change_velocity() -> void:
	var marble: Marble = load("res://scenes/marble.tscn").instantiate()
	add_child_autofree(marble)
	marble.gravity_scale = 0.0
	marble.boost(Vector2.RIGHT)
	await wait_physics_frames(2)
	assert_gt(marble.linear_velocity.x, 100.0)
	marble.linear_velocity = Vector2.ZERO
	marble.curse(Vector2.RIGHT)
	await wait_physics_frames(2)
	assert_lt(marble.linear_velocity.x, -50.0)
	assert_true(marble.is_cursed())
	assert_gt(marble.linear_damp, 1.0)
