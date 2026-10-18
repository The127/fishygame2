class_name LurkerSpots
extends RefCounted
## Where lurkers hide on a map ([LurkerDen]) and what they hide in: open water near the course
## but off the fish's way, clear of walls, and a hideout that fits the map.

## What a lurker hides in.
enum Hideout { KELP, PORTHOLE, PIPE, CURTAIN, GLASS, ROCK, DARK }

## Maps that hide their lurkers in something other than kelp.
const HIDEOUTS: Dictionary[String, Hideout] = {
	"wreck": Hideout.PORTHOLE,
	"city": Hideout.PORTHOLE,
	"flush": Hideout.PIPE,
	"washer": Hideout.PIPE,
	"whale": Hideout.DARK,
	"abyss": Hideout.DARK,
	"kraken": Hideout.DARK,
	"cave": Hideout.ROCK,
	"vents": Hideout.ROCK,
	"fault": Hideout.ROCK,
	"sushi": Hideout.CURTAIN,
	"claw": Hideout.GLASS,
	"pinball": Hideout.GLASS,
	"pinball2": Hideout.GLASS,
	"board": Hideout.GLASS,
}

const MAX_SPOTS: int = 16
## Grid step of the candidate spots, in pixels.
const STEP: float = 56.0
## A spot sits this far from the nearest route line: close enough to watch, out of the way.
const NEAR: float = 80.0
const FAR: float = 240.0
## Nothing solid within this radius of a spot.
const CLEARANCE: float = 56.0
## Spots are at least this far apart.
const SPACING: float = 150.0
## Kept clear of the view's edges.
const MARGIN: float = 48.0


static func hideout_of(map_id: String) -> Hideout:
	return HIDEOUTS.get(map_id, Hideout.KELP)


## Up to [constant MAX_SPOTS] global spots on [param track], spread out and in a fixed order
## for the map, so the same lurkers sit in the same spots from race to race. Needs the track's colliders in
## the physics space (call from a physics frame).
static func find(track: Track, map_id: String) -> Array[Vector2]:
	var space: PhysicsDirectSpaceState2D = track.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = CLEARANCE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collide_with_areas = false
	var covers: Array[Polygon2D] = _covers(track)
	var area: Rect2 = track.view_bounds.grow(-MARGIN)
	var candidates: Array[Vector2] = []
	var y: float = area.position.y
	while y <= area.end.y:
		var x: float = area.position.x
		while x <= area.end.x:
			var at := Vector2(x, y)
			var distance: float = track.distance_to_route(at)
			if distance >= NEAR and distance <= FAR:
				query.transform = Transform2D(0.0, at)
				if space.intersect_shape(query, 1).is_empty() and not _covered(covers, at):
					candidates.append(at)
			x += STEP
		y += STEP
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(map_id)
	for i: int in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Vector2 = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var spots: Array[Vector2] = []
	for at: Vector2 in candidates:
		if spots.size() >= MAX_SPOTS:
			break
		if spots.all(func(s: Vector2) -> bool: return s.distance_to(at) >= SPACING):
			spots.append(at)
	return spots


## The shapes drawn over the den (walls without a collider of the same shape, like a ring's
## rock): every visible [Polygon2D] of the track at or above z 0.
static func _covers(track: Track) -> Array[Polygon2D]:
	var result: Array[Polygon2D] = []
	for node: Node in track.find_children("*", "Polygon2D", true, false):
		var polygon: Polygon2D = node as Polygon2D
		if polygon.polygon.size() >= 3 and polygon.is_visible_in_tree() and _z_of(polygon) >= 0:
			result.append(polygon)
	return result


static func _z_of(item: CanvasItem) -> int:
	var z: int = 0
	var node: Node = item
	while node is CanvasItem:
		z += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative:
			break
		node = node.get_parent()
	return z


## Whether any of [param covers] hides a lurker at [param at] (its middle or its edges).
static func _covered(covers: Array[Polygon2D], at: Vector2) -> bool:
	for polygon: Polygon2D in covers:
		for offset: Vector2 in [Vector2.ZERO, Vector2(CLEARANCE, 0.0), Vector2(-CLEARANCE, 0.0)]:
			var inside: bool = Geometry2D.is_point_in_polygon(
				polygon.to_local(at + offset), polygon.polygon
			)
			if inside != polygon.invert_enabled:
				return true
	return false
