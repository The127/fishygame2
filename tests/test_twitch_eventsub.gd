# gdlint: ignore=max-line-length
extends GutTest

const WELCOME: String = """{"metadata":{"message_id":"96a3f3b5","message_type":"session_welcome","message_timestamp":"2023-07-19T14:56:51.634234626Z"},"payload":{"session":{"id":"AQoQILE98gGXX","status":"connected","connected_at":"2023-07-19T14:56:51.616329898Z","keepalive_timeout_seconds":10,"reconnect_url":null}}}"""
const RECONNECT: String = """{"metadata":{"message_id":"84c1e79a","message_type":"session_reconnect","message_timestamp":"2022-11-18T09:10:11.634234626Z"},"payload":{"session":{"id":"AQoQ","status":"reconnecting","keepalive_timeout_seconds":null,"reconnect_url":"wss://eventsub.wss.twitch.tv?...","connected_at":"2022-11-16T10:11:12.634234626Z"}}}"""
const KEEPALIVE: String = """{"metadata":{"message_id":"84c1e79a","message_type":"session_keepalive","message_timestamp":"2023-07-19T10:11:12.634234626Z"},"payload":{}}"""
const REVOCATION: String = """{"metadata":{"message_id":"84c1e79a","message_type":"revocation","message_timestamp":"2022-11-16T10:11:12.464757833Z","subscription_type":"channel.chat.message","subscription_version":"1"},"payload":{"subscription":{"id":"f1c2a387","status":"authorization_revoked","type":"channel.chat.message","version":"1","cost":1,"condition":{"broadcaster_user_id":"1337","user_id":"1338"},"transport":{"method":"websocket","session_id":"AQoQ"},"created_at":"2022-11-16T10:11:12.464757833Z"}}}"""
const NOTIFICATION: String = """{"metadata":{"message_id":"befa7b53","message_type":"notification","message_timestamp":"2023-11-06T18:11:47.492253549Z","subscription_type":"channel.chat.message","subscription_version":"1"},"payload":{"subscription":{"id":"4aa632e0","type":"channel.chat.message","version":"1","status":"enabled","cost":0,"condition":{"broadcaster_user_id":"1971641","user_id":"2914196"},"transport":{"method":"websocket","session_id":"AgoQ"},"created_at":"2023-11-06T18:04:47.692Z"},"event":{"broadcaster_user_id":"1971641","broadcaster_user_login":"streamer","broadcaster_user_name":"streamer","chatter_user_id":"4145994","chatter_user_login":"viewer32","chatter_user_name":"viewer32","message_id":"cc106a89","message":{"text":"#join Kappa hi","fragments":[{"type":"text","text":"#join ","cheermote":null,"emote":null,"mention":null},{"type":"emote","text":"Kappa","cheermote":null,"emote":{"id":"25","emote_set_id":"0","owner_id":"0","format":["static"]},"mention":null},{"type":"text","text":" hi","cheermote":null,"emote":null,"mention":null}]},"color":"#00FF7F","badges":[],"message_type":"text","cheer":null,"reply":null,"channel_points_custom_reward_id":null}}}"""


func test_welcome() -> void:
	var f: Dictionary = TwitchEventSubSource.parse_frame(WELCOME)
	assert_eq(f["type"], "session_welcome")
	assert_eq(f["session_id"], "AQoQILE98gGXX")
	assert_eq(f["keepalive_timeout"], 10.0)
	assert_eq(f["reconnect_url"], "")


func test_reconnect() -> void:
	var f: Dictionary = TwitchEventSubSource.parse_frame(RECONNECT)
	assert_eq(f["type"], "session_reconnect")
	assert_eq(f["reconnect_url"], "wss://eventsub.wss.twitch.tv?...")


func test_keepalive_and_revocation() -> void:
	assert_eq(TwitchEventSubSource.parse_frame(KEEPALIVE)["type"], "session_keepalive")
	assert_eq(TwitchEventSubSource.parse_frame(REVOCATION)["type"], "revocation")
	assert_null(TwitchEventSubSource.parse_frame(REVOCATION)["message"])


func test_notification_message() -> void:
	var f: Dictionary = TwitchEventSubSource.parse_frame(NOTIFICATION)
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
