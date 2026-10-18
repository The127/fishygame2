class_name RollCommands
extends Node
## The chat command that rolls the die of a board map: "#roll".
##
## Any viewer can press, joined or not. The node only forwards the press as
## [signal roll_requested]; the game passes it to the map, which owns the meter and the cooldown.

## A viewer pressed "#roll".
signal roll_requested(who: String)


## Feed it Chat.command_received.
func handle_command(msg: ChatMessage, command: String, _args: PackedStringArray) -> void:
	if command == "roll":
		roll_requested.emit(ChatReplies.viewer_name(msg))
