class_name ChatSource
extends Node
## Base class for chat providers. Subclasses emit [signal message_received].

signal message_received(msg: ChatMessage)


## Begin producing messages. Subclasses override.
func start() -> void:
	pass


## Stop producing messages. Subclasses override.
func stop() -> void:
	pass


## Post a message to the channel. Sources that cannot write ignore it.
func send_message(_text: String) -> void:
	pass
