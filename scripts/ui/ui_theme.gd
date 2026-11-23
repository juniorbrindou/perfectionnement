class_name UiTheme
extends RefCounted
## Identité visuelle validée (maquettes « cartes illustrées ») : violet profond,
## sarcelle, framboise et jaune tournesol ; Lilita One pour les titres et les
## réponses, Nunito pour le texte. Les maquettes sont dessinées sur 390 px de large,
## l'écran du jeu en fait 720 : px() convertit les mesures des maquettes.

const NIGHT := Color("2a1640")
const VIOLET := Color("3b1f6e")
const TEAL := Color("1fb5b0")
const GOLD := Color("f4a62a")
const FRAMBOISE := Color("b8185a")
const YELLOW := Color("ffc93c")
const CREAM := Color("fffdf5")
const LILAC := Color("d9c9f5")
const GREEN := Color("2fbf71")
const EMBER := Color("c4501f")   ## Tranche orangée sous les boutons jaunes.
const LAMP := Color(1.0, 0.69, 0.27)

const DIFFICULTY_COLORS := {"lait": TEAL, "manne": GOLD, "solide": FRAMBOISE}
const SCALE := 720.0 / 390.0

const TITLE_FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const NUNITO := preload("res://assets/fonts/Nunito.ttf")

static var _theme: Theme
static var _fonts := {}


static func px(v: float) -> int:
	return int(round(v * SCALE))


static func difficulty_color(difficulty: String) -> Color:
	return DIFFICULTY_COLORS.get(difficulty, TEAL)


## Bande des réponses : framboise, sauf sur les cartes déjà framboise.
static func answers_color(difficulty: String) -> Color:
	return VIOLET if difficulty == "solide" else FRAMBOISE


static func body_font(weight: int = 800) -> Font:
	if not _fonts.has(weight):
		var f := FontVariation.new()
		f.base_font = NUNITO
		f.variation_opentype = {"wght": weight}
		_fonts[weight] = f
	return _fonts[weight]


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func box(bg: Color, radius: int = 16, margin_h: int = 0, margin_v: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	s.anti_aliasing = true
	return s


static func _yellow(pressed: bool) -> StyleBoxFlat:
	var s := box(YELLOW, px(18), px(16), px(10))
	s.border_color = EMBER
	s.border_width_bottom = px(2) if pressed else px(6)
	if pressed:
		s.content_margin_top = px(14)
	return s


static func _outline(color: Color, fill: Color = Color.TRANSPARENT, radius: int = 16) -> StyleBoxFlat:
	var s := box(fill, px(radius), px(14), px(10))
	s.border_color = color
	s.set_border_width_all(px(3))
	return s


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = body_font(800)
	t.default_font_size = px(15)

	# Bouton principal : jaune tournesol, texte violet.
	t.set_stylebox("normal", "Button", _yellow(false))
	t.set_stylebox("hover", "Button", _yellow(false))
	t.set_stylebox("pressed", "Button", _yellow(true))
	t.set_stylebox("hover_pressed", "Button", _yellow(true))
	t.set_stylebox("disabled", "Button", _outline(Color(LILAC, 0.25), Color(1, 1, 1, 0.06), 18))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", TITLE_FONT)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", NIGHT)
	t.set_color("font_disabled_color", "Button", Color(LILAC, 0.55))

	# Bouton secondaire : contour lilas.
	t.set_type_variation("GhostButton", "Button")
	for state in ["normal", "hover", "disabled"]:
		t.set_stylebox(state, "GhostButton", _outline(Color(LILAC, 0.7)))
	t.set_stylebox("pressed", "GhostButton", _outline(LILAC, Color(1, 1, 1, 0.1)))
	t.set_stylebox("hover_pressed", "GhostButton", _outline(LILAC, Color(1, 1, 1, 0.1)))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "GhostButton", CREAM)

	# Réponse touchée directement sur la carte.
	t.set_type_variation("AnswerButton", "Button")
	t.set_stylebox("normal", "AnswerButton", box(Color(NIGHT, 0.25), px(12)))
	t.set_stylebox("hover", "AnswerButton", box(Color(NIGHT, 0.25), px(12)))
	t.set_stylebox("pressed", "AnswerButton", box(Color(NIGHT, 0.5), px(12)))
	t.set_stylebox("hover_pressed", "AnswerButton", box(Color(NIGHT, 0.5), px(12)))
	t.set_stylebox("disabled", "AnswerButton", box(Color(NIGHT, 0.25), px(12)))

	# Choix à bascule (difficulté, contenu) : plein jaune quand sélectionné.
	t.set_type_variation("ChipToggle", "Button")
	for state in ["normal", "hover"]:
		t.set_stylebox(state, "ChipToggle", _outline(Color(LILAC, 0.35), Color(1, 1, 1, 0.06), 14))
	for state in ["pressed", "hover_pressed"]:
		t.set_stylebox(state, "ChipToggle", _outline(YELLOW, YELLOW, 14))
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(state, "ChipToggle", CREAM)
	t.set_color("font_pressed_color", "ChipToggle", NIGHT)
	t.set_color("font_hover_pressed_color", "ChipToggle", NIGHT)

	t.set_color("font_color", "Label", CREAM)

	t.set_stylebox("normal", "LineEdit", _outline(Color(LILAC, 0.4), Color(1, 1, 1, 0.06), 14))
	t.set_stylebox("focus", "LineEdit", _outline(YELLOW, Color(1, 1, 1, 0.08), 14))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("caret_color", "LineEdit", YELLOW)
	t.set_color("font_placeholder_color", "LineEdit", Color(LILAC, 0.6))
	t.set_font("font", "LineEdit", body_font(800))

	for state in ["font_color", "font_focus_color"]:
		t.set_color(state, "CheckBox", CREAM)
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, "CheckBox", YELLOW)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	return t


# ---------------------------------------------------------------- Fabriques

static func label(text: String, size: float = 15, color: Color = CREAM, weight: int = 800,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", body_font(weight))
	l.add_theme_font_size_override("font_size", px(size))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size: float = 22, color: Color = CREAM,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, size, color, 800, align)
	l.add_theme_font_override("font", TITLE_FONT)
	return l


static func button(text: String, on_pressed: Callable, size: float = 22, variation: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", px(size))
	b.custom_minimum_size = Vector2(0, px(60))
	if not variation.is_empty():
		b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_pressed)
	return b


static func circle(color: Color, diameter: float, border: Color = Color.TRANSPARENT, border_w: float = 0) -> Panel:
	var p := Panel.new()
	var s := box(color, px(diameter))
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(px(border_w))
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(px(diameter), px(diameter))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Pastille ronde avec l'initiale du joueur.
static func avatar(player_name: String, color: Color, diameter: float = 40) -> Control:
	var c := circle(color, diameter, YELLOW, 3)
	var l := title(player_name.substr(0, 1).to_upper(), diameter * 0.5)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	return c


static func vbox(separation: float = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", px(separation))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func hbox(separation: float = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", px(separation))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px(height))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expander() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func margins(left: float, top: float, right: float, bottom: float) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", px(left))
	m.add_theme_constant_override("margin_top", px(top))
	m.add_theme_constant_override("margin_right", px(right))
	m.add_theme_constant_override("margin_bottom", px(bottom))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


## Fond des écrans de jeu : violet profond éclairé par une lampe.
static func night_background(parent: Control, glow_y: float = 0.32) -> void:
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var glow := Shapes.Glow.new()
	glow.center = Vector2(0.5, glow_y)
	glow.color = Color(LAMP, 0.35)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(glow)
