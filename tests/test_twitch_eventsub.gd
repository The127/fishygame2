extends GutTest

const FIXTURE_DIR: String = "res://tests/fixtures/eventsub/"


func _fixture(file_name: String) -> String:
	return FileAccess.get_file_as_string(FIXTURE_DIR + file_name)


func test_welcome() -> void:
	var f: Dictionary = TwitchEventSubSource.parse_frame(_fixture("welcome.json"))
	assert_eq(f["type"], "session_welcome")
	assert_eq(f["session_id"], "AQoQILE98gGXX")
	assert_eq(f["keepalive_timeout"], 10.0)
	assert_eq(f["reconnect_url"], "")


func test_reconnect() -> void:
	var f: Dictionary = TwitchEventSubSource.parse_frame(_fixture("reconnect.json"))
	assert_eq(f["type"], "session_reconnect")
	assert_eq(f["reconnect_url"], "wss://eventsub.wss.twitch.tv?...")


func test_keepalive_and_revocation() -> void:
	assert_eq(
		TwitchEventSubSource.parse_frame(_fixture("keepalive.json"))["type"], "session_keepalive"
	)
	assert_eq(TwitchEventSubSource.parse_frame(_fixture("revocation.json"))["type"], "revocation")
	assert_null(TwitchEventSubSource.parse_frame(_fixture("revocation.json"))["message"])


func test_notification_message() -> void:
	var f: Dictionary = TwitchEventSubSource.parse_frame(_fixture("notification.json"))
	assert_eq(f["type"], "notification")
	var msg: ChatMessage = f["message"]
	assert_not_null(msg)
	assert_eq(msg.user_id, "4145994")
	assert_eq(msg.login, "viewer32")
	assert_eq(msg.display_name, "viewer32")
	assert_eq(msg.text, "#join Kappa hi")
	assert_eq(msg.emotes.size(), 1)
	assert_eq(msg.emotes[0]["id"], "25")
	assert_eq(msg.emotes[0]["text"], "Kappa")


func test_invalid_input() -> void:
	assert_eq(TwitchEventSubSource.parse_frame("not json")["type"], "")
	assert_eq(TwitchEventSubSource.parse_frame("[1]")["type"], "")


func test_subscription_body() -> void:
	var src := TwitchEventSubSource.new("cid", "tok", "1971641")
	var body: Dictionary = src.build_subscription_body("SID")
	assert_eq(body["type"], "channel.chat.message")
	assert_eq(body["version"], "1")
	assert_eq(body["condition"], {"broadcaster_user_id": "1971641", "user_id": "1971641"})
	assert_eq(body["transport"], {"method": "websocket", "session_id": "SID"})
	src.free()
