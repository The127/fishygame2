class_name TideTrigger
extends Area2D
## An invisible tripwire on Ebb Tide. The first fish to swim through it is the furthest one along,
## and that sends the tide crashing down to [member level_y] (see [method WaterLevel.drop_to]). It
## fires once per race, so the waterline can only ever fall.

## Emitted when the first live fish enters. `level_y` is the world y the tide should reach.
signal tripped(level_y: float)

## World y the waterline quickly falls to when this trigger trips.
@export var level_y: float = 0.0

var _armed: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Arms the trigger for the next race.
func rearm() -> void:
	_armed = true


func _on_body_entered(body: Node2D) -> void:
	var marble: Marble = body as Marble
	if not _armed or marble == null or marble.is_out():
		return
	_armed = false
	tripped.emit(level_y)
