class_name AutoJoin
extends Node
## "Auto-join chatters": while a lobby is open, a viewer who says anything in chat joins the
## race without typing "#join". Viewers who chatted within [member recent_seconds] before a
## lobby opens join it as it opens, most recent first, so quiet viewers are not dropped every
## round. Lurkers, the game's own chat account and [member ignored] logins never auto-join.
##
## The node only asks: it emits [signal join_wanted] and the owner joins through the normal
## [method GameFlow.join] path, so the same rules and the player cap apply.

## The viewer of [param msg] should join the open lobby, without a word on rejection.
signal join_wanted(msg: ChatMessage)

var enabled: bool = false
## How far back a chat message still counts when a lobby opens, in seconds. 0 means only
## messages sent while the lobby is open.
var recent_seconds: float = 300.0
## Lower-case logins that never auto-join, see [method set_ignored].
var ignored: Dictionary[String, bool] = {}
## Where the lurking is kept, shared with [Lurkers]. Set by the owner.
var store: ShopStore = null
## Spots "#lurk" messages, which must not join their sender first. Set by the owner.
var parser: CommandParser = CommandParser.new()
## The user id the game posts its chat lines as, or "". Set by the owner.
var own_user_id: Callable = func() -> String: return ""

var _lobby_open: bool = false
var _clock: float = 0.0
## user_id -> {"msg": ChatMessage, "at": float}, the latest message of each recent chatter.
var _recent: Dictionary[String, Dictionary] = {}


func _process(delta: float) -> void:
	tick(delta)


## Advances the clock of [member recent_seconds]. Called every frame; tests call it directly.
func tick(delta: float) -> void:
	_clock += delta


## Takes the streamer's auto-join settings.
func apply(settings: GameSettings) -> void:
	enabled = settings.auto_join_chatters
	recent_seconds = float(settings.auto_join_recent)
	set_ignored(settings.auto_join_ignore)


## Sets [member ignored] from a list of logins separated by commas or spaces ("@" optional).
func set_ignored(text: String) -> void:
	ignored = parse_logins(text)


## Feed it Chat.message_received.
func handle_message(msg: ChatMessage) -> void:
	if not enabled or not _may_join(msg):
		return
	var parsed: Dictionary = parser.parse(msg.text)
	if not parsed.is_empty() and parsed["command"] == Lurkers.COMMAND:
		return
	_recent[msg.user_id] = {"msg": msg, "at": _clock}
	if _lobby_open:
		join_wanted.emit(msg)


## Feed it GameFlow.state_changed, after anything else that fills a fresh lobby: a lobby
## opening asks for the recent chatters (see [method lobby_opened]).
func on_state_changed(new_state: GameFlow.State, _old_state: GameFlow.State) -> void:
	_lobby_open = new_state == GameFlow.State.LOBBY
	if _lobby_open:
		lobby_opened()


## Asks to join the recent chatters into the lobby that just opened, most recent first, and
## forgets everyone older than [member recent_seconds].
func lobby_opened() -> void:
	var cutoff: float = _clock - recent_seconds
	var chatters: Array[Dictionary] = []
	for user_id: String in _recent.keys():
		var entry: Dictionary = _recent[user_id]
		if float(entry["at"]) < cutoff or recent_seconds <= 0.0:
			_recent.erase(user_id)
		else:
			chatters.append(entry)
	if not enabled or not _lobby_open:
		return
	chatters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] > b["at"])
	for entry: Dictionary in chatters:
		var msg: ChatMessage = entry["msg"]
		if _may_join(msg):
			join_wanted.emit(msg)


## Whether the viewer of [param msg] may be auto-joined at all.
func _may_join(msg: ChatMessage) -> bool:
	if msg.user_id.is_empty() or msg.user_id == String(own_user_id.call()):
		return false
	if ignored.has(msg.login.to_lower()) or ignored.has(msg.display_name.to_lower()):
		return false
	return store == null or not store.is_lurking(msg.user_id)


## Lower-case logins of [param text], separated by commas or whitespace, "@" stripped.
static func parse_logins(text: String) -> Dictionary[String, bool]:
	var logins: Dictionary[String, bool] = {}
	for part: String in text.replace(",", " ").split(" ", false):
		var login: String = part.strip_edges().trim_prefix("@").to_lower()
		if not login.is_empty():
			logins[login] = true
	return logins
