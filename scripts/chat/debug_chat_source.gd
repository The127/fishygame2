class_name DebugChatSource
extends ChatSource
## Fake chat source for development and tests. Use [method inject] from code.

## Messages passed to [method send_message], for tests and the console.
var sent: Array[String] = []


func inject(user_id: String, display_name: String, text: String) -> void:
	var msg := ChatMessage.create(user_id, display_name.to_lower(), display_name, text)
	message_received.emit(msg)


func send_message(text: String) -> void:
	sent.append(text)
	print("[chat out] %s" % text)
