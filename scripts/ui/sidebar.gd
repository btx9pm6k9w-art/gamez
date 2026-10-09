extends PanelContainer
## C&C-style command sidebar on the right: credits and income, one
## production line per category (infantry, vehicles, naval) with a build
## button per unit, queue counts and a progress bar, and a rally point
## button. Left click queues a unit, right click cancels one.

const Economy := preload("res://scripts/game/economy.gd")

const ACCENT := Color(0.3, 0.85, 1.0)
const DIM := Color(0.55, 0.6, 0.65)
const CATEGORY_NAMES := {"infantry": "INFANTRY", "vehicle": "VEHICLES", "naval": "NAVAL"}

var economy: Economy
var selection: SelectionManager

var _credits: Label
var _income: Label
var _buttons := {} # id -> {"button": Button, "bar": ProgressBar}
var _shown_credits := 0.0


func setup(eco: Economy, sel: SelectionManager) -> void:
	economy = eco
	selection = sel
	_shown_credits = eco.credits
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.07, 0.82)
	sb.border_color = Color(ACCENT, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_credits = _label(22, ACCENT)
	box.add_child(_credits)
	_income = _label(12, DIM)
	box.add_child(_income)

	var by_cat := {}
	for id in UnitDefs.buildable("coalition"):
		var cat: String = UnitDefs.get_def(id)["category"]
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append(id)
	for cat: String in Economy.CATEGORIES:
		if not by_cat.has(cat):
			continue
		var head := _label(12, DIM)
		head.text = CATEGORY_NAMES[cat]
		box.add_child(head)
		for id: String in by_cat[cat]:
			var b := Button.new()
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 14)
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(210, 30)
			b.pressed.connect(func() -> void: economy.build(id))
			b.gui_input.connect(func(ev: InputEvent) -> void:
				var mb := ev as InputEventMouseButton
				if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
					economy.cancel(id)
					b.accept_event())
			b.tooltip_text = "%s\nCost %d, build time %d s\nLeft click to build, right click to cancel" % [
				UnitDefs.get_def(id)["display"], UnitDefs.get_def(id)["cost"], int(UnitDefs.get_def(id)["build_time"])]
			box.add_child(b)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(0, 4)
			bar.show_percentage = false
			bar.max_value = 1.0
			bar.step = 0.0
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(bar)
			_buttons[id] = {"button": b, "bar": bar}

	var rally := Button.new()
	rally.text = "Set rally point"
	rally.focus_mode = Control.FOCUS_NONE
	rally.add_theme_font_size_override("font_size", 13)
	rally.tooltip_text = "Then click where new units should gather (click water for boats)"
	rally.pressed.connect(func() -> void: selection.rally_armed = true)
	box.add_child(rally)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _process(delta: float) -> void:
	if economy == null:
		return
	# Credits count up and down like the classic ticker.
	_shown_credits = move_toward(_shown_credits, economy.credits, maxf(absf(economy.credits - _shown_credits) * delta * 6.0, 40.0 * delta))
	_credits.text = "$ %d" % int(_shown_credits)
	var n := economy.owned_derricks()
	_income.text = ("+%d / s from %d oil derrick%s" % [int(economy.income_per_second()), n, "" if n == 1 else "s"]) if n > 0 else "No income: capture the oil derricks"
	for id: String in _buttons:
		var def := UnitDefs.get_def(id)
		var b: Button = _buttons[id]["button"]
		var bar: ProgressBar = _buttons[id]["bar"]
		var q := economy.queued(id)
		var short := String(def["display"]).replace("-class", "").replace(" Air Defence", " AD")
		b.text = "%s   %d%s" % [short, def["cost"], ("   x%d" % q) if q > 0 else ""]
		b.modulate = Color.WHITE if economy.credits >= float(def["cost"]) or q > 0 else Color(1, 1, 1, 0.45)
		bar.value = economy.progress_of(id)
