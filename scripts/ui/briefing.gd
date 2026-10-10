extends Control
## Mission briefing before play and debrief after it, in the tactical-glass
## style. The briefing pauses the game over the live map: a classified
## header strip, the situation typed out like a field report on the left,
## objectives (diamond = primary, circle = bonus) and field notes on the
## right, then difficulty cards and the Begin button. The debrief shows the
## result, the objective outcomes and the mission statistics.

signal begin(difficulty: int)

const UI := preload("res://scripts/ui/ui_theme.gd")
const DIFFICULTY_NAMES := ["Recruit", "Veteran", "Elite"]
const DIFFICULTY_NOTES := [
	"Smaller, slower enemy waves.",
	"The intended experience.",
	"More defenders, faster and bigger waves, fewer tanks for you.",
]

var _difficulty := 1
var _diff_buttons: Array[Button] = []
var _diff_note: Label
var _panel: PanelContainer
var _box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.02, 0.04, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# Scan lines over the dimmed map, very faint.
	var lines := Control.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.draw.connect(func() -> void:
		var h := lines.size.y
		var y := 0.0
		while y < h:
			lines.draw_line(Vector2(0, y), Vector2(lines.size.x, y), Color(UI.ACCENT, 0.025), 1.0)
			y += 4.0)
	add_child(lines)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	var sb := UI.panel_box(Color(0.02, 0.045, 0.07, 0.94), Color(UI.ACCENT, 0.45), 4)
	sb.set_content_margin_all(28)
	sb.content_margin_left = 32
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(980, 0)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_box)
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.35)


func _label(text: String, size_px: int, color := UI.TEXT, wrap := false, parent: Control = null, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(parent if parent != null else _box).add_child(l)
	return l


func _section(title: String, parent: Control) -> void:
	var head := Control.new()
	head.custom_minimum_size = Vector2(0, 24)
	head.draw.connect(func() -> void: UI.draw_header(head, Vector2.ZERO, head.size.x, title))
	parent.add_child(head)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(150, 38)
	b.pressed.connect(func() -> void: Audio.play_ui("ui_select"))
	return b


## Objective row with the same icons as the in-game tracker.
func _objective(text: String, primary: bool, color: Color, parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(14, 20)
	icon.draw.connect(func() -> void:
		var c := Vector2(7, 11)
		if primary:
			icon.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), color)
		else:
			icon.draw_arc(c, 5, 0, TAU, 16, color, 1.5, true))
	row.add_child(icon)
	var l := _label(text, 16, color, true, row)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)


func _header(kicker: String, title: String, sub: String, title_color := UI.ACCENT) -> void:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 12)
	_box.add_child(strip)
	var tag := _label("  CLASSIFIED  ", 11, Color(0.02, 0.05, 0.08), false, strip, UI.header_font())
	var tag_box := StyleBoxFlat.new()
	tag_box.bg_color = UI.WARN
	tag.add_theme_stylebox_override("normal", tag_box)
	_label(kicker.to_upper(), 12, UI.DIM, false, strip, UI.header_font())
	var t := _label(title, 38, title_color, false, null, UI.header_font())
	t.add_theme_constant_override("outline_size", 0)
	if sub != "":
		_label(sub, 15, UI.DIM, false, null, UI.mono_font())
	_box.add_child(HSeparator.new())


func show_briefing(info: Dictionary, objectives: Array[Dictionary]) -> void:
	get_tree().paused = true
	_header(info.get("subtitle", "Operation briefing"), String(info.get("title", "")),
		"%s   //   %s" % [info.get("place", ""), info.get("time", "")])
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	_box.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(520, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(360, 0)
	cols.add_child(right)

	_section("Situation", left)
	var delay := 0.4
	for para: String in info.get("situation", []):
		var l := _label(para, 17, UI.TEXT, true, left)
		l.visible_ratio = 0.0
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(l, "visible_ratio", 1.0, para.length() / 110.0)
		delay += para.length() / 110.0 + 0.15

	_section("Objectives", right)
	for o in objectives:
		if o["state"] == 0: # hidden until revealed in play
			continue
		_objective(String(o["text"]), o["primary"], UI.TEXT if o["primary"] else UI.DIM, right)
	_label("Further objectives will be revealed in the field.", 13, Color(UI.DIM, 0.8), true, right)
	var tips: Array = info.get("tips", [])
	if not tips.is_empty():
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		right.add_child(spacer)
		_section("Field notes", right)
		for t: String in tips:
			_label("·  " + t, 14, UI.DIM, true, right)

	_box.add_child(HSeparator.new())
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	_box.add_child(bottom)
	var diff := VBoxContainer.new()
	diff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(diff)
	_label("DIFFICULTY", 11, UI.DIM, false, diff, UI.header_font())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	diff.add_child(row)
	for i in 3:
		var b := _button(DIFFICULTY_NAMES[i])
		b.toggle_mode = true
		b.button_pressed = i == _difficulty
		b.custom_minimum_size = Vector2(120, 36)
		b.pressed.connect(_pick.bind(i))
		row.add_child(b)
		_diff_buttons.append(b)
	_diff_note = _label(DIFFICULTY_NOTES[_difficulty], 14, UI.DIM, false, diff)
	var go := _button("BEGIN OPERATION  (ENTER)")
	go.add_theme_font_override("font", UI.header_font())
	go.custom_minimum_size = Vector2(280, 52)
	go.size_flags_vertical = Control.SIZE_SHRINK_END
	var go_box := UI.panel_box(Color(UI.ACCENT, 0.18), UI.ACCENT, 4)
	go.add_theme_stylebox_override("normal", go_box)
	var go_hover := UI.panel_box(Color(UI.ACCENT, 0.32), UI.ACCENT, 4)
	go.add_theme_stylebox_override("hover", go_hover)
	go.pressed.connect(_begin)
	bottom.add_child(go)


func _pick(i: int) -> void:
	_difficulty = i
	for k in _diff_buttons.size():
		_diff_buttons[k].button_pressed = k == i
	_diff_note.text = DIFFICULTY_NOTES[i]


func _begin() -> void:
	get_tree().paused = false
	begin.emit(_difficulty)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER) and not _diff_buttons.is_empty():
		get_viewport().set_input_as_handled()
		_diff_buttons.clear()
		_begin()


func show_debrief(won: bool, summary: String, objectives: Array[Dictionary]) -> void:
	_header("After-action report", "MISSION ACCOMPLISHED" if won else "MISSION FAILED", "", UI.GOOD if won else UI.DANGER)
	_label(summary, 17, UI.TEXT, true)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_box.add_child(spacer)
	_section("Objectives", _box)
	for o in objectives:
		if o["state"] == 0:
			continue
		var col: Color = [UI.TEXT, UI.DIM, UI.GOOD, UI.DANGER][o["state"]]
		var mark: String = ["", "", "  (done)", "  (failed)"][o["state"]]
		_objective(String(o["text"]) + mark, o["primary"], col, _box)
	_box.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	var stay := _button("Keep playing")
	stay.pressed.connect(queue_free)
	var again := _button("Play again  (F6)")
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	row.add_child(stay)
	row.add_child(again)
	_box.add_child(row)
