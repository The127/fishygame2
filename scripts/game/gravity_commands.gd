class_name GravityCommands
extends Node
## Chat commands that steer the gravity of a map that has a [GravityFlipper]: "#up", "#down",
## "#left" and "#right", each the side of the room the viewer wants as the floor.
##
## Any viewer can vote, joined or not. The node only forwards the vote as
## [signal gravity_requested]; the game passes it to the map, which owns the tally and the pace.

## A viewer voted for a side to become the floor.
signal gravity_requested(side: GravityFlipper.Pull, who: String)


## Feed it Chat.command_received.
func handle_command(msg: ChatMessage, command: String, _args: PackedStringArray) -> void:
	var side: int = GravityFlipper.COMMANDS.find(command)
	if side >= 0:
		gravity_requested.emit(side as GravityFlipper.Pull, ChatReplies.viewer_name(msg))
