class_name TwitchAuth
extends RefCounted
## Pure helpers for the Twitch OAuth implicit grant (no backend needed in the browser).
## Nothing here logs or prints a token.

## Where the streamer login stands.
enum LoginStatus { LOGGED_OUT, VALIDATING, LOGGED_IN, ERROR }

const AUTHORIZE_URL: String = "https://id.twitch.tv/oauth2/authorize"
const VALIDATE_URL: String = "https://id.twitch.tv/oauth2/validate"
const REVOKE_URL: String = "https://id.twitch.tv/oauth2/revoke"
## What the game needs: read chat (EventSub) and post to chat (Helix).
const SCOPES: PackedStringArray = ["user:read:chat", "user:write:chat"]
## A token this close to expiry is treated as already expired.
const EXPIRY_MARGIN_SECONDS: int = 60


## The address Twitch must be told to send the streamer back to: this page without query or
## fragment. Empty outside the web build, where there is no page.
static func current_redirect_url() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("window.location.origin + window.location.pathname"))


static func build_authorize_url(client_id: String, redirect_uri: String, state: String) -> String:
	return (
		"%s?response_type=token&client_id=%s&redirect_uri=%s&scope=%s&state=%s&force_verify=true"
		% [
			AUTHORIZE_URL,
			client_id.uri_encode(),
			redirect_uri.uri_encode(),
			" ".join(SCOPES).uri_encode(),
			state.uri_encode(),
		]
	)


## Parses a URL fragment ("#access_token=..&state=..") into a Dictionary of decoded values.
static func parse_fragment(fragment: String) -> Dictionary:
	var out: Dictionary = {}
	for pair: String in fragment.trim_prefix("#").split("&", false):
		var idx: int = pair.find("=")
		if idx < 0:
			continue
		out[pair.substr(0, idx).uri_decode()] = pair.substr(idx + 1).uri_decode()
	return out


## Random hex string for the OAuth `state` parameter (CSRF protection).
static func generate_state() -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(16).hex_encode()


## Checks a /oauth2/validate response. Returns {session} on success or {error} on failure.
## `now` is the unix time used to compute the expiry (injectable for tests).
static func session_from_validation(
	token: String, client_id: String, data: Dictionary, now: int
) -> Dictionary:
	# A token issued to another app must never be accepted.
	if str(data.get("client_id", "")) != client_id:
		return {"error": "Token was issued for a different Twitch app"}
	var scopes_value: Variant = data.get("scopes", [])
	var scopes: Array = scopes_value if scopes_value is Array else []
	for scope: String in SCOPES:
		if not scopes.has(scope):
			return {"error": "Token is missing the scope %s" % scope}
	if str(data.get("user_id", "")).is_empty():
		return {"error": "Token has no user"}
	if int(data.get("expires_in", 0)) <= 0:
		return {"error": "Token has no valid expiry"}
	return {
		"session":
		{
			"client_id": client_id,
			"token": token,
			"user_id": str(data["user_id"]),
			"login": str(data.get("login", "")),
			"expires_at": now + int(data.get("expires_in", 0)),
		}
	}


static func is_expired(session: Dictionary, now: int) -> bool:
	return int(session.get("expires_at", 0)) <= now + EXPIRY_MARGIN_SECONDS


## Text for the streamer about a login status. `login` is the Twitch user, `error` the reason
## for LoginStatus.ERROR, `web` whether this is the web build (login only works there).
static func status_text(status: LoginStatus, login: String, error: String, web: bool) -> String:
	match status:
		LoginStatus.LOGGED_IN:
			return "Logged in as %s" % login
		LoginStatus.VALIDATING:
			return "Checking Twitch login..."
		LoginStatus.ERROR:
			return error
		_:
			return "Not logged in" if web else "Twitch login needs the web build"
