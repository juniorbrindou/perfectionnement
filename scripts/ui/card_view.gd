class_name CardView
extends Control
## La carte à l'écran (maquette B validée le 2026-11-24) : un cadre doré, l'illustration du
## livre en haut avec son nom dans un bandeau, puis un parchemin où sont écrites la question
## et ses réponses. On répond en touchant la carte.
##
## L'illustration vient de assets/illustrations/<livre>.jpg (demandes : docs/IMAGES_LIVRES.md) ;
## tant qu'un livre n'a pas la sienne, la carte montre la Bible lumineuse du dos de carte.
##
## Modes :
##   BACK   dos de carte peint
##   OWNER  vue du propriétaire : la bonne réponse est marquée en vert
##   ANSWER vue de celui qui répond : les réponses sont des boutons → signal answered
##   REVEAL après une bonne réponse : récit, réponse, référence

signal answered(choice: String)

enum Mode { BACK, OWNER, ANSWER, REVEAL }
enum Highlight { NONE, HESITATE, RIGHT, WRONG }

const LETTERS := ["A", "B", "C", "D", "E"]
const BADGE_LABELS := {"lait": "Lait", "manne": "Manne", "solide": "Solide"}

const CARD_BACK := preload("res://assets/duel/dos_carte.png")
const CARD_FACE := preload("res://assets/duel/face_carte.png")
const BOOKS_DIR := "res://assets/illustrations/"

const GOLD := Color("f0c05a")
const GOLD_LIGHT := Color("ffe9a8")
const GOLD_DARK := Color("6b3f10")
const NAVY := Color("13275e")
const INK := Color("4a2a12")  ## Texte sur le parchemin.
const INK_SOFT := Color("7a5a3a")
const PILL := Color("fff1d6")
const PILL_PRESSED := Color("f3dcae")
const PILL_EDGE := Color("d9b77a")
const RIGHT := Color("2fae68")
const WRONG := Color("d9445a")

var mode := Mode.BACK

var _frame: Control
var _body: Panel
var _content: Control
var _overlay: Control
var _sheet: VBoxContainer  ## Colonne du parchemin de la face en cours.
var _answer_buttons := {}  ## texte de la réponse → Button
var _owner_rows := {}  ## texte de la réponse → PanelContainer (vue du propriétaire)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func(): pivot_offset = size / 2)

	# Cadre doré avec son halo, et un filet sombre à l'intérieur.
	_frame = Panel.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := UiTheme.box(GOLD, UiTheme.px(22))
	fs.border_color = GOLD_LIGHT
	fs.set_border_width_all(UiTheme.px(2))
	fs.shadow_color = Color(1.0, 0.84, 0.42, 0.45)
	fs.shadow_size = UiTheme.px(10)
	_frame.add_theme_stylebox_override("panel", fs)
	add_child(_frame)
	var line := Panel.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inset(line, 5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_stylebox_override("panel", UiTheme.box(GOLD_DARK, UiTheme.px(18)))
	_frame.add_child(line)

	_body = Panel.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inset(_body, 7)
	_body.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_stylebox_override("panel", UiTheme.box(NAVY, UiTheme.px(16)))
	add_child(_body)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_content)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	show_back()


# ---------------------------------------------------------------- Illustrations

## Nom de fichier d'un livre : « 1 Samuel » → 1_samuel, « Ézéchiel » → ezechiel.
static func book_slug(book: String) -> String:
	var s := book.to_lower()
	for pair in [["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"], ["à", "a"], ["â", "a"], ["î", "i"],
			["ï", "i"], ["ô", "o"], ["û", "u"], ["ù", "u"], ["ç", "c"], [" ", "_"], ["'", ""]]:
		s = s.replace(pair[0], pair[1])
	return s


## Illustration du livre de la carte, ou la Bible lumineuse du dos de carte en attendant.
static func book_art(data: CardData) -> Texture2D:
	if data != null and not data.books.is_empty():
		var path := BOOKS_DIR + book_slug(data.books[0]) + ".jpg"
		if ResourceLoader.exists(path):
			return load(path)
	var a := AtlasTexture.new()
	a.atlas = CARD_BACK
	a.region = Rect2(38, 40, 196, 133)
	return a


# ---------------------------------------------------------------- Modes

func show_back() -> void:
	_reset(Mode.BACK)
	var back := _picture(CARD_BACK, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(back)


## Vue du propriétaire : sa carte avec la bonne réponse marquée.
func show_owner(card: CardInPlay, owner_name: String) -> void:
	var data := card.data
	var options: Array[String] = [data.answer]
	options.append_array(card.shown_wrongs)
	options.sort()
	_reset(Mode.OWNER)
	var rows := _face(data, _book(data), book_art(data))
	for i in options.size():
		rows.add_child(_owner_row(LETTERS[i], options[i], options[i] == data.answer))
	_footer(data, "Ta carte" if owner_name.is_empty() else "La carte de %s" % owner_name)


## Vue du propriétaire pendant que l'adversaire répond : les propositions dans l'ordre
## qu'il voit, la bonne réponse marquée. highlight_owner_row() montre son hésitation.
func show_owner_answering(data: CardData, presented: Array[String], footer: String) -> void:
	_reset(Mode.OWNER)
	var rows := _face(data, _book(data), book_art(data))
	for i in presented.size():
		var row := _owner_row(LETTERS[i], presented[i], presented[i] == data.answer)
		rows.add_child(row)
		_owner_rows[presented[i]] = row
	_footer(data, footer)


func highlight_owner_row(text: String, state: Highlight) -> void:
	for t in _owner_rows:
		var row: PanelContainer = _owner_rows[t]
		var correct := (row.get_meta("correct", false) as bool)
		var fill := RIGHT if correct else PILL
		var edge := Color.TRANSPARENT
		if t == text and state != Highlight.NONE:
			match state:
				Highlight.HESITATE:
					fill = RIGHT if correct else PILL_PRESSED
				Highlight.RIGHT:
					fill = RIGHT
				Highlight.WRONG:
					fill = WRONG
			edge = NAVY
		row.add_theme_stylebox_override("panel", _pill_style(fill, edge))
		_set_row_ink(row, PILL if fill != PILL and fill != PILL_PRESSED else INK)


## Vue de celui qui répond : les propositions se touchent sur la carte.
func show_question(data: CardData, presented: Array[String], owner_name: String, footer: String = "") -> void:
	_reset(Mode.ANSWER)
	# Ni le livre ni son illustration : ils trahiraient souvent la réponse (« Ruth », « Jonas »…).
	var rows := _face(data, "", null)
	for i in presented.size():
		var b := make_answer_button(LETTERS[i], presented[i])
		b.size_flags_vertical = Control.SIZE_FILL
		b.pressed.connect(func(): answered.emit(presented[i]))
		rows.add_child(b)
		_answer_buttons[presented[i]] = b
	_footer(data, footer if not footer.is_empty() else "La carte de %s" % owner_name)


## Après une bonne réponse : la carte montre son récit.
func show_reveal(data: CardData, story_title: String) -> void:
	_reset(Mode.REVEAL)
	var v := _layout(book_art(data), story_title if not story_title.is_empty() else _book(data), 0.42)
	v.add_child(UiTheme.label(data.question, 14, INK_SOFT, 800))
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _pill_style(RIGHT, Color.TRANSPARENT, 16, 8))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(UiTheme.title(data.answer, 26, UiTheme.CREAM))
	v.add_child(pill)
	v.add_child(UiTheme.title(data.reference, 18, Color("9a3412")))
	if not data.explanation.is_empty():
		var e := UiTheme.label(data.explanation, 14, INK, 700)
		e.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(e)


## Retourne la carte (animation), en changeant de face au milieu.
func flip(change_face: Callable) -> void:
	Sound.play("carte", -4.0)
	var t := create_tween()
	t.tween_property(self, "scale:x", 0.0, 0.15).set_ease(Tween.EASE_IN)
	t.tween_callback(change_face)
	t.tween_property(self, "scale:x", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Colore la proposition choisie (verte si juste, rouge sinon) et bloque les autres.
func mark_answer(choice: String, correct: bool) -> void:
	Sound.play("juste" if correct else "faux")
	for text in _answer_buttons:
		var b: Button = _answer_buttons[text]
		b.disabled = true
		if text == choice:
			tint(b, correct)


func set_answers_enabled(on: bool) -> void:
	for text in _answer_buttons:
		(_answer_buttons[text] as Button).disabled = not on


# ---------------------------------------------------------------- Réponses

## Bouton de réponse en pastille crème, lettre dans un rond bleu nuit cerclé d'or
## (aussi utilisé par la question de départ).
static func make_answer_button(letter: String, text: String, height: float = 50) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiTheme.px(height))
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, _pill_style(PILL))
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, _pill_style(PILL_PRESSED))
	var row := _row(letter, text)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(row)
	b.set_meta("row", row)
	return b


## Colore une réponse après coup : vert si juste, rouge si fausse.
static func tint(b: Button, correct: bool) -> void:
	var s := _pill_style(RIGHT if correct else WRONG, NAVY)
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(state, s)
	if b.has_meta("row"):
		_set_row_ink(b.get_meta("row"), PILL)


static func _pill_style(fill: Color, edge: Color = Color.TRANSPARENT, pad_h: float = 6, pad_v: float = 3) -> StyleBoxFlat:
	var s := UiTheme.box(fill, UiTheme.px(40), UiTheme.px(pad_h), UiTheme.px(pad_v))
	s.border_color = PILL_EDGE if edge == Color.TRANSPARENT else edge
	s.border_width_bottom = UiTheme.px(3)
	if edge != Color.TRANSPARENT:
		s.set_border_width_all(UiTheme.px(3))
	s.anti_aliasing = true
	return s


## Lettre dans son rond, puis le texte de la réponse.
static func _row(letter: String, text: String) -> HBoxContainer:
	var h := UiTheme.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(UiTheme.px(2), 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pad)
	var dot := UiTheme.circle(NAVY, 32, Color("c99a3c"), 2.5)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UiTheme.title(letter, 17, UiTheme.CREAM)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.add_child(l)
	h.add_child(dot)
	var t := UiTheme.label(text, 17, INK, 900, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.name = "Text"
	h.add_child(t)
	return h


static func _set_row_ink(row: Control, color: Color) -> void:
	var r: Node = row if row is HBoxContainer else row.get_child(0)
	var t := r.get_node_or_null("Text") as Label
	if t:
		t.add_theme_color_override("font_color", color)


func _owner_row(letter: String, text: String, correct: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill_style(RIGHT if correct else PILL))
	p.custom_minimum_size = Vector2(0, UiTheme.px(48))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_meta("correct", correct)
	var row := _row(letter, text)
	if correct:
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.CREAM, UiTheme.px(10), UiTheme.px(8), UiTheme.px(2)))
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tl := UiTheme.label("la bonne", 12, Color("1d7a47"), 900)
		tl.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag.add_child(tl)
		row.add_child(tag)
		var end := Control.new()
		end.custom_minimum_size = Vector2(UiTheme.px(4), 0)
		row.add_child(end)
	p.add_child(row)
	_set_row_ink(row, PILL if correct else INK)
	return p


# ---------------------------------------------------------------- Construction

func _reset(m: Mode) -> void:
	mode = m
	_answer_buttons.clear()
	_owner_rows.clear()
	for child in _content.get_children():
		child.queue_free()
	for child in _overlay.get_children():
		child.queue_free()


func _book(data: CardData) -> String:
	return data.books[0] if not data.books.is_empty() else ""


## Face de carte : illustration et bandeau, puis la question sur le parchemin. Renvoie la
## colonne où poser les réponses.
func _face(data: CardData, ribbon: String, art: Texture2D) -> VBoxContainer:
	var v := _layout(art if art != null else book_art(null), ribbon, 0.36)
	var q := UiTheme.title(data.question, 21, INK)
	v.add_child(q)
	v.add_child(Divider.new())
	var rows := UiTheme.vbox(7)
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(rows)
	_badges(data)
	return rows


## Illustration en haut (part de la hauteur : art_share), parchemin dessous. Renvoie la
## colonne du parchemin.
func _layout(picture: Texture2D, ribbon: String, art_share: float) -> VBoxContainer:
	var col := UiTheme.vbox(0)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(col)

	var art := Control.new()
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_stretch_ratio = art_share
	col.add_child(art)
	var pic := _picture(picture, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(pic)
	if not ribbon.is_empty():
		art.add_child(_ribbon(ribbon))

	var sheet := PanelContainer.new()
	var paper := StyleBoxTexture.new()
	paper.texture = CARD_FACE
	paper.region_rect = Rect2(60, 60, 166, 150)
	sheet.add_theme_stylebox_override("panel", paper)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.size_flags_stretch_ratio = 1.0 - art_share
	col.add_child(sheet)
	sheet.add_child(_shade())
	var m := UiTheme.margins(14, 12, 14, 8)
	sheet.add_child(m)
	_sheet = UiTheme.vbox(8)
	m.add_child(_sheet)
	return _sheet


## Ombre douce en haut du parchemin, sous l'illustration.
static func _shade() -> Control:
	var g := Gradient.new()
	g.set_color(0, Color(0.23, 0.12, 0.03, 0.45))
	g.set_color(1, Color(0.23, 0.12, 0.03, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tr.custom_minimum_size = Vector2(0, UiTheme.px(10))
	return tr


## Bandeau bleu nuit cerclé d'or, en bas de l'illustration.
func _ribbon(text: String) -> Control:
	var holder := CenterContainer.new()
	holder.anchor_left = 0
	holder.anchor_right = 1
	holder.anchor_top = 1
	holder.anchor_bottom = 1
	holder.offset_top = -UiTheme.px(40)
	holder.offset_bottom = -UiTheme.px(8)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := PanelContainer.new()
	var s := UiTheme.box(Color(0.055, 0.12, 0.3, 0.92), UiTheme.px(16), UiTheme.px(16), UiTheme.px(2))
	s.border_color = Color("f2c14e")
	s.set_border_width_all(UiTheme.px(2))
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.title(text, 16, Color("ffd76a"))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	holder.add_child(p)
	return holder


## Médaillon de difficulté (haut gauche) et pastille de catégorie (haut droite).
func _badges(data: CardData) -> void:
	var badge := UiTheme.circle(NAVY, 58, Color("f2c14e"), 3)
	badge.position = Vector2(UiTheme.px(10), UiTheme.px(10))
	badge.size = badge.custom_minimum_size
	var bv := UiTheme.vbox(0)
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.set_anchors_preset(Control.PRESET_FULL_RECT)
	var icon := Shapes.Icon.new(data.difficulty, UiTheme.CREAM, 18)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(icon)
	bv.add_child(UiTheme.title(BADGE_LABELS.get(data.difficulty, ""), 12, Color("ffd76a")))
	badge.add_child(bv)
	_overlay.add_child(badge)

	var orb := UiTheme.circle(NAVY, 44, Color("f2c14e"), 3)
	orb.anchor_left = 1.0
	orb.anchor_right = 1.0
	orb.offset_left = -UiTheme.px(54)
	orb.offset_right = -UiTheme.px(10)
	orb.offset_top = UiTheme.px(10)
	orb.offset_bottom = UiTheme.px(54)
	var cat := Shapes.Icon.new(data.category, Color("ffd76a"), 24)
	cat.set_anchors_preset(Control.PRESET_FULL_RECT)
	orb.add_child(cat)
	_overlay.add_child(orb)


## Pied du parchemin : catégorie à gauche, à qui est la carte à droite.
func _footer(data: CardData, right_text: String) -> void:
	var foot := UiTheme.hbox(8)
	var left := UiTheme.label(data.category_label(), 12, INK_SOFT, 800, HORIZONTAL_ALIGNMENT_LEFT)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(left)
	var right := UiTheme.label(right_text, 12, INK_SOFT, 800, HORIZONTAL_ALIGNMENT_RIGHT)
	right.autowrap_mode = TextServer.AUTOWRAP_OFF
	foot.add_child(right)
	_sheet.add_child(foot)


func _picture(texture: Texture2D, stretch: TextureRect.StretchMode) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = stretch
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _inset(c: Control, v: float) -> void:
	c.offset_left = UiTheme.px(v)
	c.offset_top = UiTheme.px(v)
	c.offset_right = -UiTheme.px(v)
	c.offset_bottom = -UiTheme.px(v)


## Filet brun avec un losange au milieu, sous la question.
class Divider extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, UiTheme.px(12))

	func _draw() -> void:
		var c := size / 2
		var col := Color("7a4a1c")
		var d := UiTheme.px(6)
		var w := maxf(1.0, UiTheme.px(1.2))
		draw_line(Vector2(size.x * 0.14, c.y), Vector2(c.x - d * 2, c.y), col, w, true)
		draw_line(Vector2(c.x + d * 2, c.y), Vector2(size.x * 0.86, c.y), col, w, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d * 1.4, 0), c + Vector2(0, d), c + Vector2(-d * 1.4, 0)]), col)
