extends GutTest
## StreamerPowers: cooldown, per-race cap, the off switch and the racing window.

var _powers: StreamerPowers
var _used: Array[Array] = []
var _rejected: Array[String] = []


func before_each() -> void:
	_used.clear()
	_rejected.clear()
	_powers = StreamerPowers.new()
	_powers.cooldown = 5.0
	_powers.max_per_race = 3
	add_child_autofree(_powers)
	_powers.power_used.connect(
		func(kind: StreamerPowers.Kind, pos: Vector2) -> void: _used.append([kind, pos])
	)
	_powers.power_rejected.connect(
		func(_kind: StreamerPowers.Kind, reason: String) -> void: _rejected.append(reason)
	)
	_powers.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)


func test_power_fires_during_a_race() -> void:
	assert_true(_powers.use(StreamerPowers.Kind.ROD, Vector2(10, 20)))
	assert_eq(_used, [[StreamerPowers.Kind.ROD, Vector2(10, 20)]] as Array[Array])


func test_closed_outside_a_race() -> void:
	_powers.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.RACING)
	assert_false(_powers.use(StreamerPowers.Kind.NET, Vector2.ZERO))
	assert_eq(_rejected, ["closed"] as Array[String])


func test_closes_the_moment_the_race_finishes() -> void:
	_powers.on_race_finished([] as Array[Dictionary])
	assert_false(_powers.use(StreamerPowers.Kind.NET, Vector2.ZERO))
	assert_eq(_rejected, ["closed"] as Array[String])


func test_off_switch_rejects_everything() -> void:
	_powers.enabled = false
	assert_false(_powers.use(StreamerPowers.Kind.BLAST, Vector2.ZERO))
	assert_eq(_rejected, ["off"] as Array[String])


func test_cooldown_is_shared_between_powers() -> void:
	assert_true(_powers.use(StreamerPowers.Kind.ROD, Vector2.ZERO))
	assert_eq(_powers.cooldown_left(), 5.0)
	assert_false(_powers.use(StreamerPowers.Kind.NET, Vector2.ZERO))
	assert_eq(_rejected, ["cooldown"] as Array[String])
	_powers.tick(5.0)
	assert_eq(_powers.cooldown_left(), 0.0)
	assert_true(_powers.use(StreamerPowers.Kind.NET, Vector2.ZERO))


func test_cap_per_race() -> void:
	for i: int in 3:
		assert_true(_powers.use(StreamerPowers.Kind.ROD, Vector2.ZERO))
		_powers.tick(5.0)
	assert_eq(_powers.uses_left(), 0)
	assert_false(_powers.use(StreamerPowers.Kind.ROD, Vector2.ZERO))
	assert_eq(_rejected, ["cap"] as Array[String])


func test_a_new_race_resets_cooldown_and_cap() -> void:
	for i: int in 3:
		_powers.use(StreamerPowers.Kind.ROD, Vector2.ZERO)
		_powers.tick(5.0)
	_powers.on_state_changed(GameFlow.State.PODIUM, GameFlow.State.RACING)
	_powers.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	assert_eq(_powers.uses_left(), 3)
	assert_eq(_powers.cooldown_left(), 0.0)
	assert_true(_powers.use(StreamerPowers.Kind.ROD, Vector2.ZERO))


func test_clock_stands_still_outside_a_race() -> void:
	_powers.use(StreamerPowers.Kind.ROD, Vector2.ZERO)
	_powers.on_race_finished([] as Array[Dictionary])
	_powers.tick(100.0)
	assert_eq(_powers.cooldown_left(), 5.0)
