class_name Painted
extends RefCounted
## Écran peint (images de ChatGPT, assets/duel/) : l'image porte le décor et les boutons,
## le code pose par-dessus ce qui change (textes, code, minuteur) et rend les boutons
## touchables, comme l'accueil (main_menu.gd). Les rectangles sont en pixels de l'image.
##
## L'image est ajustée à la hauteur de l'écran et centrée ; les bandes laissées sur les
## côtés reprennent l'image, agrandie et assombrie.

const P := preload("res://scripts/ui/ui_theme.gd")
const BEZEL := 3.0  ## Liseré du cadre de téléphone autour de chaque écran peint.

const NAVY := Color("0a1f5b")
const NAVY_DEEP := Color("061a4d")
const PILL := Color("172753")
const PARCHMENT := Color("fddc9c")
const SLOT := Color("fbe6bd")
const INK := Color("3a2412")
const BROWN := Color("612c06")
const GOLD := Color("ffc93c")
const GOLD_TEXT := Color("ffd76a")

var s := 1.0  ## Échelle image → écran.
var origin := Vector2.ZERO
var region := Rect2()
var parent: Control


## top : haut de la place laissée à l'image (sous la barre du haut).
static func cover(host: Control, texture: Texture2D, top: float = 0.0) -> Painted:
	var p := Painted.new()
	p.parent = host
	var screen := host.get_viewport_rect().size
	var full := Vector2(texture.get_width(), texture.get_height())
	p.region = Rect2(Vector2(BEZEL, BEZEL), full - Vector2(BEZEL, BEZEL) * 2)
	var avail := screen.y - top
	p.s = avail / p.region.size.y
	if p.region.size.x * p.s > screen.x:
		p.s = screen.x / p.region.size.x
	var size := p.region.size * p.s
	p.origin = Vector2((screen.x - size.x) / 2, top + maxf(0, avail - size.y))
	var back := TextureRect.new()
	back.texture = texture
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.modulate = Color(0.5, 0.52, 0.62)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(back)
	var art := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = p.region
	art.texture = atlas
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.position = p.origin
	art.size = size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(art)
	return p


## Rectangle de l'image → rectangle de l'écran.
func r(img: Rect2) -> Rect2:
	return Rect2(origin + (img.position - region.position) * s, img.size * s)


func place(c: Control, img: Rect2, into: Control = null) -> Control:
	var rr := r(img)
	c.position = rr.position
	c.size = rr.size
	(into if into else parent).add_child(c)
	return c


## Pièce unie qui cache un texte de l'image.
func patch(color: Color, img: Rect2, radius_img: float = 6, into: Control = null) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", P.box(color, int(radius_img * s)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(p, img, into)
	return p


## Texte dont la taille est donnée en pixels de l'image.
func text(value: String, img_px: float, color: Color, img: Rect2, title: bool = true,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, into: Control = null) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_override("font", P.TITLE_FONT if title else P.body_font(900))
	l.add_theme_font_size_override("font_size", int(img_px * s))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(l, img, into)
	return l


## Zone touchable invisible sur un bouton de l'image ; elle s'enfonce un peu quand on la touche.
func tap(img: Rect2, action: Callable, into: Control = null) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var press := StyleBoxFlat.new()
	press.bg_color = Color(0, 0, 0, 0.18)
	press.set_corner_radius_all(int(img.size.y * s / 2))
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("hover_pressed", press)
	b.pressed.connect(action)
	place(b, img, into)
	return b


## Bouton doré dessiné (pour les actions qui ne sont pas dans l'image).
static func gold_button(label: String, action: Callable, height: float, font_px: float) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_override("font", P.TITLE_FONT)
	b.add_theme_font_size_override("font_size", int(font_px))
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var st := P.box(Color("f7b733") if state.begins_with("pressed") or state == "hover_pressed" else Color("fcc444"), int(height / 2), int(height / 3), 0)
		st.border_color = Color("b9741a")
		st.border_width_bottom = int(height / 12) if not state.contains("pressed") else int(height / 30)
		st.shadow_color = Color(0, 0, 0, 0.35)
		st.shadow_size = int(height / 10)
		st.shadow_offset = Vector2(0, height / 14)
		b.add_theme_stylebox_override(state, st)
	var off := P.box(Color(0.3, 0.32, 0.4, 0.8), int(height / 2))
	b.add_theme_stylebox_override("disabled", off)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, Color("2a1a05"))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	b.pressed.connect(action)
	return b


## Bouton bleu nuit bordé d'or, comme « Annuler » dans les images.
static func navy_button(label: String, action: Callable, height: float, font_px: float) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_override("font", P.TITLE_FONT)
	b.add_theme_font_size_override("font_size", int(font_px))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var st := P.box(Color("0b1f55") if not state.contains("pressed") else Color("152f72"), int(height / 2), int(height / 3), 0)
		st.border_color = Color("c99a3c")
		st.set_border_width_all(maxi(2, int(height / 30)))
		b.add_theme_stylebox_override(state, st)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	b.pressed.connect(action)
	return b
