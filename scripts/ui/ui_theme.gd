class_name UiTheme
extends RefCounted
## Identité visuelle : les couleurs du tabernacle (Exode 26:1) — fin lin, bleu,
## pourpre et cramoisi — sur la nuit du désert, avec l'or de l'arche.
## Typographies SIL : Gentium Book Plus pour le texte biblique, Andika pour l'interface.

const NIGHT := Color("10173a")      ## Nuit bleue du désert : fond.
const NIGHT_SOFT := Color("1b2552")
const TEKHELET := Color("2f4796")   ## Bleu.
const POURPRE := Color("6e2559")    ## Pourpre.
const CRAMOISI := Color("b3262f")   ## Cramoisi.
const LIN := Color("ece5d3")        ## Fin lin.
const LIN_DIM := Color("aaa38f")
const INK := Color("1d1a2c")        ## Encre bleu-noir sur le lin.
const OR := Color("c9a23f")
const ACACIA := Color("5a3a22")
const OLIVE := Color("4f6b2c")      ## Bonne réponse.

const DIFFICULTY_COLORS := {"lait": TEKHELET, "manne": POURPRE, "solide": CRAMOISI}

const SCRIPTURE := preload("res://assets/fonts/GentiumBookPlus-Regular.ttf")
const SCRIPTURE_BOLD := preload("res://assets/fonts/GentiumBookPlus-Bold.ttf")
const SCRIPTURE_ITALIC := preload("res://assets/fonts/GentiumBookPlus-Italic.ttf")
const UI := preload("res://assets/fonts/Andika-Regular.ttf")
const UI_BOLD := preload("res://assets/fonts/Andika-Bold.ttf")

static var _theme: Theme
static var _weaves := {}


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func difficulty_color(difficulty: String) -> Color:
	return DIFFICULTY_COLORS.get(difficulty, TEKHELET)


static func box(bg: Color, radius: int = 12, margin_h: int = 20, margin_v: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	s.anti_aliasing = true
	return s


## Bouton « tactile » : une tranche plus sombre en bas qui s'écrase à l'appui.
static func _press_box(bg: Color, pressed: bool) -> StyleBoxFlat:
	var s := box(bg, 12, 22, 14)
	s.border_color = bg.darkened(0.4)
	s.border_width_bottom = 2 if pressed else 6
	if pressed:
		s.content_margin_top = 18
	return s


static func _outline_box(color: Color, fill: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := box(fill, 12, 20, 14)
	s.border_color = color
	s.set_border_width_all(2)
	return s


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = UI
	t.default_font_size = 28

	# Bouton principal : cramoisi.
	t.set_stylebox("normal", "Button", _press_box(CRAMOISI, false))
	t.set_stylebox("hover", "Button", _press_box(CRAMOISI.lightened(0.08), false))
	t.set_stylebox("pressed", "Button", _press_box(CRAMOISI, true))
	t.set_stylebox("hover_pressed", "Button", _press_box(CRAMOISI, true))
	t.set_stylebox("disabled", "Button", _press_box(Color("3a3757"), false))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", UI_BOLD)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", LIN)
	t.set_color("font_disabled_color", "Button", LIN_DIM)

	# Bouton discret : contour de lin.
	t.set_type_variation("GhostButton", "Button")
	for state in ["normal", "hover", "disabled"]:
		t.set_stylebox(state, "GhostButton", _outline_box(Color(LIN, 0.45)))
	t.set_stylebox("pressed", "GhostButton", _outline_box(LIN, Color(LIN, 0.12)))
	t.set_stylebox("hover_pressed", "GhostButton", _outline_box(LIN, Color(LIN, 0.12)))
	t.set_font("font", "GhostButton", UI)

	# Bouton discret sur un panneau de lin : contour d'encre.
	t.set_type_variation("InkGhostButton", "Button")
	for state in ["normal", "hover", "disabled"]:
		t.set_stylebox(state, "InkGhostButton", _outline_box(Color(INK, 0.4)))
	t.set_stylebox("pressed", "InkGhostButton", _outline_box(INK, Color(INK, 0.08)))
	t.set_stylebox("hover_pressed", "InkGhostButton", _outline_box(INK, Color(INK, 0.08)))
	t.set_font("font", "InkGhostButton", UI)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "InkGhostButton", INK)

	# Choix à bascule (difficulté, contenu) : plein lin quand sélectionné.
	t.set_type_variation("ToggleButton", "Button")
	t.set_stylebox("normal", "ToggleButton", _outline_box(Color(LIN, 0.35)))
	t.set_stylebox("hover", "ToggleButton", _outline_box(Color(LIN, 0.6)))
	t.set_stylebox("pressed", "ToggleButton", _outline_box(LIN, LIN))
	t.set_stylebox("hover_pressed", "ToggleButton", _outline_box(LIN, LIN))
	t.set_color("font_pressed_color", "ToggleButton", INK)
	t.set_color("font_hover_pressed_color", "ToggleButton", INK)

	# Proposition de réponse : pièce de lin, texte biblique.
	t.set_type_variation("ChoiceButton", "Button")
	var choice := box(Color("f6f1e4"), 12, 18, 16)
	choice.border_color = Color(TEKHELET, 0.35)
	choice.set_border_width_all(2)
	var choice_down := choice.duplicate()
	choice_down.bg_color = Color("e4dcc6")
	t.set_stylebox("normal", "ChoiceButton", choice)
	t.set_stylebox("hover", "ChoiceButton", choice)
	t.set_stylebox("pressed", "ChoiceButton", choice_down)
	t.set_stylebox("hover_pressed", "ChoiceButton", choice_down)
	t.set_stylebox("disabled", "ChoiceButton", choice)
	t.set_font("font", "ChoiceButton", SCRIPTURE)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		t.set_color(state, "ChoiceButton", INK)

	t.set_color("font_color", "Label", LIN)
	t.set_type_variation("InkLabel", "Label")
	t.set_color("font_color", "InkLabel", INK)
	t.set_type_variation("Scripture", "Label")
	t.set_font("font", "Scripture", SCRIPTURE)
	t.set_color("font_color", "Scripture", INK)
	t.set_type_variation("ScriptureLight", "Label")
	t.set_font("font", "ScriptureLight", SCRIPTURE)
	t.set_color("font_color", "ScriptureLight", LIN)

	# Panneau de lin posé sur la table.
	var linen := box(LIN, 16, 26, 22)
	linen.shadow_color = Color(0, 0, 0, 0.45)
	linen.shadow_size = 18
	linen.shadow_offset = Vector2(0, 6)
	t.set_stylebox("panel", "PanelContainer", linen)
	t.set_type_variation("NightPanel", "PanelContainer")
	t.set_stylebox("panel", "NightPanel", box(Color(NIGHT, 0.88), 14, 18, 12))

	t.set_stylebox("normal", "LineEdit", _outline_box(Color(LIN, 0.45), Color(LIN, 0.06)))
	t.set_stylebox("focus", "LineEdit", _outline_box(OR, Color(LIN, 0.1)))
	t.set_color("font_color", "LineEdit", LIN)
	t.set_color("caret_color", "LineEdit", OR)
	t.set_color("font_placeholder_color", "LineEdit", LIN_DIM)

	t.set_stylebox("background", "ProgressBar", box(Color(LIN, 0.12), 4, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(OR, 4, 0, 0))

	for state in ["font_color", "font_focus_color"]:
		t.set_color(state, "CheckBox", LIN)
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, "CheckBox", OR)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	return t


# ---------------------------------------------------------------- Fabriques

static func label(text: String, size: int = 28, variation: String = "",
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if not variation.is_empty():
		l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Texte biblique (question, réponse, référence) en Gentium.
static func scripture(text: String, size: int = 30, on_linen: bool = true, bold: bool = false,
		italic: bool = false) -> Label:
	var l := label(text, size, "Scripture" if on_linen else "ScriptureLight")
	if bold:
		l.add_theme_font_override("font", SCRIPTURE_BOLD)
	elif italic:
		l.add_theme_font_override("font", SCRIPTURE_ITALIC)
	return l


static func button(text: String, on_pressed: Callable, size: int = 28, variation: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 84)
	if not variation.is_empty():
		b.theme_type_variation = variation
	b.pressed.connect(on_pressed)
	return b


static func choice_button(text: String, on_pressed: Callable, size: int = 28) -> Button:
	var b := button(text, on_pressed, size, "ChoiceButton")
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 74)
	return b


## Colore une proposition après la réponse (olive = bonne, cramoisi = choisie et fausse).
static func tint_choice(b: Button, color: Color) -> void:
	var s := box(color, 12, 18, 16)
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(state, s)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(state, LIN)


## Pastille de difficulté, dans la couleur de sa teinture.
static func difficulty_chip(difficulty: String) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", box(difficulty_color(difficulty), 8, 14, 4))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := label(CardData.DIFFICULTY_LABELS.get(difficulty, difficulty), 20)
	l.add_theme_font_override("font", UI_BOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	chip.add_child(l)
	return chip


## Ligne d'en-tête d'une carte : pastille, catégorie, nombre de choix.
static func card_header(data: CardData, options: int) -> HBoxContainer:
	var h := hbox(12)
	h.add_child(difficulty_chip(data.difficulty))
	var cat := label(data.category_label(), 22, "InkLabel", HORIZONTAL_ALIGNMENT_LEFT)
	cat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cat)
	var n := label("%d choix" % options, 22, "InkLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.modulate = Color(1, 1, 1, 0.7)
	h.add_child(n)
	return h


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


static func spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Fond plein écran : la nuit bleue.
static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


## Bande tissée aux couleurs du tabernacle (bleu, pourpre, cramoisi sur fin lin).
static func weave_band(height: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = weave_texture("bande", 104, 16, true, 0, 2)
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.custom_minimum_size = Vector2(0, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r


## Étoffe tissée procédurale : rayures bleu / pourpre / cramoisi / lin, effet sergé.
## vertical = rayures dans le sens de la hauteur.
static func weave_texture(key: String, w: int, h: int, vertical: bool, border: int = 0,
		scale: int = 1) -> ImageTexture:
	var cache_key := "%s_%d_%d_%s_%d_%d" % [key, w, h, vertical, border, scale]
	if _weaves.has(cache_key):
		return _weaves[cache_key]
	var stripes := [[TEKHELET, 6], [LIN, 2], [POURPRE, 6], [LIN, 2], [CRAMOISI, 6], [LIN, 4]]
	var period := 0
	for s in stripes:
		period += s[1]
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var pos := ((x if vertical else y) / scale) % period
			var color: Color = LIN
			var acc := 0
			for s in stripes:
				acc += s[1]
				if pos < acc:
					color = s[0]
					break
			if border > 0 and (x < border or y < border or x >= w - border or y >= h - border):
				color = NIGHT_SOFT
			elif border > 0 and (x < border + 2 or y < border + 2 or x >= w - border - 2 or y >= h - border - 2):
				color = OR
			var twill := 0.92 if ((x + y) / 2) % 3 == 0 else 1.0
			img.set_pixel(x, y, color * twill)
	var tex := ImageTexture.create_from_image(img)
	_weaves[cache_key] = tex
	return tex


## Illustration provisoire d'un récit : étoffe sombre et titre du récit.
static func illustration_placeholder(story_id: String, title: String) -> Control:
	var panel := PanelContainer.new()
	var hue := float(abs(story_id.hash()) % 360) / 360.0
	panel.add_theme_stylebox_override("panel", box(Color.from_hsv(hue, 0.3, 0.32), 10, 16, 16))
	panel.custom_minimum_size = Vector2(0, 200)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(scripture(title, 30, false, false, true))
	var hint := label("Illustration à venir", 18)
	hint.modulate = Color(1, 1, 1, 0.6)
	v.add_child(hint)
	panel.add_child(v)
	return panel
