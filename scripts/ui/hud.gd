class_name HUD
extends CanvasLayer
## Tactical HUD in the "tactical glass" style (scripts/ui/ui_theme.gd):
## a thin top bar, objective tracker, event feed, selection card with
## portraits, command bar with commander powers and orders, tactical map
## with radar sweep, in-world health and capture bars, a centre banner for
## big moments and the controls overlay. Built in code so the layout scales
## with the window (Retina included).

const UnitVoice := preload("res://scripts/audio/unit_voice.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")
const Minimap := preload("res://scripts/ui/minimap.gd")
const ObjectivePanel := preload("res://scripts/ui/objective_panel.gd")
const AbilityBar := preload("res://scripts/ui/ability_bar.gd")
const UnitCard := preload("res://scripts/ui/unit_card.gd")
const AlertFeed := preload("res://scripts/ui/alert_feed.gd")

const ACCENT := UI.ACCENT
const WARN := UI.WARN

var battlefield: Battlefield
var selection: SelectionManager
var rig: RTSCamera
var ai: SimpleAI
## The running mission (scripts/missions/mission.gd) and its economy; untyped
## so the HUD works without a mission too.
var mission: Node
var economy: Node

var _overlay: Control
var _top: Control
var _banner: Label
var _banner_sub: Label
var _banner_box: VBoxContainer
var _banner_time := 0.0
var _help: PanelContainer
var _minimap: Control
var _objectives: Control
var _feed: VBoxContainer
var _abilities: Control
var _card: Control
var _post: ColorRect


func _ready() -> void:
	layer = 1
	get_tree().root.theme = UI.build()
	var post_layer := CanvasLayer.new()
	post_layer.layer = 0
	add_sibling.call_deferred(post_layer)
	_post = ColorRect.new()
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/post_process.gdshader")
	_post.material = pm
	post_layer.add_child(_post)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_top = Control.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_bottom = 34
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.draw.connect(_draw_top)
	add_child(_top)

	_objectives = ObjectivePanel.new()
	_objectives.position = Vector2(16, 46)
	_objectives.visible = false
	add_child(_objectives)

	_feed = AlertFeed.new()
	_feed.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_feed.offset_left = 16
	_feed.offset_right = 420
	_feed.offset_top = 0
	add_child(_feed)

	_card = UnitCard.new()
	_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	add_child(_card)

	_abilities = AbilityBar.new()
	_abilities.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	add_child(_abilities)

	_minimap = Minimap.new()
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	add_child(_minimap)

	_banner_box = VBoxContainer.new()
	_banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_box.offset_top = 110
	_banner_box.offset_left = -560
	_banner_box.offset_right = 560
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_banner_box)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_override("font", UI.header_font())
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_banner_box.add_child(_banner)
	_banner_sub = Label.new()
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_font_size_override("font_size", 16)
	_banner_sub.add_theme_constant_override("outline_size", 6)
	_banner_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_banner_box.add_child(_banner_sub)
	_banner_box.modulate.a = 0.0

	_help = PanelContainer.new()
	_help.set_anchors_preset(Control.PRESET_CENTER)
	_help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_help.grow_vertical = Control.GROW_DIRECTION_BOTH
	_help.add_theme_stylebox_override("panel", UI.panel_box(UI.PANEL_SOLID, UI.ACCENT_DIM, 3))
	_help.visible = false
	add_child(_help)
	var help := Label.new()
	help.add_theme_font_override("font", UI.mono_font())
	help.add_theme_font_size_override("font_size", 14)
	help.text = "\n".join([
		"CONTROLS",
		"",
		"Left click / drag      select   (Shift adds, double-click or Ctrl+click = all of type)",
		"Right click            move, or attack the enemy under the cursor  (Shift queues)",
		"A  attack-move    S  stop    H  hold position    P  patrol    TAB  whole army",
		"Ctrl/Cmd + 1..9        set group        1..9  recall  (twice = jump to it)",
		"SPACE  last alert      HOME  reset camera      - =  scroll speed",
		"Screen edge / arrows / middle drag  pan      wheel / pinch  zoom     Q E  rotate",
		"F  Precision Strike    G  Airstrike    (or click the command bar)",
		"Minimap: left click jumps, right click sends the selection",
		"Sidebar: left click builds, right click cancels, Set rally point",
		"Oil: stand by a derrick with no enemy near to capture it",
		"F9  lock mouse   V  voices   T  time of day   F1-F4  graphics   F5  HDR",
		"F6  restart   F8  unit showcase   F11  fullscreen   F10 or ?  this help",
	])
	_help.add_child(help)


func setup(bf: Battlefield, sel: SelectionManager, camera_rig: RTSCamera, p_ai: SimpleAI) -> void:
	battlefield = bf
	selection = sel
	rig = camera_rig
	ai = p_ai
	_minimap.setup(bf, sel, camera_rig)
	_minimap.offset_left = -_minimap.custom_minimum_size.x - 16
	_minimap.offset_top = -_minimap.custom_minimum_size.y - 16
	_minimap.offset_right = -16
	_minimap.offset_bottom = -16
	_card.setup(sel)
	_card.offset_left = 16
	_card.offset_top = -_card.custom_minimum_size.y - 16
	_card.offset_right = 16 + _card.custom_minimum_size.x
	_card.offset_bottom = -16
	_abilities.setup(sel)
	_abilities.offset_left = -_abilities.custom_minimum_size.x * 0.5
	_abilities.offset_right = _abilities.custom_minimum_size.x * 0.5
	_abilities.offset_top = -_abilities.custom_minimum_size.y - 16
	_abilities.offset_bottom = -16
	VFX.flash_requested.connect(_on_flash)
	ai.wave_incoming.connect(func(i: int, total: int) -> void:
		show_message("Enemy wave %d of %d" % [i, total], WARN, 4.0, "Incoming from " + ai.last_wave_from)
		UnitVoice.alert("wave", 0.0))
	rig.setting_changed.connect(func(text: String) -> void: notify(text))
	sel.alert_raised.connect(func(_pos: Vector3) -> void: notify("Units under attack. SPACE to jump there", WARN))
	GameSettings.preset_changed.connect(_on_preset_changed)
	_on_preset_changed(GameSettings.preset)


## Hook up the running mission: objective panel, notices and derrick markers.
func set_mission(m: Node, eco: Node) -> void:
	mission = m
	economy = eco
	_minimap.economy = eco
	_objectives.visible = true
	_objectives.set_mission(m)
	m.objectives_changed.connect(_objectives.refresh)
	m.objective_completed.connect(func(text: String) -> void:
		show_message("Objective complete", UI.GOOD, 3.0, text)
		notify("Objective complete: " + text, UI.GOOD))
	m.objective_added.connect(func(text: String) -> void:
		show_message("New objective", ACCENT, 3.5, text)
		notify("New objective: " + text))
	eco.derrick_changed.connect(func(_i: int, holder: int) -> void:
		if holder == Battlefield.COALITION:
			notify("Oil derrick captured", UI.GOOD)
		elif holder == Battlefield.IRAN:
			notify("Oil derrick lost", UI.DANGER))
	eco.unit_delivered.connect(func(u: Unit) -> void: notify("Reinforcements: " + u.display_name()))


func _on_flash(strength: float, origin: Vector3) -> void:
	var cam := rig.camera
	if not _post.visible or cam.is_position_behind(origin) or not cam.is_position_in_frustum(origin):
		return
	var m := _post.material as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("flash", v), strength, 0.0, 0.25 + strength * 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)


func _on_preset_changed(p: int) -> void:
	_post.visible = p >= GameSettings.Preset.MEDIUM


## Big centre banner for moments that matter (mission start, waves,
## objectives, victory). Small notices go to notify().
func show_message(text: String, color := ACCENT, duration := 4.0, sub := "") -> void:
	_banner.text = text.to_upper()
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	_banner_sub.visible = sub != ""
	_banner_time = duration
	_banner_box.modulate.a = 0.0
	_banner_box.scale = Vector2(1.06, 1.06)
	_banner_box.pivot_offset = _banner_box.size * 0.5
	var tw := create_tween()
	tw.tween_property(_banner_box, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(_banner_box, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	Audio.play_ui("alert")


func notify(text: String, color := ACCENT) -> void:
	_feed.push(text, color)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		_help.visible = not _help.visible


func _process(delta: float) -> void:
	if battlefield == null:
		return
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time <= 0.0:
			var tw := create_tween()
			tw.tween_property(_banner_box, "modulate:a", 0.0, 0.5)
	_top.queue_redraw()
	_overlay.queue_redraw()


func _draw_top() -> void:
	var s := _top.size
	_top.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.05, 0.08, 0.78))
	_top.draw_line(Vector2(0, s.y), Vector2(s.x, s.y), Color(ACCENT, 0.3), 1.0)
	var y := 23.0
	var x := 16.0
	_top.draw_rect(Rect2(Vector2(x, 9), Vector2(3, 16)), ACCENT)
	_top.draw_string(UI.header_font(), Vector2(x + 10, y), "FRACTURE LINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ACCENT)
	x += 160.0
	var title := "Strait of Hormuz"
	if mission != null:
		title = String(mission.briefing().get("title", title)).capitalize()
	_top.draw_string(UI.bold_font(), Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.TEXT)
	if mission != null:
		var t: float = mission.elapsed
		_top.draw_string(UI.mono_font(), Vector2(x + 250, y), "T+%02d:%02d" % [int(t) / 60, int(t) % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.DIM)
	# Force balance in the middle.
	var own: int = battlefield.units[Battlefield.COALITION].size()
	var enemy: int = battlefield.units[Battlefield.IRAN].size()
	var cx := s.x * 0.5
	_top.draw_string(UI.mono_font(), Vector2(cx - 120, y), "%3d" % own, HORIZONTAL_ALIGNMENT_RIGHT, 60, 16, UI.COALITION)
	_top.draw_string(UI.header_font(), Vector2(cx - 54, y), "COALITION", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UI.COALITION, 0.8))
	_top.draw_string(UI.header_font(), Vector2(cx + 16, y), "IRAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UI.IRAN, 0.8))
	_top.draw_string(UI.mono_font(), Vector2(cx + 54, y), "%d" % enemy, HORIZONTAL_ALIGNMENT_LEFT, 60, 16, UI.IRAN)
	_top.draw_line(Vector2(cx + 6, 10), Vector2(cx + 6, 26), Color(1, 1, 1, 0.2), 1.0)
	# System info on the right.
	var tod: String = ["Golden hour", "Midday", "Night"][battlefield.time_of_day]
	var info := "Waves %d   |   %s   |   %s%s   |   %d fps" % [ai.waves_remaining(), tod, GameSettings.PRESET_NAMES[GameSettings.preset],
		" HDR" if GameSettings.hdr_output else "", Engine.get_frames_per_second()]
	_top.draw_string(UI.text_font(), Vector2(s.x - 616, y), info, HORIZONTAL_ALIGNMENT_RIGHT, 600, 14, UI.DIM)


func _draw_overlay() -> void:
	var cam := rig.camera
	var now := Time.get_ticks_msec() / 1000.0
	for t in 2:
		for u: Unit in battlefield.units[t]:
			if not is_instance_valid(u) or not u.is_alive() or cam.is_position_behind(u.global_position):
				continue
			var show_bar := u.selected or u == selection.hovered or now - u.last_hit_time < 3.0
			if not show_bar:
				continue
			var p := cam.unproject_position(u.global_position + Vector3.UP * (3.4 if u.def["radius"] > 1.0 else 2.8))
			var w := 44.0 if u.def["radius"] > 1.0 else 26.0
			var frac := clampf(u.hp / u.max_hp, 0.0, 1.0)
			var r := Rect2(p - Vector2(w * 0.5, 0), Vector2(w, 4))
			_overlay.draw_rect(r.grow(1), Color(0, 0, 0, 0.75))
			var col := UI.GOOD if t == 0 else UI.IRAN
			if t == 0 and frac < 0.35:
				col = UI.WARN
			_overlay.draw_rect(Rect2(r.position, Vector2(w * frac, 4)), col)
			var segs := 4 if w < 30.0 else 8
			for k in range(1, segs):
				var sx := r.position.x + w * k / float(segs)
				_overlay.draw_line(Vector2(sx, r.position.y), Vector2(sx, r.end.y), Color(0, 0, 0, 0.6), 1.0)
			if u == selection.hovered:
				_overlay.draw_string(UI.bold_font(), p + Vector2(-60, -7), u.display_name(), HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1, 1, 1, 0.95))
	if selection.dragging:
		var m := _overlay.get_local_mouse_position()
		var rect := Rect2(selection.drag_start, m - selection.drag_start).abs()
		if rect.size.length() > SelectionManager.DRAG_THRESHOLD:
			_overlay.draw_rect(rect, Color(ACCENT, 0.08))
			_overlay.draw_rect(rect, Color(ACCENT, 0.85), false, 1.0)
			var b := minf(12.0, minf(rect.size.x, rect.size.y) * 0.3)
			for c: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
				var sx := 1.0 if c.x == rect.position.x else -1.0
				var sy := 1.0 if c.y == rect.position.y else -1.0
				_overlay.draw_line(c, c + Vector2(b * sx, 0), ACCENT, 2.5)
				_overlay.draw_line(c, c + Vector2(0, b * sy), ACCENT, 2.5)
	if economy != null:
		_draw_derricks(cam)
	if selection.strike_armed or selection.airstrike_armed or selection.attack_move_armed or selection.patrol_armed or selection.rally_armed:
		var m := _overlay.get_local_mouse_position()
		var c := WARN if selection.strike_armed or selection.airstrike_armed else Color(1.0, 0.85, 0.4)
		if selection.strike_armed or selection.airstrike_armed:
			_draw_footprint(cam, m, 10.0 if selection.strike_armed else 7.0, selection.airstrike_armed)
		var spin := now * 1.5
		for k in 4:
			var a := spin + k * PI * 0.5
			_overlay.draw_arc(m, 18, a, a + 0.9, 10, c, 2.0, true)
		_overlay.draw_line(m - Vector2(28, 0), m - Vector2(10, 0), c, 1.5)
		_overlay.draw_line(m + Vector2(10, 0), m + Vector2(28, 0), c, 1.5)
		_overlay.draw_line(m - Vector2(0, 28), m - Vector2(0, 10), c, 1.5)
		_overlay.draw_line(m + Vector2(0, 10), m + Vector2(0, 28), c, 1.5)
		var label := "STRIKE" if selection.strike_armed else ("AIRSTRIKE" if selection.airstrike_armed else ("RALLY" if selection.rally_armed else ("PATROL" if selection.patrol_armed else "ATTACK")))
		_overlay.draw_string(UI.header_font(), m + Vector2(24, 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)


## Capture bar and holder colour over each oil derrick.
func _draw_derricks(cam: Camera3D) -> void:
	for i in economy.derricks.size():
		var d: Dictionary = economy.derricks[i]
		if not d["prop"]["alive"]:
			continue
		var wp: Vector3 = economy.derrick_position(i) + Vector3.UP * 7.0
		if cam.is_position_behind(wp):
			continue
		var p := cam.unproject_position(wp)
		var holder: int = d["owner"]
		var col := UI.GOOD if holder == 0 else (UI.IRAN if holder == 1 else UI.WARN)
		var r := Rect2(p - Vector2(26, 0), Vector2(52, 5))
		_overlay.draw_rect(r.grow(1), Color(0, 0, 0, 0.75))
		var cap: float = d["capture"]
		if cap > 0.0:
			_overlay.draw_rect(Rect2(r.position + Vector2(26, 0), Vector2(26 * cap, 5)), UI.GOOD)
		elif cap < 0.0:
			_overlay.draw_rect(Rect2(r.position + Vector2(26 + 26 * cap, 0), Vector2(-26 * cap, 5)), UI.IRAN)
		_overlay.draw_line(r.position + Vector2(26, -2), r.position + Vector2(26, 7), Color(1, 1, 1, 0.6), 1.0)
		var dia := PackedVector2Array([p + Vector2(0, -20), p + Vector2(7, -13), p + Vector2(0, -6), p + Vector2(-7, -13)])
		_overlay.draw_colored_polygon(dia, Color(col, 0.9))
		_overlay.draw_string(UI.header_font(), p + Vector2(10, -8), "OIL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


## The ground a commander power will hit, so friendly troops in it are seen:
## a ring for the strike, a bomb line across the screen for the airstrike.
func _draw_footprint(cam: Camera3D, mouse: Vector2, radius: float, line: bool) -> void:
	var g := selection.ground_point(mouse)
	if g == Vector3.INF:
		return
	var col := Color(UI.DANGER, 0.85)
	if line:
		var side := cam.global_basis.x
		side.y = 0.0
		side = side.normalized()
		for k in 6:
			var c := g + side * (k - 2.5) * Airstrike.SPACING
			_ring(cam, c, radius, col)
		return
	_ring(cam, g, radius, col)


func _ring(cam: Camera3D, c: Vector3, radius: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 33:
		var a := TAU * k / 32.0
		var w := c + Vector3(cos(a), 0, sin(a)) * radius
		w.y = battlefield.terrain.height_at(w) + 0.2
		if cam.is_position_behind(w):
			return
		pts.append(cam.unproject_position(w))
	_overlay.draw_polyline(pts, col, 1.5, true)
	var fill := pts.duplicate()
	fill.remove_at(fill.size() - 1)
	_overlay.draw_colored_polygon(fill, Color(col, 0.08))
