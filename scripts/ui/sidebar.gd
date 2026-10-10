extends Control
## C&C-style command sidebar on the right, in the tactical-glass style:
## a credits ticker with income, then one build card per unit, grouped by
## production line (infantry, vehicles, naval). Each card shows the unit's
## silhouette, cost and queue count; while building, a dark shutter lifts
## off the card like the classic clock overlay. Left click queues, right
## click cancels. Hovering a card explains the unit at the bottom.
## In base mode a power meter and two tabs appear: Base (structures, built
## one at a time by the FOB and placed on the map when ready) and Units.

const Economy := preload("res://scripts/game/economy.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")
const Icons := preload("res://scripts/ui/unit_icons.gd")

const W := 236.0
const PAD := 10.0
const CARD := Vector2(102, 70)
const GAP := 6.0
const CATEGORY_NAMES := {"infantry": "Infantry", "vehicle": "Vehicles", "naval": "Naval"}

var economy: Economy
var selection: SelectionManager

var _cards: Array[Dictionary] = [] # {id, rect} of the tab on show
var _heads: Array[Dictionary] = [] # {text, y}
var _tabs := {} # tab name -> {"cards", "heads", "rect"}
var _tab := "units"
var _laid_out_base := false
var _rally_rect: Rect2
var _info_y := 0.0
var _hover := ""
var _hover_rally := false
var _shown_credits := 0.0
var _flash := {} # id -> time a unit of it was delivered


func setup(eco: Economy, sel: SelectionManager) -> void:
	economy = eco
	selection = sel
	_shown_credits = eco.credits
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout()
	eco.unit_delivered.connect(func(u: Unit) -> void: _flash[u.unit_id] = Time.get_ticks_msec() / 1000.0)
	eco.structure_finished.connect(func(id: String) -> void:
		_flash[id] = Time.get_ticks_msec() / 1000.0
		_show_tab("base"))


func _layout() -> void:
	_laid_out_base = economy.base_mode
	_tabs.clear()
	var top := 144.0 if economy.base_mode else 100.0
	var by_cat := {}
	for id in UnitDefs.buildable("coalition"):
		var cat: String = UnitDefs.get_def(id)["category"]
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append(id)
	var units := _grid(by_cat, Economy.CATEGORIES, top)
	_tabs["units"] = units
	var bottom: float = units["bottom"]
	if economy.base_mode:
		var base := _grid({"structure": BuildingDefs.BUILD_ORDER}, ["structure"], top)
		_tabs["base"] = base
		bottom = maxf(bottom, base["bottom"])
		var tw := (W - PAD * 2.0 - GAP) * 0.5
		base["rect"] = Rect2(Vector2(PAD, 112), Vector2(tw, 24))
		units["rect"] = Rect2(Vector2(PAD + tw + GAP, 112), Vector2(tw, 24))
	_rally_rect = Rect2(Vector2(PAD, bottom), Vector2(W - PAD * 2.0, 30))
	_info_y = _rally_rect.end.y + 8.0
	custom_minimum_size = Vector2(W, _info_y + 58.0)
	size = custom_minimum_size
	offset_bottom = offset_top + custom_minimum_size.y
	_show_tab("base" if economy.base_mode else "units")


func _grid(by_cat: Dictionary, order: Array, top: float) -> Dictionary:
	var cards: Array[Dictionary] = []
	var heads: Array[Dictionary] = []
	var y := top
	for cat: String in order:
		if not by_cat.has(cat):
			continue
		heads.append({"text": CATEGORY_NAMES.get(cat, "Structures"), "y": y})
		y += 20.0
		var ids: Array = by_cat[cat]
		for i in ids.size():
			var r := Rect2(Vector2(PAD + (i % 2) * (CARD.x + GAP), y + (i / 2) * (CARD.y + GAP)), CARD)
			cards.append({"id": ids[i], "rect": r})
		y += ceili(ids.size() / 2.0) * (CARD.y + GAP) + 4.0
	return {"cards": cards, "heads": heads, "bottom": y}


func _show_tab(tab: String) -> void:
	if not _tabs.has(tab):
		return
	_tab = tab
	_cards = _tabs[tab]["cards"]
	_heads = _tabs[tab]["heads"]


func _process(delta: float) -> void:
	if economy == null:
		return
	if economy.base_mode != _laid_out_base:
		_layout()
	# Credits count up and down like the classic ticker.
	_shown_credits = move_toward(_shown_credits, economy.credits, maxf(absf(economy.credits - _shown_credits) * delta * 6.0, 40.0 * delta))
	queue_redraw()


func _draw() -> void:
	if economy == null:
		return
	draw_style_box(UI.panel_box(UI.PANEL, UI.ACCENT_DIM, 3), Rect2(Vector2.ZERO, size))
	UI.draw_header(self, Vector2(PAD, 6), W - PAD * 2.0, "Command")
	# Credits.
	var gold := Color(1.0, 0.82, 0.38)
	draw_string(UI.mono_font(), Vector2(PAD, 64), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(gold, 0.7))
	draw_string(UI.mono_font(), Vector2(PAD + 18, 64), _group(int(_shown_credits)), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, gold)
	var n := economy.owned_derricks()
	var income := ("+%d/s  from %d derrick%s" % [int(economy.income_per_second()), n, "" if n == 1 else "s"]) if n > 0 else "No income: capture the oil derricks"
	if economy.base_mode and economy.count_structures("refinery") > 0:
		income = "+%d/s  from oil" % int(economy.income_per_second())
		n = 1
	draw_string(UI.text_font(), Vector2(PAD, 86), income, HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2.0, 14, UI.GOOD if n > 0 else UI.WARN)
	if economy.base_mode:
		_draw_power_and_tabs()
	for h in _heads:
		var hy: float = h["y"]
		draw_string(UI.header_font(), Vector2(PAD, hy + 13), String(h["text"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.DIM)
		draw_line(Vector2(PAD + 80, hy + 9), Vector2(W - PAD, hy + 9), Color(UI.ACCENT, 0.15), 1.0)
	var now := Time.get_ticks_msec() / 1000.0
	for c in _cards:
		_draw_card(c["id"], c["rect"], now)
	# Rally point button.
	var rally_on := selection.rally_armed
	draw_rect(_rally_rect, Color(0.08, 0.18, 0.24, 0.95) if _hover_rally or rally_on else Color(0.05, 0.1, 0.14, 0.9))
	draw_rect(Rect2(_rally_rect.position, Vector2(3, _rally_rect.size.y)), UI.WARN if rally_on else UI.ACCENT)
	draw_rect(_rally_rect, Color(UI.ACCENT, 0.3), false, 1.0)
	var flag := _rally_rect.position + Vector2(16, 7)
	draw_line(flag, flag + Vector2(0, 17), UI.TEXT, 2.0)
	draw_colored_polygon(PackedVector2Array([flag, flag + Vector2(11, 4), flag + Vector2(0, 8)]), UI.WARN if rally_on else UI.ACCENT)
	draw_string(UI.bold_font(), _rally_rect.position + Vector2(36, 21), "Click the map..." if rally_on else "Set rally point", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.TEXT)
	_draw_info()


func _draw_power_and_tabs() -> void:
	var supply := economy.power_supply()
	var drain := economy.power_drain()
	var low := drain > supply
	var col := UI.DANGER if low else (UI.WARN if drain > supply * 0.85 else UI.GOOD)
	var bar := Rect2(Vector2(PAD + 52, 96), Vector2(W - PAD * 2.0 - 52, 8))
	draw_string(UI.header_font(), Vector2(PAD, 105), "POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
	draw_rect(bar, Color(0, 0, 0, 0.5))
	var full := maxf(float(maxi(supply, drain)), 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * supply / full, bar.size.y)), Color(col, 0.35))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * minf(drain / full, 1.0), bar.size.y)), col)
	draw_string(UI.mono_font(), bar.position + Vector2(0, -2), "%d / %d" % [drain, supply], HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x, 11, UI.TEXT)
	for tab: String in ["base", "units"]:
		var r: Rect2 = _tabs[tab]["rect"]
		var on := _tab == tab
		draw_rect(r, Color(0.06, 0.16, 0.22, 0.95) if on else Color(0.03, 0.07, 0.1, 0.9))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), UI.ACCENT if on else Color(UI.ACCENT, 0.2))
		var label := "BASE" if tab == "base" else "UNITS"
		if tab == "base" and economy.structure_ready != "":
			label = "BASE  READY"
		draw_string(UI.header_font(), r.position + Vector2(0, 17), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, UI.TEXT if on else UI.DIM)


## Why a card cannot be bought now ("" when it can).
func _lock_reason(id: String) -> String:
	if BuildingDefs.has(id):
		var req := economy.missing_requirement(id)
		if req != "":
			return "Needs " + _short(BuildingDefs.get_def(req))
		return ""
	var cat: String = UnitDefs.get_def(id)["category"]
	if economy.line_open(cat):
		return ""
	if cat == "naval":
		return "No harbour"
	return "Needs " + ("Barracks" if cat == "infantry" else "Vehicle Depot")


func _draw_card(id: String, r: Rect2, now: float) -> void:
	var def := UnitDefs.get_def(id)
	var cost: int = def["cost"]
	var is_structure := BuildingDefs.has(id)
	var q := 0
	var prog := 0.0
	if is_structure:
		q = 1 if economy.structure_queue == id or economy.structure_ready == id else 0
		prog = economy.structure_progress_of(id)
	else:
		q = economy.queued(id)
		prog = economy.progress_of(id)
	var lock := _lock_reason(id)
	var ready := is_structure and economy.structure_ready == id
	var affordable := economy.credits >= float(cost) and lock == ""
	var hover := _hover == id
	var bg := Color(0.06, 0.13, 0.19, 0.95) if hover else Color(0.04, 0.09, 0.13, 0.92)
	draw_rect(r, bg)
	# Faint stripes behind the silhouette, like a hangar placard.
	for k in 4:
		draw_rect(Rect2(r.position + Vector2(0, r.size.y * (0.2 + k * 0.15)), Vector2(r.size.x, 1)), Color(UI.ACCENT, 0.05))
	var icol := Color(UI.COALITION.lightened(0.35), 0.95) if affordable or q > 0 else Color(UI.DIM, 0.45)
	Icons.draw(self, id, Rect2(r.position + Vector2(10, 10), Vector2(r.size.x - 20, r.size.y - 30)), icol)
	if q > 0 and prog > 0.0:
		# Shutter: the unbuilt part stays dark and lifts as work progresses.
		var h := r.size.y * (1.0 - prog)
		draw_rect(Rect2(r.position, Vector2(r.size.x, h)), Color(0, 0, 0, 0.55))
		draw_line(r.position + Vector2(0, h), r.position + Vector2(r.size.x, h), Color(UI.ACCENT, 0.9), 1.5)
	# Name strip.
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 18), Vector2(r.size.x, 18)), Color(0, 0, 0, 0.5))
	draw_string(UI.bold_font(), r.position + Vector2(5, r.size.y - 4), _short(def), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10, 13, UI.TEXT if affordable or q > 0 else UI.DIM)
	if lock != "":
		draw_rect(r, Color(0, 0, 0, 0.45))
		draw_string(UI.text_font(), r.position + Vector2(0, 34), lock, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, UI.WARN)
	if ready:
		var pulse := 0.6 + 0.4 * sin(now * 6.0)
		var tag2 := Rect2(r.position + Vector2(r.size.x - 52, 3), Vector2(49, 16))
		draw_rect(tag2, Color(UI.GOOD, pulse))
		draw_string(UI.bold_font(), tag2.position + Vector2(0, 13), "READY", HORIZONTAL_ALIGNMENT_CENTER, tag2.size.x, 13, Color(0.02, 0.05, 0.08))
	elif q > 0 and prog > 0.0:
		# Build progress replaces the price while the card is building.
		var tag := Rect2(r.position + Vector2(r.size.x - 40, 3), Vector2(37, 16))
		draw_rect(tag, Color(0, 0, 0, 0.8))
		draw_string(UI.mono_font(), tag.position + Vector2(0, 13), "%d%%" % int(prog * 100.0), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 13, UI.ACCENT)
	else:
		draw_string(UI.mono_font(), r.position + Vector2(0, 14), "%d" % cost, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 5, 12, Color(1.0, 0.82, 0.38) if affordable else UI.DANGER)
	if q > 0 and not is_structure:
		var badge := Rect2(r.position + Vector2(3, 3), Vector2(24, 16))
		draw_rect(badge, UI.ACCENT)
		draw_string(UI.bold_font(), badge.position + Vector2(0, 13), "x%d" % q, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 13, Color(0.02, 0.05, 0.08))
	var edge := Color(UI.ACCENT, 0.7) if hover else Color(UI.ACCENT, 0.2)
	var since := now - float(_flash.get(id, -10.0))
	if since < 0.8:
		edge = UI.GOOD.lerp(edge, since / 0.8)
	draw_rect(r, edge, false, 1.5 if hover else 1.0)


func _draw_info() -> void:
	var y := _info_y
	draw_line(Vector2(PAD, y), Vector2(W - PAD, y), Color(UI.ACCENT, 0.15), 1.0)
	if _hover == "":
		draw_string(UI.text_font(), Vector2(PAD, y + 20), "Left click builds, right click cancels.", HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2.0, 13, UI.DIM)
		draw_string(UI.text_font(), Vector2(PAD, y + 38), "New units go to the rally point.", HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2.0, 13, UI.DIM)
		return
	var def := UnitDefs.get_def(_hover)
	draw_string(UI.bold_font(), Vector2(PAD, y + 20), String(def["display"]), HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2.0 - 40, 15, UI.TEXT)
	draw_string(UI.mono_font(), Vector2(PAD, y + 20), "%ds" % int(def["build_time"]), HORIZONTAL_ALIGNMENT_RIGHT, W - PAD * 2.0, 13, UI.DIM)
	if def.get("structure", false):
		var pw := int(def["power"])
		draw_string(UI.text_font(), Vector2(PAD, y + 38), String(def.get("blurb", "")), HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2.0, 12, UI.GOOD)
		var line2 := ("Power +%d" % pw) if pw > 0 else ("Power %d" % pw)
		if economy.structure_ready == _hover:
			line2 = "Click to place it on the map"
		draw_string(UI.text_font(), Vector2(PAD, y + 54), line2, HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2.0, 13, UI.ACCENT if economy.structure_ready == _hover else UI.DIM)
		return
	var weapon := String(def["weapon"])
	var strong: Array[String] = []
	if UnitDefs.VS_ARMOR.has(weapon):
		var table: Dictionary = UnitDefs.VS_ARMOR[weapon]
		for cls: String in table:
			if float(table[cls]) >= 1.2:
				strong.append(cls)
	var line := "Strong vs " + ", ".join(strong) if not strong.is_empty() else "All-round"
	draw_string(UI.text_font(), Vector2(PAD, y + 38), line, HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2.0, 13, UI.GOOD)
	draw_string(UI.text_font(), Vector2(PAD, y + 54), "%s armour" % String(def.get("armor", "")).capitalize(), HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2.0, 13, UI.DIM)


func _short(def: Dictionary) -> String:
	return String(def["display"]).replace("-class", "").replace(" Air Defence", " AD").replace("Mk VI ", "")


## 12345 -> "12,345"
func _group(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm:
		_hover = ""
		for c in _cards:
			if (c["rect"] as Rect2).has_point(mm.position):
				_hover = c["id"]
		_hover_rally = _rally_rect.has_point(mm.position)
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	for tab: String in _tabs:
		if _tabs[tab].has("rect") and (_tabs[tab]["rect"] as Rect2).has_point(mb.position):
			_show_tab(tab)
			Audio.play_ui("ui_select")
			accept_event()
			return
	if _rally_rect.has_point(mb.position) and mb.button_index == MOUSE_BUTTON_LEFT:
		selection.rally_armed = true
		Audio.play_ui("ui_select")
		accept_event()
		return
	for c in _cards:
		if (c["rect"] as Rect2).has_point(mb.position):
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if economy.structure_ready == c["id"] and selection.placer != null:
					selection.placer.arm(c["id"])
				else:
					economy.build(c["id"])
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				economy.cancel(c["id"])
			accept_event()
			return
	accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = ""
		_hover_rally = false
