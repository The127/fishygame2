class_name Spinner
extends AnimatableBody2D
## A moving obstacle that turns at a constant speed. Kinematic, so marbles are pushed
## along by it and the motion is identical for a given physics step.

## Turn rate in radians per second (negative turns the other way).
@export var speed: float = 1.0


func _physics_process(delta: float) -> void:
	rotation += speed * delta
