extends GutTest
## AutoJoin on its own: who it asks to join, when, and in which order.

var _auto: AutoJoin
var _store: ShopStore
var _wanted: Array[String] = []


func before_each() -> void:
	_store = ShopStore.new()
	_auto = AutoJoin.new()
	_auto.store = _store
	_auto.enabled = true
	_auto.recent_seconds = 60.0
	_wanted = []
	_auto.join_wanted.connect(func(msg: ChatMessage) -> void: _wanted.append(msg.user_id))
	add_child_autofree(_auto)


func _say(user_id: String, text: String = "hello") -> void:
	_auto.handle_message(ChatMessage.create(user_id, "user" + user_id, "User" + user_id, text))


func _open_lobby() -> void:
	_auto.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.PODIUM)


func _start_race() -> void:
	_auto.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)


func test_chatting_in_an_open_lobby_asks_to_join() -> void:
	_open_lobby()
	_say("a")
	_say("b", "#bet a 10")
	assert_eq(_wanted, ["a", "b"])


func test_off_asks_for_nobody() -> void:
	_auto.enabled = false
	_open_lobby()
	_say("a")
	_start_race()
	_open_lobby()
	assert_eq(_wanted, [])


func test_chatting_during_a_race_joins_the_next_lobby_most_recent_first() -> void:
	_start_race()
	_say("a")
	_auto.tick(5.0)
	_say("b")
	_auto.tick(5.0)
	_say("c")
	_say("a", "again")
	assert_eq(_wanted, [], "no lobby to join yet")
	_open_lobby()
	assert_eq(_wanted, ["a", "c", "b"])


func test_chatters_older_than_the_window_are_forgotten() -> void:
	_start_race()
	_say("old")
	_auto.tick(61.0)
	_say("new")
	_open_lobby()
	assert_eq(_wanted, ["new"])
	_wanted.clear()
	_start_race()
	_open_lobby()
	assert_eq(_wanted, ["new"], "still inside the window")


func test_a_zero_window_only_counts_the_open_lobby() -> void:
	_auto.recent_seconds = 0.0
	_start_race()
	_say("a")
	_open_lobby()
	assert_eq(_wanted, [])


func test_lurkers_never_auto_join() -> void:
	_store.set_lurking("a", true)
	_start_race()
	_say("a")
	_say("b")
	_open_lobby()
	_say("a")
	assert_eq(_wanted, ["b"])


func test_a_viewer_who_lurks_after_chatting_is_not_joined() -> void:
	_start_race()
	_say("a")
	_store.set_lurking("a", true)
	_open_lobby()
	assert_eq(_wanted, [])


func test_the_lurk_command_itself_does_not_join() -> void:
	_open_lobby()
	_say("a", "#lurk")
	assert_eq(_wanted, [])


func test_ignored_logins_and_the_games_own_account_never_auto_join() -> void:
	_auto.set_ignored("@UserBot, usernightbot  userx")
	_auto.own_user_id = func() -> String: return "me"
	_open_lobby()
	for user_id: String in ["Bot", "nightbot", "x", "me", "y"]:
		_say(user_id)
	assert_eq(_wanted, ["y"])


func test_parse_logins() -> void:
	assert_eq(
		AutoJoin.parse_logins(" @NightBot,,StreamElements  moobot ").keys(),
		["nightbot", "streamelements", "moobot"]
	)
	assert_true(AutoJoin.parse_logins("").is_empty())
