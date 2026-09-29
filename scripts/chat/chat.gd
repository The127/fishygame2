extends Node
## Autoload "Chat": owns the active chat source and republishes its messages
## and parsed commands. Falls back to the debug source without Twitch config.

signal message_received(msg: ChatMessage)
signal command_received(msg: ChatMessage, command: String, args: PackedStringArray)

const CONFIG_PATH: String = "user://twitch.cfg"

var parser: CommandParser = CommandParser.new()
var source: ChatSource = null


func _ready() -> void:
	if source == null:
		var cfg: Dictionary = load_twitch_config()
		if cfg.is_empty():
			set_source(DebugChatSource.new())
		else:
			set_source(
				TwitchEventSubSource.new(
					cfg["client_id"], cfg["token"], cfg["broadcaster_id"], cfg.get("user_id", "")
				)
			)


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


func _on_message(msg: ChatMessage) -> void:
	message_received.emit(msg)
	var parsed: Dictionary = parser.parse(msg.text)
	if not parsed.is_empty():
		command_received.emit(msg, parsed["command"], parsed["args"])
