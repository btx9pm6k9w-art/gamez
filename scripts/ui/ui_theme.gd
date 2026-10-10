extends RefCounted
## The game's UI look in one place: a "tactical glass" style of dark
## translucent panels, a thin cyan edge, a solid accent bar on the left of
## headers and buttons, Rajdhani for text and Share Tech Mono for numbers.
## Applied to the root window, so every Control (HUD, sidebar, briefing,
## menu, tooltips) inherits it. See docs/DESIGN.md, "Art and UI direction".

const ACCENT := Color(0.31, 0.85, 1.0)
const ACCENT_DIM := Color(0.31, 0.85, 1.0, 0.35)
const WARN := Color(1.0, 0.7, 0.24)
const DANGER := Color(1.0, 0.35, 0.28)
const GOOD := Color(0.4, 1.0, 0.55)
const TEXT := Color(0.9, 0.95, 0.98)
const DIM := Color(0.58, 0.66, 0.72)
const PANEL := Color(0.02, 0.05, 0.08, 0.8)
const PANEL_SOLID := Color(0.03, 0.06, 0.09, 0.95)
const COALITION := Color(0.35, 0.7, 1.0)
const IRAN := Color(1.0, 0.38, 0.3)

const FONT_TEXT := "res://assets/fonts/Rajdhani-SemiBold.ttf"
const FONT_BOLD := "res://assets/fonts/Rajdhani-Bold.ttf"
const FONT_MONO := "res://assets/fonts/ShareTechMono-Regular.ttf"

static var _fonts := {}
static var _theme: Theme


## Loads a font, imported or not, falling back to the engine font.
static func font(path: String) -> Font:
	if _fonts.has(path):
		return _fonts[path]
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path) as Font
	if f == null and FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(path) == OK:
			f = ff
	if f == null:
		f = ThemeDB.fallback_font
	elif f is FontFile:
		(f as FontFile).fallbacks = [ThemeDB.fallback_font]
	_fonts[path] = f
	return f


static func text_font() -> Font:
	return font(FONT_TEXT)


static func bold_font() -> Font:
	return font(FONT_BOLD)


static func mono_font() -> Font:
	return font(FONT_MONO)


static func panel_box(bg := PANEL, edge := ACCENT_DIM, accent_left := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.border_width_left = maxi(1, accent_left)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 12 + accent_left
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	return sb


static func build() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = text_font()
	t.default_font_size = 16

	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))

	# Buttons: dark slab, accent bar on the left, glows on hover.
	var normal := panel_box(Color(0.05, 0.09, 0.13, 0.85), Color(ACCENT, 0.18), 3)
	normal.border_color = Color(ACCENT, 0.18)
	var hover := panel_box(Color(0.07, 0.16, 0.22, 0.95), Color(ACCENT, 0.7), 3)
	var pressed := panel_box(Color(0.1, 0.3, 0.4, 0.95), ACCENT, 3)
	var disabled := panel_box(Color(0.04, 0.06, 0.08, 0.6), Color(1, 1, 1, 0.06), 3)
	for sb: StyleBoxFlat in [normal, hover, pressed, disabled]:
		sb.shadow_size = 0
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	t.set_font("font", "Button", bold_font())

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.5)
	bar_bg.set_corner_radius_all(1)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = ACCENT
	bar_fill.set_corner_radius_all(1)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)

	var sep := StyleBoxLine.new()
	sep.color = Color(ACCENT, 0.25)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 12)

	var tip := panel_box(PANEL_SOLID, ACCENT_DIM, 3)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 14)

	_theme = t
	return t


## Draws a small panel header: accent tick, spaced caps title, thin rule.
static func draw_header(ci: CanvasItem, pos: Vector2, width: float, title: String) -> void:
	ci.draw_rect(Rect2(pos + Vector2(0, 3), Vector2(3, 12)), ACCENT)
	ci.draw_string(header_font(), pos + Vector2(10, 14), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ACCENT)
	ci.draw_line(pos + Vector2(0, 21), pos + Vector2(width, 21), Color(ACCENT, 0.2), 1.0)


## Bold caps with wide letter spacing for panel titles.
static func header_font() -> Font:
	if _fonts.has("header"):
		return _fonts["header"]
	var fv := FontVariation.new()
	fv.base_font = bold_font()
	fv.spacing_glyph = 2
	_fonts["header"] = fv
	return fv
