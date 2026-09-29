class_name TwitchEventSubSource
extends ChatSource
## Reads chat via Twitch EventSub WebSocket (channel.chat.message).
## Never logs the access token.

## Emitted on unrecoverable errors (bad token, missing scope, revoked subscription).
## The source stops and does not reconnect.
signal failed(reason: String)

const EVENTSUB_URL: String = "wss://eventsub.wss.twitch.tv/ws"
const SUBSCRIPTIONS_URL: String = "https://api.twitch.tv/helix/eventsub/subscriptions"
const MAX_BACKOFF: float = 30.0
## Seconds to wait for a session_welcome before retrying the connection.
const WELCOME_TIMEOUT: float = 10.0

var client_id: String = ""
var access_token: String = ""
var broadcaster_id: String = ""
## Id of the user the token belongs to. Defaults to the broadcaster.
var user_id: String = ""

var _socket: WebSocketPeer = null
## Socket opened for a session_reconnect; takes over once it welcomes us.
var _pending_socket: WebSocketPeer = null
var _running: bool = false
var _session_id: String = ""
var _keepalive_timeout: float = 10.0
var _since_last_message: float = 0.0
var _backoff: float = 1.0
var _reconnect_in: float = -1.0


func _init(
	p_client_id: String = "",
	p_token: String = "",
	p_broadcaster_id: String = "",
	p_user_id: String = ""
) -> void:
	client_id = p_client_id
	access_token = p_token
	broadcaster_id = p_broadcaster_id
	user_id = p_user_id if not p_user_id.is_empty() else p_broadcaster_id


func start() -> void:
	stop()
	_running = true
	_connect(EVENTSUB_URL)


func stop() -> void:
	_running = false
	_reconnect_in = -1.0
	for s: WebSocketPeer in [_socket, _pending_socket]:
		if s != null:
			s.close()
	_socket = null
	_pending_socket = null


## Pure parser. Takes a raw EventSub JSON frame and returns:
## {"type": String, "session_id": String, "keepalive_timeout": float,
##  "reconnect_url": String, "message": ChatMessage or null}
## "type" is the metadata message_type ("" if the frame is invalid).
static func parse_frame(raw: String) -> Dictionary:
	var result: Dictionary = {
		"type": "",
		"session_id": "",
		"keepalive_timeout": 0.0,
		"reconnect_url": "",
		"message": null,
	}
	var parser := JSON.new()
	if parser.parse(raw) != OK or not parser.data is Dictionary:
		return result
	var data: Dictionary = parser.data
	var metadata: Variant = data.get("metadata", {})
	var payload: Variant = data.get("payload", {})
	if not metadata is Dictionary or not payload is Dictionary:
		return result
	var type: String = str((metadata as Dictionary).get("message_type", ""))
	result["type"] = type
	var p: Dictionary = payload
	match type:
		"session_welcome", "session_reconnect":
			var session: Variant = p.get("session", {})
			if session is Dictionary:
				var s: Dictionary = session
				result["session_id"] = str(s.get("id", ""))
				var keepalive: Variant = s.get("keepalive_timeout_seconds")
				if keepalive is float or keepalive is int:
					result["keepalive_timeout"] = float(keepalive)
				var url: Variant = s.get("reconnect_url")
				result["reconnect_url"] = str(url) if url != null else ""
		"notification":
			var sub: Variant = p.get("subscription", {})
			if sub is Dictionary and (sub as Dictionary).get("type") == "channel.chat.message":
				result["message"] = parse_chat_event(p.get("event", {}))
	return result


## Converts a channel.chat.message "event" object to a ChatMessage (null if invalid).
static func parse_chat_event(event: Variant) -> ChatMessage:
	if not event is Dictionary:
		return null
	var e: Dictionary = event
	var chatter_id: String = str(e.get("chatter_user_id", ""))
	var message: Variant = e.get("message")
	if chatter_id.is_empty() or not message is Dictionary:
		return null
	var m: Dictionary = message
	var emotes: Array[Dictionary] = []
	var fragments: Variant = m.get("fragments", [])
	if fragments is Array:
		for frag: Variant in fragments:
			if frag is Dictionary and (frag as Dictionary).get("type") == "emote":
				var f: Dictionary = frag
				var emote: Variant = f.get("emote", {})
				var emote_id: String = ""
				if emote is Dictionary:
					emote_id = str((emote as Dictionary).get("id", ""))
				emotes.append({"id": emote_id, "text": str(f.get("text", ""))})
	return ChatMessage.create(
		chatter_id,
		str(e.get("chatter_user_login", "")),
		str(e.get("chatter_user_name", "")),
		str(m.get("text", "")),
		emotes
	)


## Builds the Helix subscription request body.
func build_subscription_body(session_id: String) -> Dictionary:
	return {
		"type": "channel.chat.message",
		"version": "1",
		"condition": {"broadcaster_user_id": broadcaster_id, "user_id": user_id},
		"transport": {"method": "websocket", "session_id": session_id},
	}


func _process(delta: float) -> void:
	if not _running:
		return
	if _pending_socket != null:
		_poll_pending()
	if _reconnect_in >= 0.0:
		_reconnect_in -= delta
		if _reconnect_in < 0.0:
			_connect(EVENTSUB_URL)
		return
	if _socket == null:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while _socket.get_available_packet_count() > 0:
				_since_last_message = 0.0
				_handle_frame(_socket.get_packet().get_string_from_utf8(), false)
			_since_last_message += delta
			# Twitch asks clients to treat silence beyond the keepalive as a dead connection.
			if _session_id != "" and _since_last_message > _keepalive_timeout + 5.0:
				_socket.close()
			elif _session_id == "" and _since_last_message > WELCOME_TIMEOUT:
				_socket.close()
		WebSocketPeer.STATE_CONNECTING:
			_since_last_message += delta
			if _since_last_message > WELCOME_TIMEOUT:
				_socket.close()
		WebSocketPeer.STATE_CLOSED:
			_on_unexpected_close()


func _connect(url: String) -> void:
	if _pending_socket != null:
		_pending_socket.close()
		_pending_socket = null
	_socket = WebSocketPeer.new()
	_session_id = ""
	_since_last_message = 0.0
	var err: Error = _socket.connect_to_url(url)
	if err != OK:
		push_warning("EventSub connect failed: %s" % error_string(err))
		_on_unexpected_close()


func _on_unexpected_close() -> void:
	if _pending_socket != null:
		# A reconnect handoff is in flight: let it take over instead of starting over.
		_socket = null
		_session_id = ""
		return
	_socket = null
	_session_id = ""
	_reconnect_in = _backoff
	_backoff = minf(_backoff * 2.0, MAX_BACKOFF)


func _poll_pending() -> void:
	_pending_socket.poll()
	if _pending_socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_pending_socket = null
		if _socket == null:
			_on_unexpected_close()
		return
	while (
		_pending_socket != null
		and _pending_socket.get_ready_state() == WebSocketPeer.STATE_OPEN
		and _pending_socket.get_available_packet_count() > 0
	):
		_handle_frame(_pending_socket.get_packet().get_string_from_utf8(), true)


func _handle_frame(raw: String, from_pending: bool) -> void:
	var frame: Dictionary = parse_frame(raw)
	match frame["type"]:
		"session_welcome":
			_backoff = 1.0
			_keepalive_timeout = maxf(float(frame["keepalive_timeout"]), 1.0)
			if from_pending:
				# Reconnect finished: the new session inherits the subscriptions.
				if _socket != null:
					_socket.close()
				_socket = _pending_socket
				_pending_socket = null
				_session_id = frame["session_id"]
			else:
				_session_id = frame["session_id"]
				_subscribe(_session_id)
		"session_reconnect":
			var url: String = frame["reconnect_url"]
			if not url.is_empty() and _pending_socket == null:
				_pending_socket = WebSocketPeer.new()
				var err: Error = _pending_socket.connect_to_url(url)
				if err != OK:
					push_warning("EventSub reconnect failed: %s" % error_string(err))
					_pending_socket = null
		"notification":
			var msg: ChatMessage = frame["message"]
			if msg != null:
				message_received.emit(msg)
		"revocation":
			_fail("EventSub subscription revoked (token invalid or scope missing?)")
		_:
			pass  # session_keepalive and unknown types


func _subscribe(session_id: String) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_subscribe_completed.bind(req))
	var headers: PackedStringArray = [
		"Authorization: Bearer %s" % access_token,
		"Client-Id: %s" % client_id,
		"Content-Type: application/json",
	]
	var body: String = JSON.stringify(build_subscription_body(session_id))
	var err: Error = req.request(SUBSCRIPTIONS_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("EventSub subscribe request failed: %s" % error_string(err))
		req.queue_free()


func _on_subscribe_completed(
	_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest
) -> void:
	req.queue_free()
	if code >= 200 and code < 300:
		return
	var detail: String = body.get_string_from_utf8()
	if code == 401 or code == 403:
		_fail("EventSub subscribe rejected (HTTP %d): %s" % [code, detail])
	else:
		push_warning("EventSub subscribe returned HTTP %d: %s" % [code, detail])


func _fail(reason: String) -> void:
	push_warning(reason)
	stop()
	failed.emit(reason)
