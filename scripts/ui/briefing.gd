extends Control
## Mission briefing before play and debrief after it. The briefing pauses the
## game over the live map, types out the situation like a field report, lists
## the objectives and lets the player pick the difficulty. The debrief shows
## the result and the mission statistics.

signal begin(difficulty: int)

const ACCENT := Color(0.3, 0.85, 1.0)
const WARN := Color(1.0, 0.45, 0.25)
const TEXT := Color(0.88, 0.94, 0.98)
const DIM := Color(0.6, 0.66, 0.72)
const DIFFICULTY_NAMES := ["Recruit", "Veteran", "Elite"]
const DIFFICULTY_NOTES := [
	"Smaller, slower enemy waves.",
	"The intended experience.",
	"More defenders, faster and bigger waves, fewer tanks for you.",
]

var _difficulty := 1
var _diff_buttons: Array[Button] = []
var _diff_note: Label
var _box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.02, 0.04, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.06, 0.92)
	sb.border_color = Color(ACCENT, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	panel.add_child(_box)


func _label(text: String, size: int, color := TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(760, 0)
	_box.add_child(l)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.custom_minimum_size = Vector2(150, 36)
	return b


func show_briefing(info: Dictionary, objectives: Array[Dictionary]) -> void:
	get_tree().paused = true
	_label(info.get("subtitle", "").to_upper(), 13, DIM)
	_label(info.get("title", ""), 30, ACCENT)
	_label("%s   |   %s" % [info.get("place", ""), info.get("time", "")], 14, DIM)
	_box.add_child(HSeparator.new())
	var delay := 0.3
	for para: String in info.get("situation", []):
		var l := _label(para, 16, TEXT, true)
		l.visible_ratio = 0.0
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(l, "visible_ratio", 1.0, para.length() / 90.0)
		delay += para.length() / 90.0 + 0.2
	_label("OBJECTIVES", 13, DIM)
	for o in objectives:
		if o["state"] == 0: # hidden until revealed in play
			continue
		_label(("  >  " if o["primary"] else "  +  ") + String(o["text"]), 15, TEXT if o["primary"] else DIM)
	var tips: Array = info.get("tips", [])
	if not tips.is_empty():
		_label("FIELD NOTES", 13, DIM)
		for t: String in tips:
			_label("  " + t, 13, DIM, true)
	_box.add_child(HSeparator.new())
	_label("DIFFICULTY", 13, DIM)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	for i in 3:
		var b := _button(DIFFICULTY_NAMES[i])
		b.toggle_mode = true
		b.button_pressed = i == _difficulty
		b.pressed.connect(_pick.bind(i))
		row.add_child(b)
		_diff_buttons.append(b)
	_diff_note = _label(DIFFICULTY_NOTES[_difficulty], 13, DIM)
	var go := _button("Begin operation  (Enter)")
	go.custom_minimum_size = Vector2(260, 42)
	go.pressed.connect(_begin)
	var go_row := HBoxContainer.new()
	go_row.alignment = BoxContainer.ALIGNMENT_END
	go_row.add_child(go)
	_box.add_child(go_row)


func _pick(i: int) -> void:
	_difficulty = i
	for k in _diff_buttons.size():
		_diff_buttons[k].button_pressed = k == i
	_diff_note.text = DIFFICULTY_NOTES[i]


func _begin() -> void:
	get_tree().paused = false
	begin.emit(_difficulty)
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER) and not _diff_buttons.is_empty():
		get_viewport().set_input_as_handled()
		_begin()


func show_debrief(won: bool, summary: String, objectives: Array[Dictionary]) -> void:
	_label("MISSION ACCOMPLISHED" if won else "MISSION FAILED", 30, ACCENT if won else WARN)
	_label(summary, 15, TEXT, true)
	_box.add_child(HSeparator.new())
	for o in objectives:
		var mark: String = ["", "  -  ", "  OK  ", "  X  "][o["state"]]
		if o["state"] == 0:
			continue
		_label(mark + String(o["text"]), 15, [TEXT, TEXT, ACCENT, WARN][o["state"]])
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
