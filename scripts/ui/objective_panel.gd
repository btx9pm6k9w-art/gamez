extends Control
## Objective tracker: primary objectives as diamonds, bonus ones as circles,
## live progress under each, a green flash when one completes and red when
## one fails. Reads the mission's objective list (scripts/missions/mission.gd).

const UI := preload("res://scripts/ui/ui_theme.gd")

const WIDTH := 380.0
const ROW := 24.0
const SUB := 18.0

var mission: Node
var _flash := {} # objective id -> time its state changed
var _last_state := {}


func set_mission(m: Node) -> void:
	mission = m
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh()


func refresh() -> void:
	if mission == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var h := 34.0
	for o: Dictionary in mission.objectives:
		var st: int = o["state"]
		if _last_state.get(o["id"], st) != st:
			_flash[o["id"]] = now
		_last_state[o["id"]] = st
		if st == 0:
			continue
		h += ROW
		if st == 1 and o["progress"] != "":
			h += SUB
	h += 8.0
	custom_minimum_size = Vector2(WIDTH, h)
	size = custom_minimum_size
	queue_redraw()


func _process(_delta: float) -> void:
	if not _flash.is_empty():
		queue_redraw()


func _draw() -> void:
	if mission == null:
		return
	draw_style_box(UI.panel_box(), Rect2(Vector2.ZERO, size))
	UI.draw_header(self, Vector2(12, 6), size.x - 24, "Objectives")
	var now := Time.get_ticks_msec() / 1000.0
	var y := 34.0
	var f := UI.text_font()
	for o: Dictionary in mission.objectives:
		var st: int = o["state"]
		if st == 0:
			continue
		var primary: bool = o["primary"]
		var col := UI.TEXT if primary else UI.DIM
		var icon_col := UI.ACCENT if primary else UI.DIM
		if st == 2:
			col = Color(UI.GOOD, 0.8)
			icon_col = UI.GOOD
		elif st == 3:
			col = Color(UI.DANGER, 0.85)
			icon_col = UI.DANGER
		var row_h := ROW + (SUB if st == 1 and o["progress"] != "" else 0.0)
		if _flash.has(o["id"]):
			var age: float = now - float(_flash[o["id"]])
			if age > 2.0:
				_flash.erase(o["id"])
			else:
				draw_rect(Rect2(Vector2(4, y - 2), Vector2(size.x - 8, row_h)), Color(icon_col, 0.25 * (1.0 - age / 2.0)))
		var c := Vector2(20, y + 10)
		if primary:
			var d := PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0), c + Vector2(0, -6)])
			if st == 2:
				draw_colored_polygon(d, icon_col)
			else:
				draw_polyline(d, icon_col, 1.5, true)
		else:
			if st == 2:
				draw_circle(c, 5.0, icon_col)
			else:
				draw_arc(c, 5.0, 0, TAU, 16, icon_col, 1.5, true)
		if st == 2:
			draw_polyline(PackedVector2Array([c + Vector2(-3, 0), c + Vector2(-1, 3), c + Vector2(4, -3)]), Color(0, 0, 0, 0.8), 1.6, true)
		elif st == 3:
			draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), icon_col, 1.8)
			draw_line(c + Vector2(4, -4), c + Vector2(-4, 4), icon_col, 1.8)
		draw_string(f, Vector2(34, y + 15), String(o["text"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 46, 15, col)
		y += ROW
		if st == 1 and o["progress"] != "":
			draw_string(UI.mono_font(), Vector2(34, y + 11), String(o["progress"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 46, 12, Color(UI.ACCENT, 0.8))
			y += SUB
