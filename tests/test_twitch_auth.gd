extends GutTest

const STORE_PATH: String = "user://test_twitch_session.cfg"

var _store: TwitchSessionStore


func before_each() -> void:
	DirAccess.remove_absolute(STORE_PATH)
	_store = TwitchSessionStore.new(STORE_PATH)


func after_each() -> void:
	DirAccess.remove_absolute(STORE_PATH)


func _valid_data() -> Dictionary:
	return {
		"client_id": "app",
		"login": "streamer",
		"user_id": "123",
		"scopes": ["user:read:chat", "user:write:chat"],
		"expires_in": 3600,
	}


func test_authorize_url_has_scopes_state_and_encoded_redirect() -> void:
	var url: String = TwitchAuth.build_authorize_url("app", "https://x.example/game/", "abc")
	assert_string_starts_with(url, "https://id.twitch.tv/oauth2/authorize?response_type=token")
	assert_string_contains(url, "client_id=app")
	assert_string_contains(url, "redirect_uri=https%3A%2F%2Fx.example%2Fgame%2F")
	assert_string_contains(url, "scope=user%3Aread%3Achat%20user%3Awrite%3Achat")
	assert_string_contains(url, "state=abc")


func test_parse_fragment_decodes_values() -> void:
	var out: Dictionary = TwitchAuth.parse_fragment("#access_token=t%2B1&state=s&scope=a%3Ab")
	assert_eq(out["access_token"], "t+1")
	assert_eq(out["state"], "s")
	assert_eq(out["scope"], "a:b")


func test_parse_fragment_ignores_garbage() -> void:
	assert_eq(TwitchAuth.parse_fragment("#nothing&&=").size(), 1)
	assert_true(TwitchAuth.parse_fragment("").is_empty())


func test_state_is_random_hex() -> void:
	var a: String = TwitchAuth.generate_state()
	assert_eq(a.length(), 32)
	assert_ne(a, TwitchAuth.generate_state())


func test_validation_builds_session() -> void:
	var out: Dictionary = TwitchAuth.session_from_validation("tok", "app", _valid_data(), 1000)
	assert_true(out.has("session"))
	assert_eq(out["session"]["user_id"], "123")
	assert_eq(out["session"]["login"], "streamer")
	assert_eq(out["session"]["expires_at"], 4600)


func test_validation_rejects_other_client_id() -> void:
	var data: Dictionary = _valid_data()
	data["client_id"] = "someone-else"
	assert_true(TwitchAuth.session_from_validation("tok", "app", data, 0).has("error"))


func test_validation_rejects_missing_scope() -> void:
	var data: Dictionary = _valid_data()
	data["scopes"] = ["user:read:chat"]
	assert_true(TwitchAuth.session_from_validation("tok", "app", data, 0).has("error"))


func test_expiry_uses_margin() -> void:
	var session: Dictionary = {"expires_at": 1000}
	assert_true(TwitchAuth.is_expired(session, 1000))
	assert_true(TwitchAuth.is_expired(session, 950))
	assert_false(TwitchAuth.is_expired(session, 900))


func test_store_round_trip_and_clear() -> void:
	var session: Dictionary = {
		"client_id": "app", "token": "tok", "user_id": "1", "login": "s", "expires_at": 5
	}
	assert_true(_store.load_session().is_empty())
	_store.save_session(session)
	assert_eq(TwitchSessionStore.new(STORE_PATH).load_session()["token"], "tok")
	_store.clear_session()
	assert_true(_store.load_session().is_empty())


func test_store_pending_state_is_single_use() -> void:
	_store.save_pending_login("st", "app")
	assert_eq(_store.load_client_id(), "app")
	assert_eq(_store.take_pending_state(), "st")
	assert_eq(_store.take_pending_state(), "")


func _new_chat() -> Node:
	return load("res://scripts/chat/chat.gd").new()


func test_expired_stored_session_is_dropped_by_chat() -> void:
	_store.save_session(
		{"client_id": "app", "token": "tok", "user_id": "1", "login": "s", "expires_at": 1}
	)
	var chat: Node = _new_chat()
	chat.store = _store
	add_child_autofree(chat)
	assert_eq(chat.login_status, "error")
	assert_true(chat.session.is_empty())
	assert_true(_store.load_session().is_empty())
	assert_true(chat.source is DebugChatSource)


func test_valid_stored_session_starts_twitch_source() -> void:
	var future: int = int(Time.get_unix_time_from_system()) + 3600
	_store.save_session(
		{"client_id": "app", "token": "tok", "user_id": "1", "login": "s", "expires_at": future}
	)
	var chat: Node = _new_chat()
	chat.store = _store
	add_child_autofree(chat)
	assert_eq(chat.login_status, "logged_in")
	assert_true(chat.source is TwitchEventSubSource)
	chat.logout()
	assert_eq(chat.login_status, "logged_out")
	assert_true(chat.source is DebugChatSource)
	assert_true(_store.load_session().is_empty())


func test_validation_rejects_bad_scopes_type_and_expiry() -> void:
	var data: Dictionary = _valid_data()
	data["scopes"] = null
	assert_true(TwitchAuth.session_from_validation("tok", "app", data, 0).has("error"))
	data = _valid_data()
	data["expires_in"] = 0
	assert_true(TwitchAuth.session_from_validation("tok", "app", data, 0).has("error"))


func test_store_rejects_wrongly_typed_session() -> void:
	_store.save_session(
		{"client_id": "app", "token": 5, "user_id": "1", "login": "s", "expires_at": 5}
	)
	assert_true(_store.load_session().is_empty())
