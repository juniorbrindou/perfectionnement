class_name UiTheme
extends RefCounted
## Thème « parchemin et or » et petites fabriques de widgets.

const NIGHT := Color("1c1410")
const WOOD := Color("4a2f1b")
const PARCHMENT := Color("f3e7c9")
const INK := Color("2b1d0e")
const GOLD := Color("d4af37")
const WINE := Color("7a1f1f")
const GREEN := Color("2e7d32")
const RED := Color("b23a3a")
const MUTED := Color("a8987a")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0,
		radius: int = 18, margin_h: int = 20, margin_v: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 30

	t.set_stylebox("normal", "Button", _box(WINE, GOLD, 3))
	t.set_stylebox("hover", "Button", _box(WINE.lightened(0.12), GOLD, 3))
	t.set_stylebox("pressed", "Button", _box(GOLD, GOLD.lightened(0.3), 3))
	t.set_stylebox("hover_pressed", "Button", _box(GOLD, GOLD.lightened(0.3), 3))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", _box(Color("4b4038"), Color("6b5d50"), 3))
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(state, "Button", PARCHMENT)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", MUTED)

	# Proposition de réponse : bouton clair sur panneau parchemin.
	t.set_type_variation("ChoiceButton", "Button")
	t.set_stylebox("normal", "ChoiceButton", _box(Color("fffaf0"), GOLD, 3, 14, 18, 16))
	t.set_stylebox("hover", "ChoiceButton", _box(Color("fff3d6"), GOLD, 3, 14, 18, 16))
	t.set_stylebox("pressed", "ChoiceButton", _box(Color("f0dca8"), GOLD, 3, 14, 18, 16))
	t.set_stylebox("disabled", "ChoiceButton", _box(Color("e9dfc8"), Color("c8b48a"), 3, 14, 18, 16))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		t.set_color(state, "ChoiceButton", INK)

	t.set_color("font_color", "Label", PARCHMENT)
	t.set_type_variation("InkLabel", "Label")
	t.set_color("font_color", "InkLabel", INK)

	t.set_stylebox("panel", "PanelContainer", _box(PARCHMENT, GOLD, 4, 24, 28, 24))
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", _box(Color(NIGHT, 0.92), GOLD, 3, 20, 20, 14))

	t.set_stylebox("normal", "LineEdit", _box(Color("fffaf0"), GOLD, 3, 12, 16, 12))
	t.set_stylebox("focus", "LineEdit", _box(Color("fffaf0"), WINE, 3, 12, 16, 12))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)

	t.set_stylebox("background", "ProgressBar", _box(Color(0, 0, 0, 0.45), Color.TRANSPARENT, 0, 8, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _box(GOLD, Color.TRANSPARENT, 0, 8, 0, 0))

	t.set_color("font_color", "CheckBox", PARCHMENT)
	t.set_color("font_hover_color", "CheckBox", GOLD)
	t.set_color("font_pressed_color", "CheckBox", GOLD)
	t.set_color("font_hover_pressed_color", "CheckBox", GOLD)
	t.set_color("font_focus_color", "CheckBox", PARCHMENT)
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	return t


static func label(text: String, size: int = 30, ink: bool = false,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if ink:
		l.theme_type_variation = "InkLabel"
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, on_pressed: Callable, size: int = 30) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 84)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(on_pressed)
	return b


static func choice_button(text: String, on_pressed: Callable, size: int = 28) -> Button:
	var b := button(text, on_pressed, size)
	b.theme_type_variation = "ChoiceButton"
	b.custom_minimum_size = Vector2(0, 76)
	return b


## Colore un bouton de proposition (vert = bonne, rouge = choisie et fausse).
static func tint_choice(b: Button, color: Color) -> void:
	var s := _box(color, color.darkened(0.3), 3, 14, 18, 16)
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, s)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(state, Color.WHITE)


static func vbox(separation: int = 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func hbox(separation: int = 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


## Fond plein écran pour les écrans de menu.
static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


## Illustration provisoire d'un récit : un aplat coloré et son titre.
static func illustration_placeholder(story_id: String, title: String) -> Control:
	var panel := PanelContainer.new()
	var hue := float(abs(story_id.hash()) % 360) / 360.0
	panel.add_theme_stylebox_override("panel", _box(Color.from_hsv(hue, 0.35, 0.45), GOLD, 3, 16, 16, 16))
	panel.custom_minimum_size = Vector2(0, 220)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(label(title, 32))
	var hint := label("Illustration à venir", 20)
	hint.modulate = Color(1, 1, 1, 0.7)
	v.add_child(hint)
	panel.add_child(v)
	return panel
