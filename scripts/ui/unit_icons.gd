extends RefCounted
## Flat side-view silhouettes for unit portraits, build cards and ability
## buttons, drawn as vector polygons so they stay sharp at any UI scale and
## need no image files. Shapes are authored in a 100 x 60 box and fitted to
## the target rectangle.


static func _fit(rect: Rect2, pts: Array) -> PackedVector2Array:
	var s := minf(rect.size.x / 100.0, rect.size.y / 60.0)
	var off := rect.position + (rect.size - Vector2(100, 60) * s) * 0.5
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(off + p * s)
	return out


static func _poly(ci: CanvasItem, rect: Rect2, pts: Array, color: Color) -> void:
	ci.draw_colored_polygon(_fit(rect, pts), color)


static func _circle(ci: CanvasItem, rect: Rect2, c: Vector2, r: float, color: Color) -> void:
	var s := minf(rect.size.x / 100.0, rect.size.y / 60.0)
	var off := rect.position + (rect.size - Vector2(100, 60) * s) * 0.5
	ci.draw_circle(off + c * s, r * s, color)


static func _line(ci: CanvasItem, rect: Rect2, a: Vector2, b: Vector2, color: Color, w: float) -> void:
	var p := _fit(rect, [a, b])
	var s := minf(rect.size.x / 100.0, rect.size.y / 60.0)
	ci.draw_line(p[0], p[1], color, maxf(w * s, 1.0), true)


## kind: a UnitDefs model or unit id, or "strike" / "airstrike".
static func draw(ci: CanvasItem, kind: String, rect: Rect2, color: Color) -> void:
	match kind:
		"tank", "abrams", "karrar":
			_poly(ci, rect, [Vector2(6, 44), Vector2(12, 34), Vector2(88, 34), Vector2(95, 44), Vector2(88, 52), Vector2(12, 52)], color)
			_poly(ci, rect, [Vector2(30, 34), Vector2(36, 22), Vector2(66, 22), Vector2(72, 34)], color)
			_line(ci, rect, Vector2(66, 27), Vector2(98, 25), color, 3.5)
			for i in 6:
				_circle(ci, rect, Vector2(18 + i * 13, 46), 4.0, Color(0, 0, 0, 0.45))
		"soldier", "ranger", "irgc":
			_circle(ci, rect, Vector2(50, 12), 6.0, color)
			_poly(ci, rect, [Vector2(43, 20), Vector2(57, 20), Vector2(59, 38), Vector2(41, 38)], color)
			_poly(ci, rect, [Vector2(42, 38), Vector2(49, 38), Vector2(46, 58), Vector2(39, 58)], color)
			_poly(ci, rect, [Vector2(51, 38), Vector2(58, 38), Vector2(62, 58), Vector2(55, 58)], color)
			_line(ci, rect, Vector2(44, 28), Vector2(76, 24), color, 3.0)
		"javelin", "irgc_rpg":
			_circle(ci, rect, Vector2(46, 14), 6.0, color)
			_poly(ci, rect, [Vector2(39, 22), Vector2(53, 22), Vector2(55, 40), Vector2(37, 40)], color)
			_poly(ci, rect, [Vector2(38, 40), Vector2(45, 40), Vector2(42, 58), Vector2(35, 58)], color)
			_poly(ci, rect, [Vector2(47, 40), Vector2(54, 40), Vector2(58, 58), Vector2(51, 58)], color)
			_line(ci, rect, Vector2(26, 20), Vector2(82, 14), color, 6.0)
		"robodog", "k9":
			_poly(ci, rect, [Vector2(22, 22), Vector2(74, 22), Vector2(78, 34), Vector2(20, 34)], color)
			_poly(ci, rect, [Vector2(74, 16), Vector2(90, 16), Vector2(92, 26), Vector2(76, 28)], color)
			for x: float in [26.0, 36.0, 62.0, 72.0]:
				_line(ci, rect, Vector2(x, 33), Vector2(x - 4, 45), color, 3.0)
				_line(ci, rect, Vector2(x - 4, 45), Vector2(x + 1, 56), color, 3.0)
		"laser_truck", "laser_ad", "launcher_truck", "shahed_launcher":
			_poly(ci, rect, [Vector2(6, 46), Vector2(6, 32), Vector2(24, 32), Vector2(30, 20), Vector2(44, 20), Vector2(46, 32), Vector2(94, 32), Vector2(94, 46)], color)
			for x: float in [20.0, 72.0, 84.0]:
				_circle(ci, rect, Vector2(x, 48), 6.0, color)
				_circle(ci, rect, Vector2(x, 48), 2.5, Color(0, 0, 0, 0.5))
			if kind.begins_with("laser"):
				_poly(ci, rect, [Vector2(58, 32), Vector2(62, 18), Vector2(78, 18), Vector2(80, 32)], color)
				_line(ci, rect, Vector2(70, 18), Vector2(86, 4), color, 3.0)
			else:
				_poly(ci, rect, [Vector2(52, 32), Vector2(88, 14), Vector2(92, 22), Vector2(58, 32)], color)
		"drone", "shahed":
			_poly(ci, rect, [Vector2(10, 30), Vector2(80, 26), Vector2(92, 30), Vector2(80, 34)], color)
			_poly(ci, rect, [Vector2(40, 30), Vector2(64, 8), Vector2(72, 8), Vector2(60, 30)], color)
			_poly(ci, rect, [Vector2(40, 30), Vector2(64, 52), Vector2(72, 52), Vector2(60, 30)], color)
		"patrol_boat", "fast_boat":
			_poly(ci, rect, [Vector2(4, 36), Vector2(96, 32), Vector2(84, 48), Vector2(14, 48)], color)
			if kind == "patrol_boat":
				_poly(ci, rect, [Vector2(34, 36), Vector2(38, 20), Vector2(62, 20), Vector2(66, 34)], color)
				_line(ci, rect, Vector2(50, 20), Vector2(50, 6), color, 2.0)
			else:
				_poly(ci, rect, [Vector2(40, 34), Vector2(44, 26), Vector2(58, 26), Vector2(60, 34)], color)
			_line(ci, rect, Vector2(70, 30), Vector2(88, 26), color, 2.5)
		"strike":
			_circle(ci, rect, Vector2(50, 30), 20.0, color)
			_circle(ci, rect, Vector2(50, 30), 16.0, Color(0, 0, 0, 0.75))
			_line(ci, rect, Vector2(50, 4), Vector2(50, 56), color, 2.5)
			_line(ci, rect, Vector2(24, 30), Vector2(76, 30), color, 2.5)
			_circle(ci, rect, Vector2(50, 30), 4.0, color)
		"airstrike":
			_poly(ci, rect, [Vector2(10, 30), Vector2(70, 26), Vector2(92, 30), Vector2(70, 34)], color)
			_poly(ci, rect, [Vector2(36, 28), Vector2(58, 6), Vector2(66, 6), Vector2(56, 28)], color)
			_poly(ci, rect, [Vector2(36, 32), Vector2(58, 54), Vector2(66, 54), Vector2(56, 32)], color)
			_poly(ci, rect, [Vector2(10, 30), Vector2(14, 18), Vector2(20, 18), Vector2(22, 29)], color)
		_:
			_circle(ci, rect, Vector2(50, 30), 16.0, color)
