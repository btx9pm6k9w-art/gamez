extends Control
## Main menu over the live battlefield: the camera slowly circles the
## Strait while the menu sits in a dark glass column on the left, like the
## front ends of C&C Remastered and Tempest Rising. Campaign opens the
## mission briefing; graphics and HDR can be changed here before play.

signal campaign
signal showcase

const UI := preload("res://scripts/ui/ui_theme.gd")

var _graphics: Button
var _hdr: Button


func _ready() -> void:
	# Offsets too: plain set_anchors_preset() keeps the current (empty) size
	# once the node is in the tree.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := Control.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(func() -> void:
		# Dark column on the left fading into the scene, plus a soft bottom vignette.
		var w := shade.size.x
		var h := shade.size.y
		var steps := 24
		for i in steps:
			var t := i / float(steps)
			shade.draw_rect(Rect2(Vector2(w * 0.5 * t, 0), Vector2(w * 0.5 / steps + 1, h)), Color(0.0, 0.02, 0.04, 0.88 * (1.0 - t) * (1.0 - t)))
		for i in 12:
			var t := i / 12.0
			shade.draw_rect(Rect2(Vector2(0, h * (0.8 + 0.2 * t)), Vector2(w, h * 0.2 / 12 + 1)), Color(0, 0.02, 0.04, 0.35 * t)))
	add_child(shade)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 80
	col.offset_right = 520
	col.offset_top = 0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	var kicker := Label.new()
	kicker.text = "STRAIT OF HORMUZ  //  2028"
	kicker.add_theme_font_override("font", UI.header_font())
	kicker.add_theme_font_size_override("font_size", 14)
	kicker.add_theme_color_override("font_color", UI.WARN)
	col.add_child(kicker)
	var title := Label.new()
	title.text = "FRACTURE\nLINE"
	title.add_theme_font_override("font", UI.header_font())
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_constant_override("line_spacing", -22)
	title.add_theme_color_override("font_color", UI.TEXT)
	col.add_child(title)
	var rule := ColorRect.new()
	rule.color = UI.ACCENT
	rule.custom_minimum_size = Vector2(120, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(rule)
	var tag := Label.new()
	tag.text = "Coalition command. Hold the Strait. Find out who is really pulling the strings."
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.add_theme_font_size_override("font_size", 17)
	tag.add_theme_color_override("font_color", UI.TEXT)
	tag.add_theme_constant_override("outline_size", 6)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	col.add_child(gap)

	_add(col, "Campaign", "Mission 1: Beachhead", func() -> void: _leave(campaign), true)
	_add(col, "Unit showcase", "Every unit, up close", func() -> void: _leave(showcase))
	_graphics = _add(col, "", "F1-F4 in game", func() -> void:
		GameSettings.apply_preset((GameSettings.preset + 1) % GameSettings.PRESET_NAMES.size())
		_refresh())
	_hdr = _add(col, "", "XDR / HDR displays", func() -> void:
		GameSettings.set_hdr_output(not GameSettings.hdr_output)
		_refresh())
	_add(col, "Quit", "", func() -> void: get_tree().quit())
	_refresh()

	var foot := Label.new()
	foot.text = "F10 shows every control in game"
	foot.add_theme_font_override("font", UI.mono_font())
	foot.add_theme_font_size_override("font_size", 13)
	foot.add_theme_color_override("font_color", Color(UI.DIM, 0.7))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 80
	foot.offset_top = -48
	add_child(foot)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)


func _add(parent: Control, text: String, hint: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(360, 52 if primary else 44)
	b.add_theme_font_override("font", UI.header_font())
	b.add_theme_font_size_override("font_size", 20 if primary else 16)
	if primary:
		b.add_theme_stylebox_override("normal", UI.panel_box(Color(0.03, 0.16, 0.22, 0.95), UI.ACCENT, 4))
		b.add_theme_stylebox_override("hover", UI.panel_box(Color(0.05, 0.25, 0.33, 0.97), UI.ACCENT, 4))
	else:
		b.add_theme_stylebox_override("normal", UI.panel_box(UI.PANEL_SOLID, UI.ACCENT_DIM, 3))
		b.add_theme_stylebox_override("hover", UI.panel_box(Color(0.06, 0.13, 0.18, 0.97), UI.ACCENT, 3))
	b.tooltip_text = hint
	b.pressed.connect(func() -> void:
		Audio.play_ui("ui_confirm")
		action.call())
	parent.add_child(b)
	return b


func _refresh() -> void:
	_graphics.text = "GRAPHICS:  " + String(GameSettings.PRESET_NAMES[GameSettings.preset]).to_upper()
	_hdr.text = "HDR OUTPUT:  " + ("ON" if GameSettings.hdr_output else "OFF")


func _leave(sig: Signal) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		sig.emit()
		queue_free())
