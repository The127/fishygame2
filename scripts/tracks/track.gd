class_name Track
extends Node2D
## A marble run: static colliders, a start area, a finish Area2D and a centerline
## Path2D used to measure race progress.

signal marble_reached_finish(marble: Node2D)

@export var spawn_columns: int = 5
@export var spawn_spacing: float = 34.0

@onready var _finish: Area2D = $Finish
@onready var _centerline: Path2D = $Centerline
@onready var _spawn_origin: Marker2D = $SpawnOrigin


func _ready() -> void:
	_finish.body_entered.connect(_on_finish_body_entered)


## Global position of the nth start slot (grid of spawn_columns per row, rows stack upward).
func get_spawn_position(index: int) -> Vector2:
	var col: int = index % spawn_columns
	var row: int = index / spawn_columns
	return _spawn_origin.to_global(Vector2(col * spawn_spacing, -row * spawn_spacing))


## Progress along the centerline in [0, 1] for a global position.
func get_progress(global_pos: Vector2) -> float:
	var curve: Curve2D = _centerline.curve
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return 0.0
	return curve.get_closest_offset(_centerline.to_local(global_pos)) / length


func _on_finish_body_entered(body: Node2D) -> void:
	marble_reached_finish.emit(body)
