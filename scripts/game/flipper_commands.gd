class_name FlipperCommands
extends Node
## Chat commands that fire the flippers on a map that has them: "#left" and "#right". The same
## two steer the claw of the Claw Machine, and "#grab" drops it.
##
## Any viewer can press, joined or not. The node only forwards the press as
## [signal flippers_requested] or [signal grab_requested]; the game passes it to the map, which
## owns the cooldowns.

## A viewer pressed a side: -1 for "#left", 1 for "#right".
signal flippers_requested(side: int, who: String)
## A viewer pressed "#grab".
signal grab_requested(who: String)


## Feed it Chat.command_received.
func handle_command(msg: ChatMessage, command: String, _args: PackedStringArray) -> void:
	match command:
		"left":
			flippers_requested.emit(PinballTable.LEFT, ChatReplies.viewer_name(msg))
		"right":
			flippers_requested.emit(PinballTable.RIGHT, ChatReplies.viewer_name(msg))
		"grab":
			grab_requested.emit(ChatReplies.viewer_name(msg))
