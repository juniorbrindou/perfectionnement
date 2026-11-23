class_name CardView
extends Control
## La carte à l'écran (maquettes validées) : la question et ses réponses sont écrites
## sur la carte, et on répond en touchant la carte.
##
## Modes :
##   BACK   dos de carte (framboise et sarcelle, bulle « ? »)
##   OWNER  vue du propriétaire : la bonne réponse est marquée en vert
##   ANSWER vue de celui qui répond : les réponses sont des boutons → signal answered
##   REVEAL après une bonne réponse : illustration du récit, réponse, référence

signal answered(choice: String)

enum Mode { BACK, OWNER, ANSWER, REVEAL }

const LETTERS := ["A", "B", "C", "D", "E"]
const BADGE_LABELS := {"lait": "Lait", "manne": "Manne", "solide": "Nourriture\nsolide"}

var mode := Mode.BACK

var _body: Panel
var _pattern: Control
var _back_art: Control
var _content: MarginContainer
var _overlay: Control
var _answer_buttons := {}  ## texte de la réponse → Button
var _owner_rows := {}  ## texte de la réponse → PanelContainer (vue du propriétaire)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func(): pivot_offset = size / 2)

	var frame := Shapes.NotchedFrame.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	_body = Panel.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.offset_left = UiTheme.px(16)
	_body.offset_top = UiTheme.px(16)
	_body.offset_right = -UiTheme.px(16)
	_body.offset_bottom = -UiTheme.px(44)
	_body.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	_back_art = Shapes.CardBackArt.new()
	_back_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(_back_art)
	_pattern = Shapes.RingPattern.new()
	_pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(_pattern)

	_content = MarginContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_content)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	show_back()


# ---------------------------------------------------------------- Modes

func show_back() -> void:
	_reset(Mode.BACK, UiTheme.FRAMBOISE)
	_back_art.visible = true


## Vue du propriétaire : sa carte avec la bonne réponse marquée.
func show_owner(card: CardInPlay, owner_name: String) -> void:
	var data := card.data
	_reset(Mode.OWNER, UiTheme.difficulty_color(data.difficulty))
	var options: Array[String] = [data.answer]
	options.append_array(card.shown_wrongs)
	options.sort()
	var col := _question_layout(data)
	var band := _answers_band(data, col)
	for i in options.size():
		band.add_child(_owner_row(LETTERS[i], options[i], options[i] == data.answer))
	_chrome(data, options.size(), "Ta carte" if owner_name.is_empty() else "La carte de %s" % owner_name)


## Vue du propriétaire pendant que l'adversaire répond : les propositions dans l'ordre
## qu'il voit, la bonne réponse marquée. highlight_owner_row() montre son hésitation.
func show_owner_answering(data: CardData, presented: Array[String], footer: String) -> void:
	_reset(Mode.OWNER, UiTheme.difficulty_color(data.difficulty))
	var col := _question_layout(data)
	var band := _answers_band(data, col)
	for i in presented.size():
		var row := _owner_row(LETTERS[i], presented[i], presented[i] == data.answer)
		band.add_child(row)
		_owner_rows[presented[i]] = row
	_chrome(data, presented.size(), footer)


enum Highlight { NONE, HESITATE, RIGHT, WRONG }

func highlight_owner_row(text: String, state: Highlight) -> void:
	for t in _owner_rows:
		var row: PanelContainer = _owner_rows[t]
		var correct := (row.get_meta("correct", false) as bool)
		var s := UiTheme.box(UiTheme.GREEN if correct else Color.TRANSPARENT, UiTheme.px(10), UiTheme.px(12), UiTheme.px(8))
		if t == text and state != Highlight.NONE:
			match state:
				Highlight.HESITATE:
					s.bg_color = UiTheme.GREEN if correct else Color(1, 1, 1, 0.18)
				Highlight.RIGHT:
					s.bg_color = UiTheme.GREEN
				Highlight.WRONG:
					s.bg_color = Color("ff4f6d")
			s.border_color = UiTheme.CREAM
			s.set_border_width_all(UiTheme.px(3))
		row.add_theme_stylebox_override("panel", s)


## Vue de celui qui répond : les propositions se touchent sur la carte.
func show_question(data: CardData, presented: Array[String], owner_name: String, footer: String = "") -> void:
	_reset(Mode.ANSWER, UiTheme.difficulty_color(data.difficulty))
	var col := _question_layout(data)
	var band := _answers_band(data, col)
	for i in presented.size():
		var b := _answer_button(LETTERS[i], presented[i])
		band.add_child(b)
		_answer_buttons[presented[i]] = b
	_chrome(data, presented.size(), footer if not footer.is_empty() else "La carte de %s" % owner_name)


## Après une bonne réponse : la carte montre son récit.
func show_reveal(data: CardData, story_title: String) -> void:
	_reset(Mode.REVEAL, UiTheme.CREAM)
	_pattern.visible = false
	_set_margins(0, 0, 0, 0)
	var col := UiTheme.vbox(0)
	_content.add_child(col)

	var art := PanelContainer.new()
	var hue := float(abs(data.story.hash()) % 360) / 360.0
	art.add_theme_stylebox_override("panel", UiTheme.box(Color.from_hsv(hue, 0.45, 0.6), 0))
	art.custom_minimum_size = Vector2(0, UiTheme.px(230))
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_label := UiTheme.label("Illustration : %s" % story_title, 13, UiTheme.CREAM, 900)
	art_label.size_flags_vertical = Control.SIZE_SHRINK_END
	art.add_child(art_label)
	col.add_child(art)

	var text := UiTheme.margins(18, 16, 18, 16)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(text)
	var v := UiTheme.vbox(10)
	text.add_child(v)
	v.add_child(UiTheme.label(data.question, 15, Color("6b5a8e"), 800, HORIZONTAL_ALIGNMENT_LEFT))
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.GREEN, UiTheme.px(12), UiTheme.px(14), UiTheme.px(8)))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(UiTheme.title(data.answer, 26, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(pill)
	v.add_child(UiTheme.title(data.reference, 18, UiTheme.FRAMBOISE, HORIZONTAL_ALIGNMENT_LEFT))
	if not data.explanation.is_empty():
		v.add_child(UiTheme.label(data.explanation, 15, UiTheme.NIGHT, 700, HORIZONTAL_ALIGNMENT_LEFT))


## Retourne la carte (animation), en changeant de face au milieu.
func flip(change_face: Callable) -> void:
	var t := create_tween()
	t.tween_property(self, "scale:x", 0.0, 0.15).set_ease(Tween.EASE_IN)
	t.tween_callback(change_face)
	t.tween_property(self, "scale:x", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Colore la proposition choisie (verte si juste, framboise sinon) et bloque les autres.
func mark_answer(choice: String, correct: bool) -> void:
	for text in _answer_buttons:
		var b: Button = _answer_buttons[text]
		b.disabled = true
		if text == choice:
			tint(b, correct)


func set_answers_enabled(on: bool) -> void:
	for text in _answer_buttons:
		(_answer_buttons[text] as Button).disabled = not on


# ---------------------------------------------------------------- Construction

func _reset(m: Mode, body_color: Color) -> void:
	mode = m
	_answer_buttons.clear()
	_owner_rows.clear()
	for child in _content.get_children():
		child.queue_free()
	for child in _overlay.get_children():
		child.queue_free()
	_body.add_theme_stylebox_override("panel", UiTheme.box(body_color, UiTheme.px(16)))
	_back_art.visible = false
	_pattern.visible = m != Mode.BACK
	_set_margins(14, 62, 14, 14)


func _set_margins(left: float, top: float, right: float, bottom: float) -> void:
	_content.add_theme_constant_override("margin_left", UiTheme.px(left))
	_content.add_theme_constant_override("margin_top", UiTheme.px(top))
	_content.add_theme_constant_override("margin_right", UiTheme.px(right))
	_content.add_theme_constant_override("margin_bottom", UiTheme.px(bottom))


func _question_layout(data: CardData) -> VBoxContainer:
	var col := UiTheme.vbox(16)
	_content.add_child(col)
	var bubble := Shapes.SpeechBubble.new("Question")
	var q := UiTheme.label(data.question, 21, UiTheme.NIGHT, 900)
	bubble.add_child(q)
	col.add_child(bubble)
	return col


func _answers_band(data: CardData, col: VBoxContainer) -> VBoxContainer:
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.answers_color(data.difficulty), UiTheme.px(18), UiTheme.px(8), UiTheme.px(8)))
	band.size_flags_vertical = Control.SIZE_EXPAND_FILL
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(band)
	var rows := UiTheme.vbox(8)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	band.add_child(rows)
	return rows


static func row_content(letter: String, text: String, letter_color: Color) -> HBoxContainer:
	var h := UiTheme.hbox(12)
	var l := UiTheme.title("%s)" % letter, 22, letter_color, HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size = Vector2(UiTheme.px(28), 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	var t := UiTheme.title(text, 22, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	return h


## Bouton de réponse posé sur une carte (aussi utilisé par la question de départ).
static func make_answer_button(letter: String, text: String, height: float = 58) -> Button:
	var b := Button.new()
	b.theme_type_variation = "AnswerButton"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiTheme.px(height))
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var m := UiTheme.margins(14, 4, 14, 4)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var row := row_content(letter, text, UiTheme.YELLOW)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(row)
	b.add_child(m)
	return b


## Colore une réponse après coup : vert si juste, rose vif si fausse.
static func tint(b: Button, correct: bool) -> void:
	var s := UiTheme.box(UiTheme.GREEN if correct else Color("ff4f6d"), UiTheme.px(12))
	s.border_color = UiTheme.CREAM
	s.set_border_width_all(UiTheme.px(3))
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(state, s)


func _answer_button(letter: String, text: String) -> Button:
	var b := make_answer_button(letter, text)
	b.pressed.connect(func(): answered.emit(text))
	return b

func _owner_row(letter: String, text: String, correct: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.GREEN if correct else Color.TRANSPARENT, UiTheme.px(10), UiTheme.px(12), UiTheme.px(8)))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_meta("correct", correct)
	var row := row_content(letter, text, UiTheme.CREAM if correct else UiTheme.YELLOW)
	if correct:
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.CREAM, UiTheme.px(10), UiTheme.px(8), UiTheme.px(2)))
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tl := UiTheme.label("la bonne", 12, Color("1d7a47"), 900)
		tl.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag.add_child(tl)
		row.add_child(tag)
	p.add_child(row)
	return p


## Médaillon de difficulté, pastille de catégorie, jauge des réponses, pied de carte.
func _chrome(data: CardData, options: int, footer_right: String) -> void:
	var badge := UiTheme.circle(UiTheme.NIGHT, 84, UiTheme.YELLOW, 4)
	badge.position = Vector2(-UiTheme.px(10), -UiTheme.px(10))
	badge.size = badge.custom_minimum_size
	var bv := UiTheme.vbox(0)
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.set_anchors_preset(Control.PRESET_FULL_RECT)
	var icon := Shapes.Icon.new(data.difficulty, UiTheme.CREAM, 22)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(icon)
	var bl := UiTheme.title(BADGE_LABELS.get(data.difficulty, ""), 13 if data.difficulty == "solide" else 16, UiTheme.YELLOW)
	bl.add_theme_constant_override("line_spacing", -UiTheme.px(4))
	bv.add_child(bl)
	badge.add_child(bv)
	_overlay.add_child(badge)

	var orb := UiTheme.circle(UiTheme.YELLOW, 60, UiTheme.CREAM.lerp(UiTheme.YELLOW, 0.5), 3)
	orb.anchor_left = 1.0
	orb.anchor_right = 1.0
	orb.offset_left = -UiTheme.px(66)
	orb.offset_right = -UiTheme.px(6)
	orb.offset_top = UiTheme.px(4)
	orb.offset_bottom = UiTheme.px(64)
	var cat := Shapes.Icon.new(data.category, UiTheme.VIOLET, 30)
	cat.set_anchors_preset(Control.PRESET_FULL_RECT)
	orb.add_child(cat)
	_overlay.add_child(orb)

	var gauge := UiTheme.vbox(5)
	gauge.position = Vector2(UiTheme.px(8), UiTheme.px(150))
	for i in 4:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(UiTheme.px(8), UiTheme.px(22))
		seg.color = UiTheme.YELLOW if i < options else Color(1, 1, 1, 0.18)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauge.add_child(seg)
	_overlay.add_child(gauge)

	var foot := UiTheme.hbox(8)
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.anchor_right = 1.0
	foot.offset_left = UiTheme.px(26)
	foot.offset_right = -UiTheme.px(26)
	foot.offset_top = -UiTheme.px(36)
	foot.offset_bottom = -UiTheme.px(8)
	var left := UiTheme.label(data.category_label(), 13, UiTheme.LILAC, 800, HORIZONTAL_ALIGNMENT_LEFT)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(left)
	var right := UiTheme.label(footer_right, 13, UiTheme.LILAC, 800, HORIZONTAL_ALIGNMENT_RIGHT)
	right.autowrap_mode = TextServer.AUTOWRAP_OFF
	foot.add_child(right)
	_overlay.add_child(foot)
