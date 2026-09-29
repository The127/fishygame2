class_name CameraFraming
extends RefCounted
## Pure camera maths: who the camera follows, how far it zooms and where it may sit.

## Progress (0..1 along the track) behind the leader that still counts as the leading group.
const GROUP_SPAN: float = 0.12


## Positions of the marbles that make up the leading group: everyone within
## `span` progress of the leader. `positions` and `progress` map id -> value.
static func leader_group(
	positions: Dictionary, progress: Dictionary, span: float = GROUP_SPAN
) -> Array[Vector2]:
	var best: float = -INF
	for id: int in positions:
		best = maxf(best, float(progress.get(id, 0.0)))
	var group: Array[Vector2] = []
	for id: int in positions:
		if float(progress.get(id, 0.0)) >= best - span:
			group.append(positions[id])
	return group


## Bounding box of the points, grown by `margin` on every side and to at least `min_size`.
static func focus_rect(points: Array[Vector2], margin: float, min_size: Vector2) -> Rect2:
	if points.is_empty():
		return Rect2()
	var rect: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	rect = rect.grow(margin)
	var extra: Vector2 = (min_size - rect.size).max(Vector2.ZERO)
	return rect.grow_individual(extra.x / 2.0, extra.y / 2.0, extra.x / 2.0, extra.y / 2.0)


## Zoom that fits `size` in the viewport, clamped to [min_zoom, max_zoom].
static func fit_zoom(size: Vector2, viewport: Vector2, min_zoom: float, max_zoom: float) -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return max_zoom
	return clampf(minf(viewport.x / size.x, viewport.y / size.y), min_zoom, max_zoom)


## Camera center kept so the visible area stays inside `bounds`. If the view is
## larger than the bounds on an axis, that axis is centered on the bounds.
static func clamp_center(center: Vector2, zoom: float, viewport: Vector2, bounds: Rect2) -> Vector2:
	var half: Vector2 = viewport / zoom / 2.0
	var result: Vector2 = center
	for axis: int in 2:
		if half[axis] * 2.0 >= bounds.size[axis]:
			result[axis] = bounds.position[axis] + bounds.size[axis] / 2.0
		else:
			result[axis] = clampf(
				center[axis], bounds.position[axis] + half[axis], bounds.end[axis] - half[axis]
			)
	return result


## Frame-rate independent smoothing factor for lerp: 0 at once, approaching 1 as delta grows.
static func damping(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)


## Easing-rate multiplier after a finish: `min_scale` right away, ramping smoothly to 1
## as `time_left` runs from `total` down to 0.
static func handover_scale(time_left: float, total: float, min_scale: float) -> float:
	if total <= 0.0 or time_left <= 0.0:
		return 1.0
	var t: float = 1.0 - clampf(time_left / total, 0.0, 1.0)
	return lerpf(min_scale, 1.0, t * t * (3.0 - 2.0 * t))
