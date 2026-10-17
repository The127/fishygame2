class_name DoorBeacon
extends Node2D
## A row of chevrons that pulse toward the finish in the gap of a partition, so viewers can see
## which lane the fish have to reach. Purely decoration: it has no physics and nothing to replay.

const COLOR: Color = Color(1.0, 0.86, 0.5)
const CHEVRONS: int = 3
## Pixels between chevrons, and how big each one is.
const SPACING: float = 26.0
const SIZE: float = 16.0
## Seconds a pulse takes to run through the chevrons.
const PERIOD: float = 1.4

## Height of the gap, in pixels, centered on this node.
@export var gap_height: float = 180.0

var _time: float = 0.0


func _ready() -> void:
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var half: float = gap_height * 0.5
	draw_rect(Rect2(-SPACING * 1.5, -half, SPACING * 3.0, gap_height), Color(COLOR, 0.05))
	for i: int in CHEVRONS:
		var phase: float = fposmod(_time / PERIOD - float(i) / float(CHEVRONS), 1.0)
		var alpha: float = 0.15 + 0.6 * (1.0 - phase)
		var x: float = (float(i) - float(CHEVRONS - 1) * 0.5) * SPACING
		var tip: Vector2 = Vector2(x + SIZE * 0.5, 0.0)
		var points: PackedVector2Array = PackedVector2Array(
			[Vector2(x - SIZE * 0.5, -SIZE), tip, Vector2(x - SIZE * 0.5, SIZE)]
		)
		draw_polyline(points, Color(COLOR, alpha), 4.0, true)
