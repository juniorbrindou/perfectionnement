class_name Glass
extends RefCounted
## Style « verre » des écrans de duel en ligne (maquettes validées le 2026-11-23, toile
## « Perfectionnement — accueil », rangée « Duels en ligne ») : paysage de l'accueil flouté
## en fond, panneaux bleu nuit translucides, boutons dorés.

const P := preload("res://scripts/ui/ui_theme.gd")
const BACKGROUND := preload("res://assets/duel/fond_flou.png")
const COINS := preload("res://assets/duel/pieces.png")
const CROWN := preload("res://assets/duel/couronne.png")
const SCRIBE := preload("res://assets/duel/scribe.png")

const PANEL := Color(0.063, 0.125, 0.282, 0.86)
const PANEL_DARK := Color(0.047, 0.094, 0.204, 0.75)
const DEEP := Color("0e1a38")
const EDGE := Color(1, 1, 1, 0.16)
const SOFT := Color("b9c7ea")
const PALE := Color("d8e3ff")
const GOLD := Color("ffd76a")
const RING := Color("ffc84a")
const WIN := Color("5fe39a")
const ALERT := Color("ff6b6b")
const ME := Color("1fa9a3")
const FOE := Color("7a52e0")


## Paysage flouté qui couvre l'écran, assombri vers le bas.
static func background(parent: Control, darkness: float = 0.5) -> void:
	var bg := ColorRect.new()
	bg.color = Color("14213d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var art := TextureRect.new()
	art.texture = BACKGROUND
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.modulate = Color(darkness + 0.05, darkness + 0.05, darkness + 0.1)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	var g := Gradient.new()
	g.set_color(0, Color(0.04, 0.08, 0.18, 0.1))
	g.set_color(1, Color(0.04, 0.08, 0.18, 0.8))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	var shade := TextureRect.new()
	shade.texture = tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)


static func panel_style(fill: Color = PANEL, radius: float = 20, edge: Color = EDGE, pad_h: float = 14, pad_v: float = 12) -> StyleBoxFlat:
	var s := P.box(fill, P.px(radius), P.px(pad_h), P.px(pad_v))
	s.border_color = edge
	s.set_border_width_all(maxi(1, P.px(1)))
	return s


static func panel(fill: Color = PANEL, radius: float = 20, edge: Color = EDGE, pad_h: float = 14, pad_v: float = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(fill, radius, edge, pad_h, pad_v))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Bouton translucide (action secondaire).
static func button(text: String, on_pressed: Callable, size: float = 16, height: float = 54) -> Button:
	var b := P.button(text, on_pressed, size)
	b.custom_minimum_size = Vector2(0, P.px(height))
	b.add_theme_font_override("font", P.body_font(900))
	for state in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(state, panel_style(PANEL_DARK, 18, Color(1, 1, 1, 0.28), 12, 8))
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, panel_style(Color(0.1, 0.17, 0.36, 0.9), 18, Color(1, 1, 1, 0.45), 12, 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, P.CREAM)
	b.add_theme_color_override("font_disabled_color", Color(SOFT, 0.5))
	return b


## Bouton doré (action principale) : celui du thème, à la taille des maquettes.
static func gold_button(text: String, on_pressed: Callable, size: float = 22, height: float = 64) -> Button:
	var b := P.button(text, on_pressed, size)
	b.custom_minimum_size = Vector2(0, P.px(height))
	return b


## Petite image (pièces, couronne) à la taille voulue (unités de maquette).
static func icon(texture: Texture2D, width: float, height: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(P.px(width), P.px(height))
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Pastille « Manne, mise de 20 » avec le point de couleur de la difficulté.
static func chip(text: String, dot: Color, coins: bool = false) -> PanelContainer:
	var p := panel(PANEL_DARK, 999, Color(1, 1, 1, 0.18), 12, 4)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := P.hbox(6)
	p.add_child(row)
	var d := P.circle(dot, 9)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(d)
	var l := P.label(text, 13, PALE, 900)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	if coins:
		row.add_child(icon(COINS, 16, 14))
	return p


## Talents du joueur, en haut à droite.
static func talents_pill(amount: int) -> PanelContainer:
	var p := panel(PANEL_DARK, 999, Color(1, 0.78, 0.29, 0.5), 10, 4)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := P.hbox(5)
	p.add_child(row)
	row.add_child(icon(COINS, 20, 17))
	var l := P.label(str(amount), 15, GOLD, 900)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	return p


## Pastille ronde avec l'initiale, bordée d'or.
static func avatar(player_name: String, color: Color, diameter: float, border: Color = RING) -> Panel:
	var c := P.circle(color, diameter, border, maxf(2.5, diameter / 22.0))
	var l := P.title(player_name.substr(0, 1).to_upper() if not player_name.is_empty() else "?", diameter * 0.45)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	return c


## Portrait du Scribe (image de l'accueil), rond.
static func scribe_portrait(diameter: float) -> Control:
	var ring := P.circle(RING, diameter)
	var mask := Panel.new()
	mask.add_theme_stylebox_override("panel", P.box(Color.WHITE, P.px(diameter)))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset := P.px(2.5)
	mask.offset_left = inset
	mask.offset_top = inset
	mask.offset_right = -inset
	mask.offset_bottom = -inset
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(mask)
	var t := TextureRect.new()
	t.texture = SCRIBE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(t)
	return ring


## Bouton rond « retour ».
static func back_button(on_pressed: Callable) -> Button:
	var b := button("‹", on_pressed, 26, 44)
	b.custom_minimum_size = Vector2(P.px(44), P.px(44))
	b.add_theme_font_override("font", P.TITLE_FONT)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var s := panel_style(PANEL_DARK, 999, Color(1, 1, 1, 0.2), 0, 0)
		b.add_theme_stylebox_override(state, s)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Message bref au milieu de l'écran.
static func toast(parent: Control, text: String) -> void:
	var box := panel(Color(0.05, 0.09, 0.2, 0.95), 18, RING, 18, 12)
	box.anchor_left = 0.08
	box.anchor_right = 0.92
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.z_index = 20
	box.add_child(P.label(text, 16, P.CREAM, 800))
	parent.add_child(box)
	var t := box.create_tween()
	t.tween_interval(2.2)
	t.tween_property(box, "modulate:a", 0.0, 0.4)
	t.tween_callback(box.queue_free)


## Libellé d'une difficulté et sa couleur.
static func difficulty_name(d: String) -> String:
	return CardData.DIFFICULTY_LABELS.get(d, d)
