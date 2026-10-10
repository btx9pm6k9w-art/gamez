extends Control
## Bottom-centre command bar: the commander's powers as large buttons with
## a cooldown sweep, a pulse when ready and a hotkey badge, then the basic
## orders (attack-move, stop, hold, patrol) as smaller buttons when units are
## selected. Everything here can also be done from the keyboard.

const UI := preload("res://scripts/ui/ui_theme.gd")
const Icons := preload("res://scripts/ui/unit_icons.gd")

const BIG := 64.0
const SMALL := 44.0
const GAP := 8.0
const PAD := 10.0

var selection: SelectionManager
var _slots: Array[Dictionary] = []
var _hover := -1


func setup(sel: SelectionManager) -> void:
	selection = sel
	mouse_filter = Control.MOUSE_FILTER_STOP
	_slots = [
		{"id": "strike", "key": "F", "name": "Precision Strike  $%d  (hits your own units too)" % SelectionManager.STRIKE_COST, "big": true, "total": SelectionManager.STRIKE_COOLDOWN},
		{"id": "airstrike", "key": "G", "name": "Airstrike  $%d  (hits your own units too)" % SelectionManager.AIRSTRIKE_COST, "big": true, "total": SelectionManager.AIRSTRIKE_COOLDOWN},
		{"id": "attack_move", "key": "A", "name": "Attack-move", "big": false},
		{"id": "stop", "key": "S", "name": "Stop", "big": false},
		{"id": "hold", "key": "H", "name": "Hold position", "big": false},
		{"id": "patrol", "key": "P", "name": "Patrol", "big": false},
	]
	var w := PAD * 2.0
	for s in _slots:
		w += (BIG if s["big"] else SMALL) + GAP
	w += 10.0 - GAP
	custom_minimum_size = Vector2(w, BIG + PAD * 2.0 + 16.0)
	size = custom_minimum_size


func _slot_rect(i: int) -> Rect2:
	var x := PAD
	for k in i:
		x += (BIG if _slots[k]["big"] else SMALL) + GAP
		if k == 1:
			x += 10.0 # gap between powers and orders
	var s: float = BIG if _slots[i]["big"] else SMALL
	return Rect2(Vector2(x, PAD + (BIG - s)), Vector2(s, s))


func _cooldown(id: String) -> float:
	match id:
		"strike":
			return selection.strike_cooldown
		"airstrike":
			return selection.airstrike_cooldown
	return 0.0


func _armed(id: String) -> bool:
	match id:
		"strike":
			return selection.strike_armed
		"airstrike":
			return selection.airstrike_armed
		"attack_move":
			return selection.attack_move_armed
		"patrol":
			return selection.patrol_armed
	return false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if selection == null:
		return
	draw_style_box(UI.panel_box(), Rect2(Vector2.ZERO, size))
	var now := Time.get_ticks_msec() / 1000.0
	var has_units := not selection.selected.is_empty() and selection.selected[0].team == Battlefield.COALITION
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var r := _slot_rect(i)
		var big: bool = s["big"]
		var enabled := big or has_units
		var cd := _cooldown(s["id"])
		var is_ready := enabled and cd <= 0.0
		var armed := _armed(s["id"])
		var bg := Color(0.05, 0.1, 0.14, 0.95) if enabled else Color(0.04, 0.06, 0.08, 0.6)
		if i == _hover and enabled:
			bg = Color(0.08, 0.18, 0.24, 0.95)
		draw_rect(r, bg)
		var icon_col := UI.TEXT if is_ready else Color(UI.DIM, 0.6)
		if armed:
			icon_col = UI.WARN
		var icon_rect := r.grow(-r.size.x * 0.16)
		if big:
			Icons.draw(self, s["id"], icon_rect, icon_col)
		else:
			_draw_order_icon(s["id"], icon_rect, icon_col)
		if big and cd > 0.0:
			# Cooldown: dark wedge for the time left, counting down clockwise.
			var frac := clampf(cd / float(s["total"]), 0.0, 1.0)
			var c := r.get_center()
			var pts := PackedVector2Array([c])
			var steps := 24
			for k in steps + 1:
				var a := -PI * 0.5 + TAU * (1.0 - frac) + TAU * frac * k / float(steps)
				var v := Vector2(cos(a), sin(a)) * r.size.x
				pts.append(c + Vector2(clampf(v.x, -r.size.x * 0.5, r.size.x * 0.5), clampf(v.y, -r.size.y * 0.5, r.size.y * 0.5)))
			draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
			draw_string(UI.mono_font(), r.position + Vector2(0, r.size.y * 0.62), "%d" % ceili(cd), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, UI.TEXT)
		var edge := Color(UI.ACCENT, 0.3)
		if armed:
			edge = UI.WARN
		elif big and is_ready:
			edge = Color(UI.ACCENT, 0.55 + 0.45 * sin(now * 4.0))
		draw_rect(r, edge, false, 2.0 if armed or (big and is_ready) else 1.0)
		# Hotkey badge.
		var kb := Rect2(r.position + Vector2(2, 2), Vector2(14, 14))
		draw_rect(kb, Color(0, 0, 0, 0.7))
		draw_string(UI.bold_font(), kb.position + Vector2(0, 12), s["key"], HORIZONTAL_ALIGNMENT_CENTER, 14, 12, UI.ACCENT if enabled else UI.DIM)
	# Name of the hovered slot.
	if _hover >= 0:
		var hs: Dictionary = _slots[_hover]
		var text: String = hs["name"]
		if hs["big"] and _cooldown(hs["id"]) > 0.0:
			text += "  (recharging)"
		draw_string(UI.text_font(), Vector2(PAD, size.y - 6), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2.0, 13, UI.DIM)
	else:
		draw_string(UI.text_font(), Vector2(PAD, size.y - 6), "COMMANDER POWERS            ORDERS", HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2.0, 11, Color(UI.DIM, 0.7))


func _draw_order_icon(id: String, r: Rect2, col: Color) -> void:
	var c := r.get_center()
	var e := r.size.x * 0.4
	match id:
		"attack_move":
			draw_line(c + Vector2(-e, e), c + Vector2(e, -e), col, 2.5)
			draw_colored_polygon(PackedVector2Array([c + Vector2(e, -e), c + Vector2(e * 0.2, -e), c + Vector2(e, -e * 0.2)]), col)
			draw_arc(c + Vector2(-e * 0.4, e * 0.4), e * 0.35, 0, TAU, 16, col, 1.5)
		"stop":
			draw_rect(Rect2(c - Vector2(e, e) * 0.7, Vector2(e, e) * 1.4), col)
		"hold":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-e * 0.8, -e), c + Vector2(e * 0.8, -e), c + Vector2(e * 0.8, e * 0.1), c + Vector2(0, e), c + Vector2(-e * 0.8, e * 0.1)]), col)
		"patrol":
			draw_arc(c, e * 0.8, PI * 0.15, PI * 1.1, 20, col, 2.0)
			draw_arc(c, e * 0.8, PI * 1.15, PI * 2.1, 20, col, 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(e * 0.8, -e * 0.5), c + Vector2(e * 1.15, -e * 0.05), c + Vector2(e * 0.45, -e * 0.05)]), col)


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm:
		_hover = -1
		for i in _slots.size():
			if _slot_rect(i).has_point(mm.position):
				_hover = i
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		for i in _slots.size():
			if _slot_rect(i).has_point(mb.position):
				selection.use_command(_slots[i]["id"])
				accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1
