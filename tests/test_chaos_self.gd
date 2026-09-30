extends GutTest
## #boost and #curse on your own fish are rejected without charge.

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


func test_cannot_boost_own_fish() -> void:
	_say("a", "#boost alice")
	assert_eq(_rejections, ["self_boost"] as Array[String])
	assert_eq(_requests.size(), 0)
	assert_eq(_balance("a"), 1000)


func test_cannot_curse_own_fish() -> void:
	_say("b", "#curse @Bob")
	assert_eq(_rejections, ["self_curse"] as Array[String])
	assert_eq(_requests.size(), 0)
	assert_eq(_balance("b"), 1000)


func test_own_fish_check_uses_user_id_not_name() -> void:
	# Same display name as Alice, different user id: not their fish.
	_say("Alice", "#boost alice")
	assert_eq(_requests, [[0, Chaos.Kind.BOOST]] as Array[Array])
	# Owner of Bob acting under another display name is still blocked.
	_source.inject("b", "Somebody", "#curse bob")
	assert_eq(_rejections, ["self_curse"] as Array[String])


func test_rejected_self_effect_does_not_start_cooldowns() -> void:
	_say("a", "#boost alice")
	_say("a", "#boost bob")
	assert_eq(_requests, [[1, Chaos.Kind.BOOST]] as Array[Array])
