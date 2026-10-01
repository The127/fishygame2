class_name ShakeCommands
extends Node
## The chat command that quakes a map with a fault: "#shake".
##
## Any viewer can press, joined or not. The node only forwards the press as
## [signal shake_requested]; the game passes it to the map, which owns the meter and the cooldown.

## A viewer pressed "#shake".
signal shake_requested(who: String)


## Feed it Chat.command_received.
func handle_command(msg: ChatMessage, command: String, _args: PackedStringArray) -> void:
	if command == "shake":
		shake_requested.emit(ChatReplies.viewer_name(msg))
