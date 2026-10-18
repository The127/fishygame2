class_name ChopCommands
extends Node
## The chat command that swings the sushi chef's knife: "#chop".
##
## Any viewer can press, joined or not. The node only forwards the press as
## [signal chop_requested]; the game passes it to the map, which owns the cooldown and the limits.

## A viewer pressed "#chop".
signal chop_requested(who: String)


## Feed it Chat.command_received.
func handle_command(msg: ChatMessage, command: String, _args: PackedStringArray) -> void:
	if command == "chop":
		chop_requested.emit(ChatReplies.viewer_name(msg))
