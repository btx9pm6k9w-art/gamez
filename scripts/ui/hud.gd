class_name HUD
extends CanvasLayer
## Tactical HUD: top status bar, selection card, minimap, health bars,
## selection box, alerts and the controls overlay. Built in code so the
## layout scales with the window (Retina included).

const ACCENT := Color(0.3, 0.85, 1.0)
const WARN := Color(1.0, 0.45, 0.25)
const PANEL_BG := Color(0.03, 0.05, 0.07, 0.8)

var battlefield: Battlefield
var selection: SelectionManager
var rig: RTSCamera
var ai: SimpleAI

var _overlay: Control
var _status: Label
var _card: Label
var _card_panel: PanelContainer
var _message: Label
var _help: PanelContainer
var _strike: Label
var _minimap: Control
var _minimap_tex: ImageTexture
var _post: ColorRect
var _message_time := 0.0


func _ready() -> void:
	layer = 1
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

	var top := _panel(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	_status = _label(15)
	top.add_child(_status)

	_card_panel = _panel(Control.PRESET_BOTTOM_LEFT)
	_card_panel.offset_left = 16
	_card_panel.offset_bottom = -16
	_card_panel.offset_top = -120
	_card_panel.custom_minimum_size = Vector2(340, 0)
	_card = _label(15)
	_card_panel.add_child(_card)

	var strike_panel := _panel(Control.PRESET_CENTER_BOTTOM)
	strike_panel.offset_bottom = -16
	strike_panel.offset_top = -64
	strike_panel.offset_left = -170
	strike_panel.offset_right = 170
	_strike = _label(16)
	_strike.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strike_panel.add_child(_strike)

	_message = _label(30)
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.offset_top = 90
	_message.offset_left = -500
	_message.offset_right = 500
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_message.add_theme_constant_override("outline_size", 6)
	add_child(_message)

	_help = _panel(Control.PRESET_TOP_LEFT)
	_help.offset_left = 16
	_help.offset_top = 70
	var help := _label(13)
	help.text = "\n".join([
		"LEFT click / drag   select units (shift adds, double-click = all of type)",
		"RIGHT click         move, or attack the enemy under the cursor",
		"R then click        attack-move     X  stop     TAB  select army",
		"Ctrl/Cmd+1..9       set group       1..9  recall (twice = jump)",
		"F then click        Precision Strike (hypersonic, makes a crater)",
		"WASD / edges / pinch / two-finger   pan & zoom     Q E  rotate",
		"T  time of day      F1-F4  graphics preset   F5  HDR   F11  fullscreen",
		"H  hide this help",
	])
	_help.add_child(help)

	var mm_panel := _panel(Control.PRESET_BOTTOM_RIGHT)
	mm_panel.offset_right = -16
	mm_panel.offset_bottom = -16
	mm_panel.offset_left = -236
	mm_panel.offset_top = -236
	_minimap = Control.new()
	_minimap.custom_minimum_size = Vector2(212, 212)
	_minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap.draw.connect(_draw_minimap)
	_minimap.gui_input.connect(_on_minimap_input)
	mm_panel.add_child(_minimap)


func setup(bf: Battlefield, sel: SelectionManager, camera_rig: RTSCamera, p_ai: SimpleAI) -> void:
	battlefield = bf
	selection = sel
	rig = camera_rig
	ai = p_ai
	_minimap_tex = ImageTexture.create_from_image(bf.terrain.build_minimap_image())
	ai.wave_incoming.connect(func(i: int, total: int) -> void: show_message("Enemy wave %d of %d incoming from the mountains" % [i, total], WARN))
	GameSettings.preset_changed.connect(_on_preset_changed)
	_on_preset_changed(GameSettings.preset)


func _on_preset_changed(p: int) -> void:
	_post.visible = p >= GameSettings.Preset.MEDIUM


func _panel(preset: int) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(ACCENT, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	pc.set_anchors_preset(preset)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pc)
	return pc


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.88, 0.94, 0.98))
	return l


func show_message(text: String, color := ACCENT, duration := 4.0) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)
	_message_time = duration
	Audio.play_ui("alert")


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_H:
		_help.visible = not _help.visible


func _process(delta: float) -> void:
	if battlefield == null:
		return
	var tod: String = ["Golden hour", "Midday", "Night"][battlefield.time_of_day]
	var own: int = battlefield.units[Battlefield.COALITION].size()
	var enemy: int = battlefield.units[Battlefield.IRAN].size()
	_status.text = "FRACTURE LINE  |  Strait of Hormuz coast  |  Coalition %d  vs  Iran %d  |  Waves left %d  |  %s  |  %s%s  |  %d fps" % [
		own, enemy, ai.waves_remaining(), tod, GameSettings.PRESET_NAMES[GameSettings.preset],
		"  HDR" if GameSettings.hdr_output else "", Engine.get_frames_per_second()]

	if selection.selected.is_empty():
		_card.text = "No units selected\nDrag a box around your forces to begin."
	else:
		var counts := {}
		var hp := 0.0
		var max_hp := 0.0
		for u in selection.selected:
			counts[u.display_name()] = counts.get(u.display_name(), 0) + 1
			hp += u.hp
			max_hp += u.max_hp
		var lines: Array[String] = []
		for k: String in counts:
			lines.append("%d x %s" % [counts[k], k])
		var faction: String = UnitDefs.FACTION_NAMES[selection.selected[0].faction]
		_card.text = "%s\n%s\nIntegrity %d%%" % [faction, "\n".join(lines), int(100.0 * hp / maxf(max_hp, 1.0))]

	if selection.strike_armed:
		_strike.text = "PRECISION STRIKE: click a target"
		_strike.add_theme_color_override("font_color", WARN)
	elif selection.strike_cooldown > 0.0:
		_strike.text = "Precision Strike  %ds" % ceili(selection.strike_cooldown)
		_strike.add_theme_color_override("font_color", Color(0.6, 0.66, 0.7))
	else:
		_strike.text = "Precision Strike READY  [F]"
		_strike.add_theme_color_override("font_color", ACCENT)

	if _message_time > 0.0:
		_message_time -= delta
		_message.modulate.a = clampf(_message_time, 0.0, 1.0)
	_overlay.queue_redraw()
	_minimap.queue_redraw()


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
			var w := 46.0 if u.def["radius"] > 1.0 else 26.0
			var frac := clampf(u.hp / u.max_hp, 0.0, 1.0)
			var r := Rect2(p - Vector2(w * 0.5, 0), Vector2(w, 5))
			_overlay.draw_rect(r.grow(1), Color(0, 0, 0, 0.7))
			var col := Color(0.3, 1.0, 0.5) if t == 0 else Color(1.0, 0.35, 0.25)
			if frac < 0.35:
				col = Color(1.0, 0.75, 0.2) if t == 0 else col
			_overlay.draw_rect(Rect2(r.position, Vector2(w * frac, 5)), col)
			if u == selection.hovered:
				_overlay.draw_string(ThemeDB.fallback_font, p + Vector2(-w * 0.5, -6), u.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.9))
	if selection.dragging:
		var m := _overlay.get_local_mouse_position()
		var rect := Rect2(selection.drag_start, m - selection.drag_start).abs()
		if rect.size.length() > SelectionManager.DRAG_THRESHOLD:
			_overlay.draw_rect(rect, Color(ACCENT, 0.12))
			_overlay.draw_rect(rect, Color(ACCENT, 0.9), false, 1.5)
	if selection.strike_armed or selection.attack_move_armed:
		var m := _overlay.get_local_mouse_position()
		var c := WARN if selection.strike_armed else Color(1.0, 0.8, 0.3)
		_overlay.draw_arc(m, 16, 0, TAU, 32, c, 2.0)
		_overlay.draw_line(m - Vector2(24, 0), m + Vector2(24, 0), c, 1.5)
		_overlay.draw_line(m - Vector2(0, 24), m + Vector2(0, 24), c, 1.5)


func _draw_minimap() -> void:
	var s := _minimap.size
	var k := s.x / float(Battlefield.MAP_SIZE)
	_minimap.draw_texture_rect(_minimap_tex, Rect2(Vector2.ZERO, s), false)
	for t in 2:
		for u: Unit in battlefield.units[t]:
			if not is_instance_valid(u):
				continue
			var c := Color(0.3, 1.0, 0.6) if t == 0 else Color(1.0, 0.3, 0.25)
			if u.selected:
				c = Color.WHITE
			var p := Vector2(u.global_position.x, u.global_position.z) * k
			_minimap.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)) if not u.is_air else Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), c)
	# Camera footprint.
	var corners: Array[Vector2] = []
	var vs := get_viewport().get_visible_rect().size
	for sp in [Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]:
		var gp := selection.ground_point(sp)
		if gp == Vector3.INF:
			gp = rig.get_focus()
		corners.append(Vector2(gp.x, gp.z) * k)
	corners.append(corners[0])
	_minimap.draw_polyline(PackedVector2Array(corners), Color(1, 1, 1, 0.8), 1.2)
	_minimap.draw_rect(Rect2(Vector2.ZERO, s), Color(ACCENT, 0.5), false, 1.0)


func _on_minimap_input(event: InputEvent) -> void:
	var press := event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	var drag := event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if press or drag:
		var p := (event as InputEventMouse).position / _minimap.size.x * Battlefield.MAP_SIZE
		rig.focus_on(Vector3(p.x, 0, p.y))
