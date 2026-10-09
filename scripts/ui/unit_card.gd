extends Control
## Bottom-left selection card. One unit type selected: a portrait with the
## unit's silhouette on its faction colour, name, health, weapon, armour and
## what it is strong and weak against (from the counter table). Several
## types: a grid of portraits with health, one per unit; click one to keep
## only that type selected.

const UI := preload("res://scripts/ui/ui_theme.gd")
const Icons := preload("res://scripts/ui/unit_icons.gd")

const W := 400.0
const H := 140.0
const TILE := 44.0

var selection: SelectionManager
var _tiles: Array[Dictionary] = [] # {rect, unit}


func setup(sel: SelectionManager) -> void:
	selection = sel
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func _portrait(r: Rect2, u: Unit, big: bool) -> void:
	var fc := UI.COALITION if u.team == Battlefield.COALITION else UI.IRAN
	draw_rect(r, Color(fc.darkened(0.75), 0.95))
	# Soft vertical gradient for depth.
	for k in 6:
		draw_rect(Rect2(r.position + Vector2(0, r.size.y * k / 6.0), Vector2(r.size.x, r.size.y / 6.0)), Color(fc, 0.04 * (6 - k)))
	Icons.draw(self, u.unit_id, r.grow(-r.size.x * (0.1 if big else 0.08)), Color(fc.lightened(0.35), 0.95))
	draw_rect(r, Color(fc, 0.6), false, 1.0)


func _hp_bar(r: Rect2, frac: float, segments: int) -> void:
	draw_rect(r, Color(0, 0, 0, 0.6))
	var col := UI.GOOD if frac > 0.6 else (UI.WARN if frac > 0.3 else UI.DANGER)
	draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), col)
	for k in range(1, segments):
		var x := r.position.x + r.size.x * k / float(segments)
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.6), 1.0)


func _draw() -> void:
	if selection == null:
		return
	draw_style_box(UI.panel_box(), Rect2(Vector2.ZERO, size))
	_tiles.clear()
	var units: Array[Unit] = []
	for u in selection.selected:
		if is_instance_valid(u) and u.is_alive():
			units.append(u)
	if units.is_empty():
		UI.draw_header(self, Vector2(12, 6), size.x - 24, "No selection")
		var f := UI.text_font()
		draw_string(f, Vector2(14, 52), "Drag a box around your forces, or press TAB for the whole army.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 14, UI.DIM)
		draw_string(f, Vector2(14, 74), "Right click to move or attack. A attack-moves, Shift queues.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 14, UI.DIM)
		draw_string(f, Vector2(14, 96), "F10 shows every control.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 14, UI.DIM)
		return
	var types := {}
	for u in units:
		types[u.unit_id] = true
	if types.size() == 1:
		_draw_single(units)
	else:
		_draw_group(units)


func _draw_single(units: Array[Unit]) -> void:
	var u := units[0]
	var def := u.def
	var portrait := Rect2(Vector2(12, 12), Vector2(116, 116))
	_portrait(portrait, u, true)
	if units.size() > 1:
		draw_rect(Rect2(portrait.end - Vector2(34, 22), Vector2(34, 22)), Color(0, 0, 0, 0.75))
		draw_string(UI.bold_font(), portrait.end - Vector2(34, 5), "x%d" % units.size(), HORIZONTAL_ALIGNMENT_CENTER, 34, 16, UI.TEXT)
	var x := 142.0
	var w := size.x - x - 12.0
	var fc := UI.COALITION if u.team == Battlefield.COALITION else UI.IRAN
	draw_string(UI.bold_font(), Vector2(x, 32), String(def["display"]), HORIZONTAL_ALIGNMENT_LEFT, w, 20, UI.TEXT)
	draw_string(UI.header_font(), Vector2(x, 50), String(UnitDefs.FACTION_NAMES[u.faction]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 11, fc)
	var hp := 0.0
	var max_hp := 0.0
	for o in units:
		hp += o.hp
		max_hp += o.max_hp
	_hp_bar(Rect2(Vector2(x, 58), Vector2(w, 8)), clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0), 10)
	draw_string(UI.mono_font(), Vector2(x, 82), "%d / %d" % [int(hp), int(max_hp)], HORIZONTAL_ALIGNMENT_LEFT, w, 13, UI.DIM)
	var weapon := String(def["weapon"])
	var armor := String(def.get("armor", ""))
	draw_string(UI.text_font(), Vector2(x + 110, 82), "%s  |  %s armour" % [weapon.replace("_", " ").capitalize(), armor.capitalize()], HORIZONTAL_ALIGNMENT_LEFT, w - 110, 13, UI.DIM)
	var strong: Array[String] = []
	var weak: Array[String] = []
	if UnitDefs.VS_ARMOR.has(weapon):
		var table: Dictionary = UnitDefs.VS_ARMOR[weapon]
		for cls: String in table:
			var m: float = table[cls]
			if m >= 1.2:
				strong.append(cls)
			elif m <= 0.4:
				weak.append(cls)
	if not strong.is_empty():
		draw_string(UI.text_font(), Vector2(x, 104), "Strong vs " + ", ".join(strong), HORIZONTAL_ALIGNMENT_LEFT, w, 14, UI.GOOD)
	if not weak.is_empty():
		draw_string(UI.text_font(), Vector2(x, 124), "Weak vs " + ", ".join(weak), HORIZONTAL_ALIGNMENT_LEFT, w, 14, Color(UI.DANGER, 0.9))
	var state_text := ""
	if u.hold:
		state_text = "HOLDING"
	elif u.patrol:
		state_text = "PATROL"
	elif not u.waypoints.is_empty():
		state_text = "%d WAYPOINTS" % (u.waypoints.size() + 1)
	if state_text != "":
		draw_string(UI.header_font(), Vector2(x, 32), state_text, HORIZONTAL_ALIGNMENT_RIGHT, w, 11, UI.WARN)


func _draw_group(units: Array[Unit]) -> void:
	UI.draw_header(self, Vector2(12, 6), size.x - 24, "%d units selected" % units.size())
	var cols := int((size.x - 24) / (TILE + 4))
	var shown := mini(units.size(), cols * 2)
	for i in shown:
		var u := units[i]
		var r := Rect2(Vector2(12 + (i % cols) * (TILE + 4), 36 + (i / cols) * (TILE + 10)), Vector2(TILE, TILE))
		_portrait(r, u, false)
		_hp_bar(Rect2(Vector2(r.position.x, r.end.y + 2), Vector2(TILE, 4)), clampf(u.hp / u.max_hp, 0.0, 1.0), 1)
		_tiles.append({"rect": r, "unit": u})
	if units.size() > shown:
		draw_string(UI.text_font(), Vector2(12, size.y - 8), "+%d more" % (units.size() - shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for t in _tiles:
		if (t["rect"] as Rect2).has_point(mb.position):
			var picked: Unit = t["unit"]
			if not is_instance_valid(picked):
				return
			var keep: Array[Unit] = []
			for u in selection.selected:
				if is_instance_valid(u) and u.unit_id == picked.unit_id:
					keep.append(u)
			if mb.shift_pressed:
				keep = [picked]
			selection.select_units(keep)
			accept_event()
			return
