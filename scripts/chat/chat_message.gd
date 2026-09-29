class_name ChatMessage
extends RefCounted
## A single chat message. Viewers are always keyed by [member user_id] (stable),
## never by login or display name (which can change).

var user_id: String = ""
var login: String = ""
var display_name: String = ""
var text: String = ""
## Emotes used in the message. Each entry: {"id": String, "text": String}.
var emotes: Array[Dictionary] = []


static func create(
	p_user_id: String,
	p_login: String,
	p_display_name: String,
	p_text: String,
	p_emotes: Array[Dictionary] = []
) -> ChatMessage:
	var msg := ChatMessage.new()
	msg.user_id = p_user_id
	msg.login = p_login
	msg.display_name = p_display_name
	msg.text = p_text
	msg.emotes = p_emotes
	return msg
