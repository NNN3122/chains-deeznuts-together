class_name UiTheme
extends RefCounted
## The UI look: caution-yellow on black, chunky condensed headings, built in code (no assets).
## Fonts come from the system (Impact / Arial Black on Windows) with sane fallbacks.

const YELLOW: Color = Color(0.98, 0.8, 0.18)
const YELLOW_DIM: Color = Color(0.75, 0.6, 0.15)
const INK: Color = Color(0.05, 0.045, 0.03)
const PAPER: Color = Color(0.95, 0.9, 0.75)
const DANGER: Color = Color(1.0, 0.25, 0.2)

static var _theme: Theme
static var _title: Font
static var _body: Font


static func title_font() -> Font:
	if _title == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Impact", "Haettenschweiler", "Arial Black", "DejaVu Sans"])
		f.font_weight = 800
		_title = f
	return _title


static func body_font() -> Font:
	if _body == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "Arial", "DejaVu Sans"])
		f.font_weight = 600
		_body = f
	return _body


static func panel_style(alpha: float = 0.88) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.025, alpha)
	sb.border_color = YELLOW
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	return sb


## The in-game HUD's frames: mostly see-through, a thin dim edge, tight margins. Menus keep
## panel_style; what sits over the game should barely be there.
static func hud_panel(alpha: float = 0.28) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.025, 0.02, alpha)
	sb.border_color = Color(YELLOW_DIM, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	return sb


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 18
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.06, 0.035, 0.92)
	normal.border_color = YELLOW_DIM
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.17, 0.04, 0.95)
	hover.border_color = YELLOW
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = YELLOW
	pressed.border_color = YELLOW
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("focus", cls, hover)
		t.set_stylebox("disabled", cls, normal)
		t.set_font("font", cls, title_font())
		t.set_font_size("font_size", cls, 24)
		t.set_color("font_color", cls, PAPER)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, INK)
	t.set_color("font_color", "Label", PAPER)
	var edit := normal.duplicate() as StyleBoxFlat
	edit.bg_color = Color(0.02, 0.02, 0.015, 0.95)
	edit.content_margin_left = 10
	edit.content_margin_right = 10
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", hover)
	t.set_color("font_color", "LineEdit", Color.WHITE)
	t.set_font_size("font_size", "LineEdit", 20)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_color("font_color", "CheckBox", PAPER)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_font_size("font_size", "CheckBox", 18)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = YELLOW
	grabber.set_corner_radius_all(3)
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(0.2, 0.18, 0.12)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", grabber)
	t.set_stylebox("grabber_area_highlight", "HSlider", grabber)
	_theme = t
	return t


static func heading(text: String, size: int, color: Color = YELLOW) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(4, size / 10))
	return l


static func text(t: String, size: int = 18, color: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


static func button(t: String, callback: Callable, min_width: float = 320.0) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(min_width, 44.0)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(callback)
	b.pressed.connect(func() -> void:
		if b.is_inside_tree():
			Sfx.play(b, "click", -6.0, 0.8))
	return b
