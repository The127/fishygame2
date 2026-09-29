extends Node
## Autoload "Chat": owns the active chat source and republishes its messages
## and parsed commands. Without Twitch config it falls back to the debug source, only in debug mode.

signal message_received(msg: ChatMessage)
signal command_received(msg: ChatMessage, command: String, args: PackedStringArray)
## Emitted whenever the streamer login state (`login_status`, `session`, `login_error`) changes.
signal login_changed

const CONFIG_PATH: String = "user://twitch.cfg"

var parser: CommandParser = CommandParser.new()
var source: ChatSource = null
var store: TwitchSessionStore = TwitchSessionStore.new()
## Logged in streamer: {client_id, token, user_id, login, expires_at}, or {} when logged out.
var session: Dictionary = {}
var login_status: TwitchAuth.LoginStatus = TwitchAuth.LoginStatus.LOGGED_OUT
var login_error: String = ""


func _ready() -> void:
	if source != null:
		return
	var fragment: String = _take_redirect_fragment()
	var cfg: Dictionary = load_twitch_config()
	if cfg.is_empty():
		cfg = _config_from_stored_session()
	if not cfg.is_empty():
		_use_config(cfg)
	elif DebugMode.is_enabled():
		set_source(DebugChatSource.new())
	if not fragment.is_empty():
		_finish_login(fragment)


## Sends the browser to Twitch to authorize this game. Web only; the page comes back with
## the token in the URL fragment, which `_ready` picks up.
func begin_login(client_id: String) -> void:
	client_id = client_id.strip_edges()
	if client_id.is_empty() or not OS.has_feature("web"):
		return
	_redirect_to_twitch(client_id, TwitchAuth.current_redirect_url())


## Redirects to Twitch, unless the pending login could not be stored: then the streamer would
## come back unable to finish, so show an error instead. Returns whether it redirected.
func _redirect_to_twitch(client_id: String, redirect: String) -> bool:
	var state: String = TwitchAuth.generate_state()
	if not store.save_pending_login(state, client_id):
		_login_failed("Could not save the login in this browser (is site storage blocked?)")
		return false
	var url: String = TwitchAuth.build_authorize_url(client_id, redirect, state)
	JavaScriptBridge.eval("window.location.href = %s" % JSON.stringify(url))
	return true


## Forgets the stored login, revokes the token at Twitch and falls back to the debug source.
func logout() -> void:
	if not session.is_empty():
		_revoke(str(session["client_id"]), str(session["token"]))
	store.clear_session()
	session = {}
	login_error = ""
	_set_login_status(TwitchAuth.LoginStatus.LOGGED_OUT)
	if source is TwitchEventSubSource:
		if DebugMode.is_enabled():
			set_source(DebugChatSource.new())
		else:
			_clear_source()


func _clear_source() -> void:
	if source == null:
		return
	source.stop()
	source.message_received.disconnect(_on_message)
	source.queue_free()
	source = null


func set_source(new_source: ChatSource) -> void:
	if new_source == null or new_source == source:
		return
	if source != null:
		source.stop()
		source.message_received.disconnect(_on_message)
		source.queue_free()
	source = new_source
	add_child(source)
	source.message_received.connect(_on_message)
	source.start()


## Posts a message to the channel through the active source.
func send_message(text: String) -> void:
	if source != null:
		source.send_message(text)


## Returns {client_id, token, broadcaster_id[, user_id]} or {} if not configured.
## Web: URL query params. Desktop: user://twitch.cfg, section [twitch].
func load_twitch_config() -> Dictionary:
	var cfg: Dictionary = {}
	if OS.has_feature("web"):
		DebugMode.is_enabled()  # cache it before the query string is wiped below
		for key: String in ["client_id", "token", "broadcaster_id", "user_id"]:
			var value: Variant = JavaScriptBridge.eval(
				"new URLSearchParams(window.location.search).get('%s')" % key
			)
			if value != null and str(value) != "":
				cfg[key] = str(value)
		# The token is a secret: keep it out of the address bar and history.
		JavaScriptBridge.eval("history.replaceState(null, '', window.location.pathname)")
	else:
		var file := ConfigFile.new()
		if file.load(CONFIG_PATH) == OK:
			for key: String in ["client_id", "token", "broadcaster_id", "user_id"]:
				var value: String = str(file.get_value("twitch", key, ""))
				if value != "":
					cfg[key] = value
	for required: String in ["client_id", "token", "broadcaster_id"]:
		if not cfg.has(required):
			if cfg.has("token") or cfg.has("client_id") or cfg.has("broadcaster_id"):
				push_warning("Twitch config incomplete, missing: %s" % required)
			return {}
	return cfg


func _use_config(cfg: Dictionary) -> void:
	var twitch := TwitchEventSubSource.new(
		cfg["client_id"], cfg["token"], cfg["broadcaster_id"], cfg.get("user_id", "")
	)
	twitch.failed.connect(_on_source_failed.bind(twitch))
	set_source(twitch)


## A stored login that is still valid, in the same shape as `load_twitch_config`.
func _config_from_stored_session() -> Dictionary:
	var saved: Dictionary = store.load_session()
	if saved.is_empty():
		return {}
	if TwitchAuth.is_expired(saved, int(Time.get_unix_time_from_system())):
		store.clear_session()
		login_error = "Twitch login expired, please log in again"
		_set_login_status(TwitchAuth.LoginStatus.ERROR)
		return {}
	session = saved
	login_status = TwitchAuth.LoginStatus.LOGGED_IN
	return {
		"client_id": saved["client_id"],
		"token": saved["token"],
		"broadcaster_id": saved["user_id"],
		"user_id": saved["user_id"],
	}


## Returns the URL fragment (if any) and removes it from the address bar and history.
func _take_redirect_fragment() -> String:
	if not OS.has_feature("web"):
		return ""
	# The export's head script already stashed the hash and cleared it from the address bar.
	var fragment: String = str(
		JavaScriptBridge.eval("window.__twitchHash || window.location.hash || ''")
	)
	JavaScriptBridge.eval("window.__twitchHash = ''")
	if fragment.length() > 1:
		JavaScriptBridge.eval("history.replaceState(null, '', window.location.pathname)")
		return fragment
	return ""


func _finish_login(fragment: String) -> void:
	var params: Dictionary = TwitchAuth.parse_fragment(fragment)
	if params.has("error"):
		store.take_pending_state()
		_login_failed("Twitch login was cancelled or denied")
		return
	if not params.has("access_token"):
		return  # Some other fragment, not ours.
	var expected_state: String = store.take_pending_state()
	var client_id: String = store.load_client_id()
	if expected_state.is_empty() or str(params.get("state", "")) != expected_state:
		_login_failed("Twitch login state did not match, please try again")
		return
	if client_id.is_empty():
		_login_failed("Twitch client id is missing, please try again")
		return
	_set_login_status(TwitchAuth.LoginStatus.VALIDATING)
	var token: String = str(params["access_token"])
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_validate_completed.bind(req, token, client_id))
	var headers: PackedStringArray = ["Authorization: OAuth %s" % token]
	if req.request(TwitchAuth.VALIDATE_URL, headers) != OK:
		req.queue_free()
		_login_failed("Could not reach Twitch to validate the login")


func _on_validate_completed(
	result: int,
	code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	req: HTTPRequest,
	token: String,
	client_id: String
) -> void:
	req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		_login_failed("Could not reach Twitch to validate the login")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if code != 200 or not parsed is Dictionary:
		_login_failed("Twitch rejected the login (HTTP %d)" % code)
		return
	var checked: Dictionary = TwitchAuth.session_from_validation(
		token, client_id, parsed, int(Time.get_unix_time_from_system())
	)
	if checked.has("error"):
		_revoke(client_id, token)
		_login_failed(str(checked["error"]))
		return
	session = checked["session"]
	store.save_session(session)
	login_error = ""
	_use_config(
		{
			"client_id": session["client_id"],
			"token": session["token"],
			"broadcaster_id": session["user_id"],
			"user_id": session["user_id"],
		}
	)
	_set_login_status(TwitchAuth.LoginStatus.LOGGED_IN)


func _revoke(client_id: String, token: String) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(
		func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void: req.queue_free()
	)
	var body: String = "client_id=%s&token=%s" % [client_id.uri_encode(), token.uri_encode()]
	var headers: PackedStringArray = ["Content-Type: application/x-www-form-urlencoded"]
	if req.request(TwitchAuth.REVOKE_URL, headers, HTTPClient.METHOD_POST, body) != OK:
		req.queue_free()


func _on_source_failed(reason: String, failed_source: ChatSource) -> void:
	if failed_source != source or session.is_empty():
		return
	# The stored login no longer works (revoked or expired): forget it.
	store.clear_session()
	session = {}
	login_error = "Twitch login no longer works: %s" % reason
	_set_login_status(TwitchAuth.LoginStatus.ERROR)


func _login_failed(reason: String) -> void:
	push_warning(reason)
	login_error = reason
	_set_login_status(TwitchAuth.LoginStatus.ERROR)


func _set_login_status(status: TwitchAuth.LoginStatus) -> void:
	login_status = status
	login_changed.emit()


func _on_message(msg: ChatMessage) -> void:
	message_received.emit(msg)
	var parsed: Dictionary = parser.parse(msg.text)
	if not parsed.is_empty():
		command_received.emit(msg, parsed["command"], parsed["args"])
