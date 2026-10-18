class_name MapChat
extends Node
## The chat commands that play a map part: the flippers and the claw ("#left", "#right", "#grab"),
## the fault ("#shake"), the die ("#roll"),
## the sushi chef ("#chop") and the gravity helm ("#up", "#down", "#left", "#right").
##
## Its children turn chat lines into requests; this node passes each one to the map part's chat
## group, but only while [member is_open] says a race takes them. Only a map that has the part
## reacts (the part is in the group).

## Whether a press counts now. The game sets it: only during a race, and not under the replay.
var is_open: Callable = func() -> bool: return false
## How many viewers race, for the fault's and the die's meters. The game sets it.
var field_size: Callable = func() -> int: return 0

var _flippers: FlipperCommands = FlipperCommands.new()
var _shake: ShakeCommands = ShakeCommands.new()
var _roll: RollCommands = RollCommands.new()
var _chop: ChopCommands = ChopCommands.new()
var _gravity: GravityCommands = GravityCommands.new()


func _ready() -> void:
	for commands: Node in [_flippers, _shake, _roll, _chop, _gravity]:
		add_child(commands)
		Chat.command_received.connect(commands.handle_command)
	_flippers.flippers_requested.connect(_on_flippers_requested)
	_flippers.grab_requested.connect(_on_grab_requested)
	_shake.shake_requested.connect(_on_shake_requested)
	_roll.roll_requested.connect(_on_roll_requested)
	_chop.chop_requested.connect(_on_chop_requested)
	_gravity.gravity_requested.connect(_on_gravity_requested)


func _on_flippers_requested(side: int, who: String) -> void:
	if is_open.call():
		get_tree().call_group(PinballTable.CHAT_GROUP, "fire", side, who)
		get_tree().call_group(ClawMachine.CHAT_GROUP, "steer", side, who)


func _on_grab_requested(who: String) -> void:
	if is_open.call():
		get_tree().call_group(ClawMachine.CHAT_GROUP, "grab", who)


func _on_shake_requested(who: String) -> void:
	if is_open.call():
		get_tree().call_group(QuakeFault.CHAT_GROUP, "shake", who, int(field_size.call()))


func _on_roll_requested(who: String) -> void:
	if is_open.call():
		get_tree().call_group(BoardDice.CHAT_GROUP, "press", who, int(field_size.call()))


func _on_chop_requested(who: String) -> void:
	if is_open.call():
		get_tree().call_group(SushiChef.CHAT_GROUP, "chop", who)


func _on_gravity_requested(side: GravityFlipper.Pull, who: String) -> void:
	if is_open.call():
		get_tree().call_group(GravityFlipper.CHAT_GROUP, "vote", side, who)
