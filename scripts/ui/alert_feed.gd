extends VBoxContainer
## Event feed on the left edge: short notices (derrick captured, objective
## done, reinforcements, settings) slide in, stack up to five, and fade out.
## The big centre banner in the HUD is kept for the moments that matter.

const UI := preload("res://scripts/ui/ui_theme.gd")
const MAX := 5
const LIFE := 5.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)


func push(text: String, color := UI.ACCENT) -> void:
	var panel := PanelContainer.new()
	var sb := UI.panel_box(Color(0.02, 0.05, 0.08, 0.82), Color(color, 0.35), 3)
	sb.border_color = Color(color, 0.35)
	sb.border_width_left = 3
	sb.shadow_size = 0
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", color.lerp(UI.TEXT, 0.35))
	panel.add_child(l)
	add_child(panel)
	while get_child_count() > MAX:
		var old := get_child(0)
		remove_child(old)
		old.queue_free()
	panel.modulate.a = 0.0
	panel.position.x = -30.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(panel, "position:x", 0.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(LIFE)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)
