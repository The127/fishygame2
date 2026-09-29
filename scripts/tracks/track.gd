class_name Track
extends Node2D
## A marble run: static colliders, a start area, a finish Area2D and a centerline
## Path2D used to measure race progress.

signal marble_reached_finish(marble: Node2D)

## Distance in pixels either side of a point used to estimate the track direction.
const FORWARD_SAMPLE: float = 30.0

@export var spawn_columns: int = 5
@export var spawn_spacing: float = 34.0
## World area the race camera may look at. Grow it if a map extends beyond the default frame.
@export var view_bounds: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)
## Look of the map, a key of TrackStyle.PALETTES.
@export var style_id: String = TrackStyle.DEFAULT_STYLE

@onready var _finish: Area2D = $Finish
@onready var _centerline: Path2D = $Centerline
@onready var _spawn_origin: Marker2D = $SpawnOrigin


func _ready() -> void:
	_finish.body_entered.connect(_on_finish_body_entered)
	var style: TrackStyle = TrackStyle.new()
	add_child(style)
	style.dress(self, style_id)


## Global position of the nth start slot (grid of spawn_columns per row, rows stack upward).
func get_spawn_position(index: int) -> Vector2:
	var col: int = index % spawn_columns
	var row: int = index / spawn_columns
	return _spawn_origin.to_global(Vector2(col * spawn_spacing, -row * spawn_spacing))


## Global position of the finish gate.
func get_finish_position() -> Vector2:
	return _finish.global_position


## Progress along the centerline in [0, 1] for a global position.
func get_progress(global_pos: Vector2) -> float:
	var curve: Curve2D = _centerline.curve
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return 0.0
	return curve.get_closest_offset(_centerline.to_local(global_pos)) / length


## Unit vector along the centerline (toward the finish) nearest to a global position.
func get_forward(global_pos: Vector2) -> Vector2:
	var curve: Curve2D = _centerline.curve
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return Vector2.DOWN
	var offset: float = curve.get_closest_offset(_centerline.to_local(global_pos))
	var ahead: Vector2 = curve.sample_baked(minf(offset + FORWARD_SAMPLE, length))
	var behind: Vector2 = curve.sample_baked(maxf(offset - FORWARD_SAMPLE, 0.0))
	var direction: Vector2 = _centerline.to_global(ahead) - _centerline.to_global(behind)
	if direction.length_squared() < 0.0001:
		return Vector2.DOWN
	return direction.normalized()


func _on_finish_body_entered(body: Node2D) -> void:
	marble_reached_finish.emit(body)
