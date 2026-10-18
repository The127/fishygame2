class_name FishFeatures
extends RefCounted
## The parts that give each [FishVisual] species its own silhouette: tails, fins, bills, spines.
## Drawn in the fish's own space (snout towards +x, up is -y). [method draw_fins] runs every
## frame behind the body; the body extras are drawn once with the body.

## One per species, in the order of [constant FishVisual.SPECIES].
enum Look { TROUT, PUFFER, PIKE, ANGEL, SWORD, HAMMER, LION, BETTA }

const OUTLINE: Color = Color(0.01, 0.02, 0.035, 0.95)
const MARK: Color = Color(0.96, 0.98, 1.0, 0.95)


## Half the body height at [param u], 0 at the snout and 1 at the tail.
static func half_height(sp: Dictionary, u: float) -> float:
	var height: float = sp["height"]
	return maxf(height * pow(sin(PI * pow(u, sp["peak"])), 0.8), height * 0.16)


## The x of the body at [param u], 0 at the snout and 1 at the tail.
static func x_at(sp: Dictionary, u: float) -> float:
	var length: float = sp["length"]
	return length - 2.0 * length * u


## Where the eyes sit; the first one is where accessories like shades go.
static func eyes(sp: Dictionary, look: int) -> Array[Vector2]:
	var length: float = sp["length"]
	var height: float = sp["height"]
	match look:
		Look.HAMMER:
			var bar: Array[Vector2] = _hammer_ends(sp)
			return [bar[0], bar[1]]
		Look.PUFFER:
			return [Vector2(length * 0.5, -height * 0.3)]
		Look.PIKE:
			return [Vector2(length * 0.62, -height * 0.35)]
		Look.SWORD:
			return [Vector2(length * 0.6, -height * 0.2)]
	return [Vector2(length * 0.5, -height * 0.25)]


## Body extras that the body covers at their base, e.g. the swordfish bill.
static func draw_behind_body(
	canvas: CanvasItem, sp: Dictionary, look: int, back: Color, belly: Color
) -> void:
	var length: float = sp["length"]
	match look:
		Look.SWORD:
			var bill := PackedVector2Array(
				[
					Vector2(length - 3.0, -2.2),
					Vector2(length + 13.0, -0.8),
					Vector2(length + 13.5, -0.3),
					Vector2(length - 3.0, 1.2),
				]
			)
			canvas.draw_colored_polygon(bill, back.lerp(belly, 0.4))
			canvas.draw_polyline(bill + PackedVector2Array([bill[0]]), OUTLINE, 1.6)
		Look.PIKE:
			var jaw := PackedVector2Array(
				[
					Vector2(length - 4.0, -3.4),
					Vector2(length + 5.0, -2.2),
					Vector2(length + 6.5, 0.0),
					Vector2(length + 5.0, 2.4),
					Vector2(length - 4.0, 3.4),
				]
			)
			canvas.draw_colored_polygon(jaw, belly)
			canvas.draw_polyline(jaw + PackedVector2Array([jaw[0]]), OUTLINE, 1.2)
			canvas.draw_line(Vector2(length + 5.0, 0.2), Vector2(length - 1.0, 0.6), OUTLINE, 1.0)


## Body extras drawn over the body: the hammerhead's hammer and gills, the puffer's belly.
static func draw_over_body(
	canvas: CanvasItem, sp: Dictionary, look: int, back: Color, belly: Color
) -> void:
	var height: float = sp["height"]
	match look:
		Look.HAMMER:
			for i: int in 3:
				var x: float = x_at(sp, 0.28 + 0.05 * float(i))
				canvas.draw_line(
					Vector2(x, -height * 0.3), Vector2(x - 1.0, height * 0.3), OUTLINE, 1.2
				)
			var bar: Array[Vector2] = _hammer_ends(sp)
			for pass_width: Array in [[7.5, OUTLINE], [5.0, back.lerp(belly, 0.3)]]:
				var width: float = pass_width[0]
				var col: Color = pass_width[1]
				canvas.draw_line(bar[0], bar[1], col, width)
				canvas.draw_circle(bar[0], width * 0.5, col)
				canvas.draw_circle(bar[1], width * 0.5, col)
		Look.PUFFER:
			var points := PackedVector2Array()
			for i: int in 9:
				var u: float = lerpf(0.2, 0.8, float(i) / 8.0)
				points.append(Vector2(x_at(sp, u), half_height(sp, u) * 0.6))
			canvas.draw_polyline(points, Color(belly.lightened(0.4), 0.6), 1.2)
		Look.TROUT:
			var length: float = sp["length"]
			canvas.draw_line(Vector2(length - 0.5, 0.8), Vector2(length - 4.0, 1.6), OUTLINE, 1.2)
			var gill := Vector2(x_at(sp, 0.3) + 4.0, 0.0)
			canvas.draw_arc(gill, height * 0.55, PI * 0.65, PI * 1.35, 8, OUTLINE, 1.2)


## Tail and fins, every frame. [param wag] swings the tail, [param swim] is 0 still to 1 fast.
static func draw_fins(
	canvas: CanvasItem,
	sp: Dictionary,
	look: int,
	fin_col: Color,
	accent: Color,
	time: float,
	wag: float,
	swim: float
) -> void:
	var flutter: float = sin(time * 6.0 + 1.3) * 1.5
	match look:
		Look.TROUT:
			_forked_tail(canvas, sp, fin_col, accent, wag, [1.0, 1.0, 0.8, 1.0, 1.0])
			_trout_fins(canvas, sp, fin_col, accent, flutter)
		Look.PUFFER:
			_fan_tail(canvas, sp, fin_col, accent, wag)
			_puffer_fins(canvas, sp, fin_col, accent, time)
		Look.PIKE:
			_forked_tail(canvas, sp, fin_col, accent, wag, [1.0, 1.1, 0.45, 1.0, 1.1])
			_pike_fins(canvas, sp, fin_col, accent, flutter)
		Look.ANGEL:
			_forked_tail(canvas, sp, fin_col, accent, wag, [1.2, 1.0, 0.75, 1.2, 1.0])
			_angel_fins(canvas, sp, fin_col, accent, flutter)
		Look.SWORD:
			_forked_tail(canvas, sp, fin_col, accent, wag, [1.15, 1.25, 0.2, 1.15, 1.25])
			_sword_fins(canvas, sp, fin_col, accent, flutter)
		Look.HAMMER:
			_forked_tail(canvas, sp, fin_col, accent, wag, [1.1, 1.3, 0.3, 0.6, 0.6])
			_hammer_fins(canvas, sp, fin_col, accent, flutter)
		Look.LION:
			_fan_tail(canvas, sp, fin_col, accent, wag)
			_lion_fins(canvas, sp, fin_col, time)
		Look.BETTA:
			_veil_tail(canvas, sp, fin_col, accent, time, wag, swim)
			_betta_fins(canvas, sp, fin_col, accent, time, swim)


## The top and bottom tips of the hammer, where the eyes sit.
static func _hammer_ends(sp: Dictionary) -> Array[Vector2]:
	var length: float = sp["length"]
	var height: float = sp["height"]
	return [Vector2(length - 1.5, -height - 2.0), Vector2(length - 0.5, height * 0.75)]


## A filled fin with a dark rim and a bright leading edge from its first to its second point.
static func _fin(
	canvas: CanvasItem, points: PackedVector2Array, fin_col: Color, accent: Color
) -> void:
	canvas.draw_colored_polygon(points, fin_col)
	canvas.draw_polyline(points, OUTLINE, 1.5)
	canvas.draw_line(points[0], points[1], Color(accent.r, accent.g, accent.b, 0.8), 1.2)


## Two-lobed tail. [param shape] is upper tip length, upper spread, notch depth, lower tip
## length and lower spread, all relative to the species' tail and spread.
static func _forked_tail(
	canvas: CanvasItem, sp: Dictionary, fin_col: Color, accent: Color, wag: float, shape: Array
) -> void:
	var length: float = sp["length"]
	var tail: float = sp["tail"]
	var spread: float = sp["spread"]
	var base := Vector2(-length * 0.85, 0.0)
	var points := PackedVector2Array(
		[
			base + Vector2(0.0, -1.5),
			Vector2(-length - tail * shape[0], -spread * shape[1] + wag),
			Vector2(-length - tail * shape[2], wag * 0.5),
			Vector2(-length - tail * shape[3], spread * shape[4] + wag),
			base + Vector2(0.0, 1.5),
		]
	)
	canvas.draw_colored_polygon(points, fin_col)
	canvas.draw_polyline(points.slice(1, 4), Color(accent.r, accent.g, accent.b, 0.8), 1.2)
	canvas.draw_polyline(points, OUTLINE, 1.5)


## Rounded fan tail with rays.
static func _fan_tail(
	canvas: CanvasItem, sp: Dictionary, fin_col: Color, accent: Color, wag: float
) -> void:
	var length: float = sp["length"]
	var tail: float = sp["tail"]
	var spread: float = sp["spread"]
	var base := Vector2(-length * 0.85, 0.0)
	var edge := PackedVector2Array()
	for i: int in 9:
		var a: float = lerpf(-1.0, 1.0, float(i) / 8.0)
		edge.append(Vector2(-length - tail * cos(a * 0.8), spread * sin(a) / sin(1.0) + wag * 0.7))
	_fan(canvas, base, edge, fin_col, accent)


## The betta's long veil: a wide, drooping fan whose edge ripples more the faster it swims.
static func _veil_tail(
	canvas: CanvasItem,
	sp: Dictionary,
	fin_col: Color,
	accent: Color,
	time: float,
	wag: float,
	swim: float
) -> void:
	var length: float = sp["length"]
	var tail: float = sp["tail"]
	var spread: float = sp["spread"]
	var base := Vector2(-length * 0.8, 0.0)
	var edge := PackedVector2Array()
	for i: int in 13:
		var t: float = float(i) / 12.0
		var a: float = lerpf(-1.1, 1.2, t)
		var ripple: float = sin(time * 4.0 - t * 6.0) * (1.5 + 2.0 * swim)
		edge.append(
			Vector2(
				-length - tail * (0.8 + 0.2 * cos(a)) + ripple,
				spread * sin(a) / sin(1.1) + 2.5 * t + wag * (0.4 + 0.6 * t)
			)
		)
	_fan(canvas, base, edge, Color(fin_col, 0.85), accent)


## Fills a fan from [param base] out to [param edge], with rays and a bright rim.
static func _fan(
	canvas: CanvasItem, base: Vector2, edge: PackedVector2Array, fin_col: Color, accent: Color
) -> void:
	var points := PackedVector2Array([base + Vector2(0.0, -1.5)])
	points.append_array(edge)
	points.append(base + Vector2(0.0, 1.5))
	canvas.draw_colored_polygon(points, fin_col)
	var ray := Color(accent.r, accent.g, accent.b, 0.4)
	for i: int in range(1, edge.size() - 1, 2):
		canvas.draw_line(base, base.lerp(edge[i], 0.9), ray, 0.8)
	canvas.draw_polyline(edge, Color(accent.r, accent.g, accent.b, 0.8), 1.2)
	canvas.draw_polyline(points, OUTLINE, 1.5)


## Trout: classic dorsal, a little adipose fin near the tail, belly fin.
static func _trout_fins(
	canvas: CanvasItem, sp: Dictionary, fin_col: Color, accent: Color, flutter: float
) -> void:
	var length: float = sp["length"]
	var height: float = sp["height"]
	var dorsal: float = sp["dorsal"]
	var belly: float = sp["belly"]
	_fin(
		canvas,
		PackedVector2Array(
			[
				Vector2(length * 0.2, -height * 0.8),
				Vector2(-length * 0.15 + flutter, -height - dorsal),
				Vector2(-length * 0.5, -height * 0.7),
			]
		),
		fin_col,
		accent
	)
	var adipose_x: float = x_at(sp, 0.8)
	var adipose_top: float = -half_height(sp, 0.8)
	_fin(
		canvas,
		PackedVector2Array(
			[
				Vector2(adipose_x + 2.5, adipose_top + 1.0),
				Vector2(adipose_x - 1.5 + flutter * 0.3, adipose_top - 4.5),
				Vector2(adipose_x - 3.5, adipose_top + 1.0),
			]
		),
		fin_col,
		accent
	)
	_fin(
		canvas,
		PackedVector2Array(
			[
				Vector2(length * 0.05, height * 0.8),
				Vector2(-length * 0.25 - flutter, height + belly),
				Vector2(-length * 0.5, height * 0.65),
			]
		),
		fin_col,
		accent
	)


## Puffer: spikes all round that slowly puff out and in, tiny fins set far back.
static func _puffer_fins(
	canvas: CanvasItem, sp: Dictionary, fin_col: Color, accent: Color, time: float
) -> void:
	var puff: float = 5.5 + 2.0 * sin(time * 1.6)
	for side: float in [-1.0, 1.0]:
		for i: int in 7:
			var u: float = lerpf(0.12, 0.78, float(i) / 6.0)
			# The belly is drawn at 0.9 of the back's height.
			var edge: float = half_height(sp, u) * (0.95 if side < 0.0 else 0.85)
			var root := Vector2(x_at(sp, u), side * (edge - 1.5))
			var tip: Vector2 = root + Vector2(-1.5, side * puff)
			canvas.draw_line(root, tip, OUTLINE, 2.8)
			canvas.draw_line(root, tip, MARK.lerp(fin_col, 0.3), 1.4)
	var flap: float = sin(time * 14.0) * 2.0
	for side: float in [-1.0, 1.0]:
		var u: float = 0.72
		var root := Vector2(x_at(sp, u), side * half_height(sp, u) * 0.8)
		_fin(
			canvas,
			PackedVector2Array(
				[
					root + Vector2(2.0, 0.0),
					root + Vector2(-1.5 + flap * 0.4, side * 5.0),
					root + Vector2(-4.0, side * 0.5),
				]
			),
			fin_col,
			accent
		)
	var chest := Vector2(x_at(sp, 0.3), 1.0)
	_fin(
		canvas,
		PackedVector2Array(
			[chest, chest + Vector2(-4.5, -2.5 + flap), chest + Vector2(-4.0, 2.5 + flap)]
		),
		fin_col,
		accent
	)


## Pike: dorsal and anal fins set far back beside the tail, the way it lunges.
static func _pike_fins(
	canvas: CanvasItem, sp: Dictionary, fin_col: Color, accent: Color, flutter: float
) -> void:
	var dorsal: float = sp["dorsal"]
	var belly: float = sp["belly"]
	for side: float in [-1.0, 1.0]:
		var reach: float = dorsal if side < 0.0 else belly + 2.0
		var front: float = 0.62 if side < 0.0 else 0.66
		var a := Vector2(x_at(sp, front), side * half_height(sp, front) * 0.85)
		var b := Vector2(x_at(sp, 0.86), side * half_height(sp, 0.86) * 0.8)
		_fin(
			canvas,
			PackedVector2Array(
				[
					a,
					a + Vector2(-3.0 + flutter * 0.5, side * reach),
					b + Vector2(-1.0, side * 1.0),
					b
				]
			),
			fin_col,
			accent
		)
	var pelvic := Vector2(x_at(sp, 0.4), half_height(sp, 0.4) * 0.8)
	_fin(
		canvas,
		PackedVector2Array(
			[pelvic, pelvic + Vector2(-5.0 - flutter, 3.5), pelvic + Vector2(-5.0, 0.5)]
		),
		fin_col,
		accent
	)


## Angelfish: tall swept-back sails top and bottom, and two long trailing threads.
static func _angel_fins(
	canvas: CanvasItem, sp: Dictionary, fin_col: Color, accent: Color, flutter: float
) -> void:
	var length: float = sp["length"]
	var height: float = sp["height"]
	var dorsal: float = sp["dorsal"]
	var belly: float = sp["belly"]
	_fin(
		canvas,
		PackedVector2Array(
			[
				Vector2(length * 0.2, -height * 0.85),
				Vector2(-length * 0.55 + flutter, -height - dorsal),
				Vector2(-length * 0.95 + flutter, -height - dorsal * 0.6),
				Vector2(-length * 0.65, -height * 0.4),
			]
		),
		fin_col,
		accent
	)
	_fin(
		canvas,
		PackedVector2Array(
			[
				Vector2(length * 0.05, height * 0.85),
				Vector2(-length * 0.55 - flutter, height + belly),
				Vector2(-length * 0.95 - flutter, height + belly * 0.6),
				Vector2(-length * 0.65, height * 0.4),
			]
		),
		fin_col,
		accent
	)
	var root := Vector2(length * 0.25, height * 0.7)
	for i: int in 2:
		var tip: Vector2 = Vector2(-length * 0.2 - flutter * (1.0 + i), height + belly + 6.0 + i)
		canvas.draw_line(root, tip, OUTLINE, 2.2)
		canvas.draw_line(root, tip, Color(accent.r, accent.g, accent.b, 0.85), 1.0)


## Swordfish: a tall sail of a dorsal fin with rays, and a small anal fin.
static func _sword_fins(
	canvas: CanvasItem, sp: Dictionary, fin_col: Color, accent: Color, flutter: float
) -> void:
	var length: float = sp["length"]
	var height: float = sp["height"]
	var dorsal: float = sp["dorsal"]
	var belly: float = sp["belly"]
	var sail := PackedVector2Array(
		[
			Vector2(length * 0.45, -height * 0.75),
			Vector2(length * 0.3 + flutter * 0.3, -height - dorsal),
			Vector2(length * 0.0 + flutter * 0.6, -height - dorsal * 0.85),
			Vector2(-length * 0.3 + flutter * 0.6, -height - dorsal * 0.4),
			Vector2(-length * 0.5, -height * 0.55),
		]
	)
	_fin(canvas, sail, fin_col, accent)
	var ray := Color(accent.r, accent.g, accent.b, 0.45)
	for i: int in range(1, 4):
		var root: Vector2 = sail[0].lerp(sail[4], float(i) / 4.0)
		canvas.draw_line(root, root.lerp(sail[i], 0.9), ray, 0.8)
	var anal := Vector2(x_at(sp, 0.65), half_height(sp, 0.65) * 0.8)
	_fin(
		canvas,
		PackedVector2Array(
			[anal, anal + Vector2(-3.0 - flutter, belly + 3.0), anal + Vector2(-5.0, 0.0)]
		),
		fin_col,
		accent
	)


## Hammerhead: a sharp shark dorsal, a small second one and a long pectoral fin.
static func _hammer_fins(
	canvas: CanvasItem, sp: Dictionary, fin_col: Color, accent: Color, flutter: float
) -> void:
	var length: float = sp["length"]
	var height: float = sp["height"]
	var dorsal: float = sp["dorsal"]
	var belly: float = sp["belly"]
	_fin(
		canvas,
		PackedVector2Array(
			[
				Vector2(length * 0.2, -height * 0.85),
				Vector2(-length * 0.15 + flutter * 0.3, -height - dorsal),
				Vector2(-length * 0.12, -height - dorsal * 0.45),
				Vector2(-length * 0.25, -height * 0.75),
			]
		),
		fin_col,
		accent
	)
	var second := Vector2(x_at(sp, 0.78), -half_height(sp, 0.78) * 0.85)
	_fin(
		canvas,
		PackedVector2Array([second, second + Vector2(-2.5, -3.5), second + Vector2(-4.0, 0.0)]),
		fin_col,
		accent
	)
	var chest := Vector2(length * 0.3, height * 0.6)
	_fin(
		canvas,
		PackedVector2Array(
			[
				chest,
				Vector2(-length * 0.05 - flutter, height + belly + 3.0),
				Vector2(length * 0.05, height * 0.8),
			]
		),
		fin_col,
		accent
	)


## Lionfish: a fan of banded venom spines along the back and big feathery chest fins, all
## rippling in a wave from head to tail.
static func _lion_fins(canvas: CanvasItem, sp: Dictionary, fin_col: Color, time: float) -> void:
	var length: float = sp["length"]
	var height: float = sp["height"]
	var dorsal: float = sp["dorsal"]
	var belly: float = sp["belly"]
	var membrane := PackedVector2Array()
	var spines: Array[PackedVector2Array] = []
	for i: int in 9:
		var t: float = float(i) / 8.0
		var u: float = lerpf(0.18, 0.75, t)
		var root := Vector2(x_at(sp, u), -half_height(sp, u) * 0.85)
		var reach: float = dorsal * (1.0 - 0.45 * t) + sin(time * 4.0 - t * 5.0) * 1.5
		var tip: Vector2 = root + Vector2(-reach * 0.35 - 2.0 * t, -reach)
		spines.append(PackedVector2Array([root, tip]))
		membrane.append(root.lerp(tip, 0.45))
	var roots := PackedVector2Array()
	for spine: PackedVector2Array in spines:
		roots.append(spine[0])
	roots.reverse()
	membrane.append_array(roots)
	canvas.draw_colored_polygon(membrane, Color(fin_col, 0.6))
	for spine: PackedVector2Array in spines:
		_banded_line(canvas, spine[0], spine[1], fin_col)
	var chest := Vector2(length * 0.15, height * 0.4)
	var fan := PackedVector2Array()
	for i: int in 6:
		var t: float = float(i) / 5.0
		var sway: float = sin(time * 3.0 - t * 3.0) * 1.5
		fan.append(chest + Vector2(-4.0 - 9.0 * t + sway, belly * (0.6 + 0.6 * sin(PI * t))))
	var chest_points := PackedVector2Array([chest])
	chest_points.append_array(fan)
	chest_points.append(chest + Vector2(-9.0, 0.0))
	canvas.draw_colored_polygon(chest_points, Color(fin_col, 0.7))
	for tip: Vector2 in fan:
		_banded_line(canvas, chest, chest.lerp(tip, 1.15), fin_col)


## A spine with alternating light and dark bands.
static func _banded_line(canvas: CanvasItem, from: Vector2, to: Vector2, fin_col: Color) -> void:
	canvas.draw_line(from, to, OUTLINE, 2.2)
	for k: int in 4:
		var col: Color = MARK if k % 2 == 0 else fin_col
		canvas.draw_line(from.lerp(to, k / 4.0), from.lerp(to, (k + 1) / 4.0), col, 1.0)


## Betta: long flowing dorsal and anal fins that trail past the tail and billow.
static func _betta_fins(
	canvas: CanvasItem, sp: Dictionary, fin_col: Color, accent: Color, time: float, swim: float
) -> void:
	var length: float = sp["length"]
	var height: float = sp["height"]
	var dorsal: float = sp["dorsal"]
	var belly: float = sp["belly"]
	for side: float in [-1.0, 1.0]:
		var reach: float = dorsal if side < 0.0 else belly
		var front := Vector2(length * (0.1 if side < 0.0 else 0.0), side * height * 0.85)
		var back := Vector2(-length * 0.8, side * height * 0.3)
		var points := PackedVector2Array([front])
		for i: int in 9:
			var t: float = float(i) / 8.0
			var lift: float = reach * pow(sin(PI * (0.08 + 0.84 * t)), 0.7)
			var ripple: float = sin(time * 4.0 - t * 5.0 + side) * (1.0 + 1.5 * swim)
			var x: float = lerpf(length * 0.05, -length - 4.0, t)
			var y: float = lerpf(height * 0.85, height * 0.45, t) + lift + ripple * sin(PI * t)
			points.append(Vector2(x, side * y))
		points.append(back)
		canvas.draw_colored_polygon(points, Color(fin_col, 0.85))
		var ray := Color(accent.r, accent.g, accent.b, 0.4)
		for i: int in range(2, 9, 2):
			canvas.draw_line(front.lerp(back, float(i) / 9.0), points[i], ray, 0.8)
		canvas.draw_polyline(points.slice(1, points.size() - 1), Color(accent, 0.8), 1.2)
		canvas.draw_polyline(points, OUTLINE, 1.5)
	var chest := Vector2(length * 0.3, height * 0.5)
	var flap: float = sin(time * 7.0) * 1.5
	canvas.draw_colored_polygon(
		PackedVector2Array([chest, chest + Vector2(-5.0, 4.0 + flap), chest + Vector2(-6.0, 1.0)]),
		Color(fin_col, 0.85)
	)
