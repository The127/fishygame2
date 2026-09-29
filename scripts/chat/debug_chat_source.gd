class_name DebugChatSource
extends ChatSource
## Fake chat source for development and tests. Use [method inject] from code.


func inject(user_id: String, display_name: String, text: String) -> void:
	var msg := ChatMessage.create(user_id, display_name.to_lower(), display_name, text)
	message_received.emit(msg)
