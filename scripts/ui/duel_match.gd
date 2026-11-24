extends Control
## Duel en ligne contre un autre joueur, sur l'écran peint « partie » (assets/duel/partie.png) :
## les deux joueurs et leurs cartes en haut, le minuteur au milieu, la carte posée sur le
## parchemin, et rien d'autre (direction validée le 2026-11-23 : écran épuré, la carte au
## centre). La carte trouvée se désagrège en particules dorées.
##
## Le serveur mène la partie (server/src/duel_en_ligne.ts) : il envoie à ce téléphone sa
## propre vue à chaque changement, et le téléphone n'envoie que ses choix. L'écran est
## reconstruit quand l'étape change, et mis à jour sur place sinon (pause, revanche, prêt).
## Les rectangles sont en pixels de l'image (319 × 679).

const P := preload("res://scripts/ui/ui_theme.gd")
const G := preload("res://scripts/ui/glass.gd")
const ART := preload("res://assets/duel/partie.png")
const CARD_BACK := preload("res://assets/duel/dos_carte.png")
const CARD_FACE := preload("res://assets/duel/face_carte.png")
const MENU_SCENE := "res://scenes/main_menu.tscn"

const AVATAR_ME := Rect2(10, 21, 46, 46)
const AVATAR_FOE := Rect2(263, 21, 46, 46)
const NAME_ME := Rect2(57, 27, 62, 17)
const NAME_FOE := Rect2(200, 27, 63, 17)
const SUB_ME := Rect2(57, 45, 62, 15)
const SUB_FOE := Rect2(200, 45, 63, 15)
const COUNT_ME := Rect2(60, 79, 26, 24)
const COUNT_FOE := Rect2(260, 79, 26, 24)
const TIMER := Rect2(124, 42, 72, 72)
const STATUS := Rect2(30, 114, 260, 30)
const RIBBON := Rect2(96, 151, 128, 22)
const CARD := Rect2(14, 140, 292, 420)
const QUESTION := Rect2(38, 188, 244, 128)
const ANSWERS := Rect2(30, 320, 260, 216)
const BELOW := Rect2(14, 560, 292, 112)

var view: Dictionary = {}
var _key := ""
var _sent := false  ## Choix déjà envoyé pour l'écran en cours.
var _end_applied := false
var _rng := RandomNumberGenerator.new()
var _hand: Array[CardInPlay] = []
var _selected := -1
var _art: Painted

# Minuteur affiché (le serveur tient le vrai délai).
var _time_left := 0.0
var _time_total := 1.0
var _timer: Countdown

# Éléments mis à jour sans reconstruire l'écran.
var _rows := {}  ## proposition → ligne de réponse
var _minis: Array = []
var _owner_view: Control
var _play_button: Button
var _continue_button: Button
var _ready_note: Label
var _rematch_button: Button
var _rematch_note: Label

# Calques
var _screen: Control
var _top: Control
var _pause_layer: Control
var _pause_ring: Countdown
var _link_layer: Control
var _quit_box: Control


func _ready() -> void:
	theme = P.get_theme()
	_rng.randomize()
	_screen = _layer()
	_top = _layer()
	Online.duel_view_received.connect(_on_view)
	Online.duel_link_changed.connect(_on_link)
	if Online.duel_match_id.is_empty() and Online.duel_view.is_empty():
		_to_menu.call_deferred()
		return
	if Online.duel_view.is_empty():
		_base()
		_parchment_message("Préparation de la partie…", "")
	else:
		_on_view(Online.duel_view)


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _process(delta: float) -> void:
	if view.get("pause") != null or not is_instance_valid(_timer):
		return
	_time_left = maxf(_time_left - delta, 0.0)
	_timer.set_time(_time_left, _time_total)


# ---------------------------------------------------------------- Vues du serveur

func _on_view(v: Dictionary) -> void:
	view = v
	if v.get("etape") == "depart":
		_end_applied = false  # Revanche : nouvelle partie.
	_apply_hand()
	var fin = v.get("fin")
	if fin is Dictionary and fin.has("talents") and not _end_applied:
		_end_applied = true
		Online.apply_duel_end(fin)
	var key := _key_of(v)
	if key != _key:
		_key = key
		_sent = false
		_render()
	else:
		_refresh_in_place()
	_update_pause()


func _key_of(v: Dictionary) -> String:
	var step := str(v.get("etape", ""))
	if step == "finie":
		var fin = v.get("fin")
		return "finie|%s" % (str(fin.get("gagne")) + str(fin.get("raison")) if fin is Dictionary else "")
	return "%s|%s|%s|%s" % [step, v.get("poseur", ""), JSON.stringify(v.get("depart")), JSON.stringify(v.get("coup"))]


func _apply_hand() -> void:
	_hand.clear()
	for c in view.get("main", []):
		if not c is Dictionary:
			continue
		var card := CardInPlay.new(CardData.from_dict(c.get("carte", {})), _rng)
		card.shown_wrongs.assign(c.get("fausses", []))
		card.reserve.clear()
		for i in int(c.get("reserve", 0)):
			card.reserve.append("?")
		_hand.append(card)


func _render() -> void:
	_time_total = maxf(float(view.get("temps", 0)), 1.0)
	_time_left = float(view.get("temps", 0))
	var mine: bool = view.get("poseur", "") == "moi"
	match str(view.get("etape", "")):
		"attente":
			_base()
			_parchment_message("En attente de l'adversaire…", "La partie commence dès que vous êtes deux.")
		"depart":
			_show_starter()
		"annonce":
			_show_announce()
		"choisir":
			if mine:
				_begin_choose()
			else:
				_show_opponent_choosing()
		"repondre":
			if mine:
				_show_opponent_answering()
			else:
				_begin_answer()
		"resultat":
			_show_result()
		"finie":
			_show_end()
		"annulee":
			_show_cancelled()


func _refresh_in_place() -> void:
	if is_instance_valid(_ready_note):
		var c = view.get("continuer")
		_ready_note.visible = c is Dictionary and c.get("adversaire", false)
	if is_instance_valid(_rematch_button):
		_update_rematch()


func _opponent() -> String:
	var a = view.get("adversaire")
	return str(a.get("pseudo", "Ton adversaire")) if a is Dictionary else "Ton adversaire"


func _opponent_level() -> int:
	var a = view.get("adversaire")
	return int(a.get("niveau", 1)) if a is Dictionary else 1


func _difficulty() -> String:
	return str(view.get("difficulte", "lait"))


func _stake() -> int:
	return int(view.get("mise", 0))


## Taille de police en pixels de l'image.
func _fs(img_px: float) -> int:
	return int(img_px * _art.s)


# ---------------------------------------------------------------- L'écran peint

## Fond peint et en-tête : les deux joueurs, leurs cartes, le minuteur. active : "moi",
## "adversaire" ou "" ; le joueur qui doit agir a un halo doré.
func _base(active: String = "", with_timer: bool = false) -> void:
	_rows.clear()
	_minis.clear()
	_timer = null
	_continue_button = null
	_ready_note = null
	_rematch_button = null
	_owner_view = null
	for c in _screen.get_children():
		c.queue_free()
	_art = Painted.cover(_screen, ART)
	var a := _art
	var hand := [view.get("main", []).size(), int(view.get("mainAdverse", 0))]
	for p in [0, 1]:
		var me: bool = p == 0
		var player: String = Online.username if me else _opponent()
		var level: int = int(Progression.from_xp(Online.xp())["level"]) if me else _opponent_level()
		var face_rect := AVATAR_ME if me else AVATAR_FOE
		if active == ("moi" if me else "adversaire"):
			var halo := Halo.new()
			a.place(halo, face_rect.grow(10))
		var face := G.avatar(player, G.ME if me else G.FOE, 10)
		a.place(face, face_rect)
		var fs := P.box(G.ME if me else G.FOE, _fs(30))
		fs.border_color = Color("ffc84a")
		fs.set_border_width_all(maxi(2, _fs(2)))
		face.add_theme_stylebox_override("panel", fs)
		(face.get_child(0) as Label).add_theme_font_size_override("font_size", _fs(20))
		a.patch(Color("011946"), NAME_ME if me else NAME_FOE, 3)
		a.text(player, 12, Color.WHITE, NAME_ME if me else NAME_FOE, true, HORIZONTAL_ALIGNMENT_LEFT if me else HORIZONTAL_ALIGNMENT_RIGHT)
		a.patch(Color("011946"), SUB_ME if me else SUB_FOE, 3)
		a.text("Niveau %d" % level, 9, Painted.GOLD_TEXT, SUB_ME if me else SUB_FOE, false, HORIZONTAL_ALIGNMENT_LEFT if me else HORIZONTAL_ALIGNMENT_RIGHT)
		a.patch(Color("021740"), COUNT_ME if me else COUNT_FOE, 4)
		a.text(str(hand[p]), 16, Color.WHITE, COUNT_ME if me else COUNT_FOE)
	_timer = Countdown.new()
	_timer.show_number = with_timer
	a.place(_timer, TIMER)
	_timer.set_time(_time_left if with_timer else 1.0, _time_total if with_timer else 1.0)
	var quit := a.tap(Rect2(124, 4, 72, 34), _ask_quit)
	quit.tooltip_text = "Quitter"


func _ribbon(text: String) -> void:
	_art.patch(Painted.BROWN, RIBBON, 3)
	_art.text(text, 11, Color("fbe3b0"), RIBBON)


## Pastille de statut entre l'en-tête et la carte, avec trois points qui clignotent.
func _status(text: String, dots: bool = false, color: Color = Color.WHITE) -> void:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.place(holder, STATUS)
	var pill := PanelContainer.new()
	var st := P.box(Color(0.02, 0.07, 0.22, 0.88), _fs(15), _fs(10), _fs(3))
	st.border_color = Color("c99a3c")
	st.set_border_width_all(maxi(1, _fs(1)))
	pill.add_theme_stylebox_override("panel", st)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _fs(6))
	pill.add_child(row)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", P.TITLE_FONT)
	l.add_theme_font_size_override("font_size", _fs(12))
	l.add_theme_color_override("font_color", color)
	row.add_child(l)
	if dots:
		for i in 3:
			var dot := P.circle(Color("ffc84a"), 5)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(dot)
			var t := dot.create_tween().set_loops()
			t.tween_interval(0.2 * i)
			t.tween_property(dot, "modulate:a", 0.3, 0.5)
			t.tween_property(dot, "modulate:a", 1.0, 0.5)


func _question(text: String, size_px: float = 15) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", P.TITLE_FONT)
	l.add_theme_font_size_override("font_size", _fs(size_px))
	l.add_theme_color_override("font_color", Painted.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.place(l, QUESTION)
	return l


## Les réponses sur le parchemin (elles remplacent les lignes de l'image, pour en avoir 2 à 5).
## clickable : on répond en touchant une ligne ; correct : bonne réponse marquée (sa propre carte).
func _answers(options: Array, clickable: bool, correct: String = "") -> void:
	_parchment_patch()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", _fs(6))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.place(col, ANSWERS)
	var h := minf(44.0, (ANSWERS.size.y - 6 * (options.size() - 1)) / maxf(options.size(), 1))
	for i in options.size():
		var option := str(options[i])
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(0, h * _art.s)
		row.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", _fs(8))
		line.set_anchors_preset(Control.PRESET_FULL_RECT)
		line.offset_left = _fs(8)
		line.offset_right = -_fs(8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
		var letter := P.circle(Painted.BROWN, 1)
		letter.custom_minimum_size = Vector2(_fs(24), _fs(24))
		letter.add_theme_stylebox_override("panel", P.box(Color("4a2410"), _fs(12)))
		letter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ll := Label.new()
		ll.text = CardView.LETTERS[i]
		ll.add_theme_font_override("font", P.TITLE_FONT)
		ll.add_theme_font_size_override("font_size", _fs(13))
		ll.add_theme_color_override("font_color", Color("fbe3b0"))
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ll.set_anchors_preset(Control.PRESET_FULL_RECT)
		letter.add_child(ll)
		line.add_child(letter)
		var tl := Label.new()
		tl.text = option
		tl.add_theme_font_override("font", P.TITLE_FONT)
		tl.add_theme_font_size_override("font_size", _fs(13 if option.length() < 26 else 11))
		tl.add_theme_color_override("font_color", Painted.INK)
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(tl)
		var check := Label.new()
		check.text = "✓"
		check.add_theme_font_size_override("font_size", _fs(15))
		check.add_theme_color_override("font_color", Color("1d7a47"))
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		check.visible = option == correct
		line.add_child(check)
		row.set_meta("check", check)
		_mark_row(row, "juste" if option == correct else "")
		if clickable:
			row.pressed.connect(_on_answer.bind(option))
		col.add_child(row)
		_rows[option] = row


## state : "" (neutre), "juste", "faux", "choisi".
func _mark_row(row: Button, state: String) -> void:
	var fill := Painted.SLOT
	var edge := Color("d3a85a")
	match state:
		"juste":
			fill = Color("d4f0da")
			edge = Color("2e9b5f")
		"faux":
			fill = Color("ffd9d6")
			edge = Color("d9534f")
		"choisi":
			fill = Color("ffe9a8")
			edge = Color("e0a520")
	var st := P.box(fill, _fs(10))
	st.border_color = edge
	st.set_border_width_all(maxi(2, _fs(1.5)))
	st.shadow_color = Color(0.35, 0.2, 0.05, 0.25)
	st.shadow_size = _fs(1)
	st.shadow_offset = Vector2(0, _fs(1.5))
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		row.add_theme_stylebox_override(s, st)
	var check: Label = row.get_meta("check", null)
	if check:
		check.visible = state == "juste"


## Parchemin uni qui remplace les lignes de réponse de l'image ; bord fondu dans le décor.
func _parchment_patch() -> void:
	var p := _art.patch(Painted.PARCHMENT, ANSWERS, 10)
	var st := P.box(Color("f9d899"), _fs(10))
	st.shadow_color = Color("f9d899")
	st.shadow_size = _fs(6)
	p.add_theme_stylebox_override("panel", st)


## Carte vue de dos, posée sur le parchemin.
func _card_back(pulse: bool) -> Control:
	var holder := _rounded(CARD.grow(-6), 14)
	var back := TextureRect.new()
	back.texture = CARD_BACK
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(back)
	if pulse:
		holder.pivot_offset = holder.size / 2
		var t := holder.create_tween().set_loops()
		t.tween_property(holder, "scale", Vector2(1.02, 1.02), 0.9).set_trans(Tween.TRANS_SINE)
		t.tween_property(holder, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)
	return holder


func _rounded(img: Rect2, radius_img: float) -> Panel:
	var mask := Panel.new()
	mask.add_theme_stylebox_override("panel", P.box(Color.WHITE, _fs(radius_img)))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.place(mask, img)
	return mask


## Retourne la carte : le dos se rétrécit et disparaît, la face (déjà dessinée dessous) apparaît.
func _flip_away(back: Control) -> void:
	back.pivot_offset = back.size / 2
	var t := back.create_tween()
	t.tween_property(back, "scale:x", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(back.queue_free)


func _below_button(label: String, action: Callable, gold: bool = true, img: Rect2 = Rect2(40, 600, 240, 46)) -> Button:
	var b := Painted.gold_button(label, action, img.size.y * _art.s, _fs(15)) if gold \
		else Painted.navy_button(label, action, img.size.y * _art.s, _fs(14))
	_art.place(b, img)
	return b


func _parchment_message(title: String, text: String) -> void:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", _fs(10))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parchment_patch()
	_art.place(v, Rect2(QUESTION.position, Vector2(QUESTION.size.x, ANSWERS.end.y - QUESTION.position.y)))
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", P.TITLE_FONT)
	t.add_theme_font_size_override("font_size", _fs(20))
	t.add_theme_color_override("font_color", Painted.INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if not text.is_empty():
		var l := Label.new()
		l.text = text
		l.add_theme_font_override("font", P.body_font(800))
		l.add_theme_font_size_override("font_size", _fs(12))
		l.add_theme_color_override("font_color", Color("6b4a24"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)


# ---------------------------------------------------------------- Question de départ

func _show_starter() -> void:
	var d = view.get("depart")
	if not d is Dictionary:
		return
	_base("", true)
	_ribbon("Question de départ")
	var coup = view.get("coup")
	if coup is Dictionary and coup.get("type") == "nouvelle_question":
		_status("Personne n'a répondu : nouvelle question")
	else:
		_status("Le premier qui répond juste commence")
	_question(str(d.get("question", "")))
	_answers(d.get("propositions", []), true)


func _on_answer(choice: String) -> void:
	if _sent:
		return
	_sent = true
	for o in _rows:
		(_rows[o] as Button).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _rows.has(choice):
		_mark_row(_rows[choice], "choisi")
	var step := str(view.get("etape", ""))
	if step == "depart":
		Online.duel_send(Online.OP_DEPART, {"choix": choice})
	elif step == "repondre":
		Online.duel_send(Online.OP_REPONDRE, {"choix": choice})


func _show_announce() -> void:
	var c = view.get("coup")
	var coup: Dictionary = c if c is Dictionary else {}
	var me_first: bool = coup.get("jeCommence", false)
	_base("moi" if me_first else "adversaire")
	_ribbon("Question de départ")
	var right := str(coup.get("bonne", ""))
	var text := ""
	if coup.get("parMoi", false):
		text = "Bonne réponse : « %s »." % right if coup.get("juste", false) \
			else "« %s » n'était pas la bonne réponse. C'était « %s »." % [coup.get("choix", ""), right]
	else:
		text = "%s a trouvé le premier : « %s »." % [_opponent(), right] if coup.get("juste", false) \
			else "%s s'est trompé. La bonne réponse était « %s »." % [_opponent(), right]
	_parchment_message("Tu commences !" if me_first else "%s commence" % _opponent(), text)


# ---------------------------------------------------------------- Poser une carte

func _begin_choose() -> void:
	_selected = -1
	_base("moi", true)
	_status("À toi : choisis la carte à poser")
	_owner_view = Control.new()
	_owner_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_owner_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(_owner_view)
	# La main : les dos de cartes sur le paysage du bas ; la carte touchée se lève.
	var n := _hand.size()
	for i in n:
		var mini := TextureButton.new()
		mini.texture_normal = CARD_BACK
		mini.ignore_texture_size = true
		mini.stretch_mode = TextureButton.STRETCH_SCALE
		mini.focus_mode = Control.FOCUS_NONE
		var w := 38.0
		var x := 160.0 - 0.5 * (n * w + (n - 1) * 4.0) + i * (w + 4.0)
		_art.place(mini, Rect2(x, 562, w, 46))
		mini.pivot_offset = mini.size / 2
		mini.pressed.connect(_select_card.bind(i))
		_minis.append(mini)
	_play_button = _below_button("Poser cette carte", _play_selected, true, Rect2(50, 618, 220, 44))
	_play_button.disabled = true
	if n > 0:
		_select_card(0)


func _select_card(index: int) -> void:
	if index >= _hand.size() or _sent:
		return
	_selected = index
	for i in _minis.size():
		var m: Control = _minis[i]
		var up := i == index
		var t := m.create_tween().set_parallel()
		t.tween_property(m, "scale", Vector2(1.12, 1.12) if up else Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(m, "modulate", Color(1.25, 1.15, 0.9) if up else Color(0.8, 0.8, 0.85), 0.18)
	var card := _hand[index]
	_rows.clear()
	for c in _owner_view.get_children():
		c.queue_free()
	var holder := _owner_view
	var keep := _art.parent
	_art.parent = holder
	_ribbon(card.data.category_label())
	var q := _question(card.data.question)
	q.modulate.a = 0.0
	q.create_tween().tween_property(q, "modulate:a", 1.0, 0.2)
	var options: Array[String] = [card.data.answer]
	options.append_array(card.shown_wrongs)
	options.sort()
	_answers(options, false, card.data.answer)
	_art.parent = keep
	_play_button.disabled = false


func _play_selected() -> void:
	if _selected < 0 or _sent:
		return
	_sent = true
	_play_button.disabled = true
	_play_button.text = "Carte posée"
	var m: Control = _minis[_selected]
	m.create_tween().tween_property(m, "position:y", m.position.y - _fs(60), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	Online.duel_send(Online.OP_JOUER, {"index": _selected})


func _show_opponent_choosing() -> void:
	_base("adversaire", true)
	_status("%s choisit une carte" % _opponent(), true)
	_card_back(true)


# ---------------------------------------------------------------- L'adversaire répond à ta carte

func _show_opponent_answering() -> void:
	var c = view.get("carte")
	if not c is Dictionary:
		return
	var data := CardData.from_dict(c)
	_base("adversaire", true)
	_status("%s réfléchit" % _opponent(), true)
	_ribbon(data.category_label())
	_question(data.question)
	_answers(c.get("propositions", []), false, data.answer)


# ---------------------------------------------------------------- Répondre à sa carte

func _begin_answer() -> void:
	var c = view.get("carte")
	if not c is Dictionary:
		return
	var data := CardData.from_dict(c)
	_base("moi", true)
	_status("Touche ta réponse")
	_ribbon(data.category_label())
	_question(data.question)
	_answers(c.get("propositions", []), true)
	# La carte arrive de dos, puis se retourne.
	var back := _card_back(false)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(back):
		_flip_away(back)


# ---------------------------------------------------------------- Résultat d'un coup

func _show_result() -> void:
	var c = view.get("coup")
	if not c is Dictionary or c.get("type") != "coup":
		return
	var coup: Dictionary = c
	var data := CardData.from_dict(coup.get("carte", {}))
	var correct: bool = coup.get("juste", false)
	var mine: bool = coup.get("mienne", false)
	var choice := str(coup.get("choix", ""))
	_base("")
	var headline := ""
	if mine:
		headline = ("%s a trouvé ta carte !" if correct else "%s s'est trompé !") % _opponent()
	else:
		headline = "Bonne réponse !" if correct else ("Temps écoulé !" if coup.get("tempsEcoule", false) else "Raté !")
	var good_for_me := correct != mine
	_status(headline, false, Color("ffd76a") if good_for_me else Color("ff9b9b"))
	_ribbon(data.category_label())
	_question(data.question)
	_answers(coup.get("presentees", []), false, data.answer if (correct or mine) else "")
	if not correct and _rows.has(choice):
		_mark_row(_rows[choice], "faux")
	if correct:
		_destroy_card(data, "Ta carte est détruite" if mine else "Carte de %s détruite" % _opponent())
	else:
		var before: int = coup.get("presentees", []).size()
		var weakened := "Elle n'a plus que %d réponses." % (before - 1) if before > 2 else "Elle garde 2 réponses, peut-être pas les mêmes."
		var note := Label.new()
		note.text = ("Ta carte te revient. " if mine else "La carte retourne chez %s. " % _opponent()) + weakened
		note.add_theme_font_override("font", P.body_font(900))
		note.add_theme_font_size_override("font_size", _fs(11))
		note.add_theme_color_override("font_color", Color.WHITE)
		note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		note.add_theme_constant_override("outline_size", _fs(2))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.place(note, Rect2(20, 562, 280, 34))
	_ready_note = Label.new()
	_ready_note.text = "%s est prêt." % _opponent()
	_ready_note.add_theme_font_size_override("font_size", _fs(10))
	_ready_note.add_theme_color_override("font_color", Color("d8e3ff"))
	_ready_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ready_note.visible = false
	_art.place(_ready_note, Rect2(20, 664, 280, 12))
	_continue_button = _below_button("Continuer", func():
		if _sent:
			return
		_sent = true
		_continue_button.disabled = true
		_continue_button.text = "En attente de %s…" % _opponent()
		Online.duel_send(Online.OP_CONTINUER), true, Rect2(50, 616, 220, 44))
	_refresh_in_place()


## Carte trouvée : elle montre sa réponse un instant, puis brûle au feu doré (FeuDore).
func _destroy_card(data: CardData, stamp_text: String) -> void:
	var card := _rounded(CARD.grow(-4), 16)
	var face := TextureRect.new()
	face.texture = CARD_FACE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(face)
	var text := Label.new()
	text.text = "%s\n\n%s\n\n%s" % [data.answer, data.reference, data.explanation]
	text.add_theme_font_override("font", P.TITLE_FONT)
	text.add_theme_font_size_override("font_size", _fs(14))
	text.add_theme_color_override("font_color", Painted.INK)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.offset_left = _fs(36)
	text.offset_right = -_fs(36)
	text.offset_top = _fs(40)
	text.offset_bottom = -_fs(60)
	face.add_child(text)
	card.modulate.a = 0.0
	var stamp := _stamp(stamp_text)
	var t := card.create_tween()
	t.tween_property(card, "modulate:a", 1.0, 0.25)
	t.tween_interval(1.4)
	t.tween_callback(func():
		await FeuDore.burn(card, float(_fs(16))).consumed
		if not is_instance_valid(stamp):
			return
		stamp.visible = true
		stamp.scale = Vector2(1.6, 1.6)
		var st := stamp.create_tween().set_parallel()
		st.tween_property(stamp, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		st.tween_property(stamp, "modulate:a", 1.0, 0.2))


func _stamp(text: String) -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.place(holder, Rect2(20, 330, 280, 60))
	var stamp := PanelContainer.new()
	var ss := P.box(P.FRAMBOISE, _fs(8), _fs(12), _fs(5))
	ss.border_color = Color("ffd34d")
	ss.set_border_width_all(maxi(2, _fs(2)))
	stamp.add_theme_stylebox_override("panel", ss)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.rotation_degrees = -8
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", P.TITLE_FONT)
	l.add_theme_font_size_override("font_size", _fs(15))
	l.add_theme_color_override("font_color", P.CREAM)
	stamp.add_child(l)
	holder.add_child(stamp)
	stamp.visible = false
	stamp.modulate.a = 0.0
	stamp.resized.connect(func(): stamp.pivot_offset = stamp.size / 2)
	return stamp


# ---------------------------------------------------------------- Fin

func _show_end() -> void:
	var fin_v = view.get("fin")
	var fin: Dictionary = fin_v if fin_v is Dictionary else {}
	var won: bool = fin.get("gagne", false)
	var reason := str(fin.get("raison", "cartes"))
	_base("", true)
	_ribbon("Fin de la partie")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _fs(4))
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parchment_patch()
	_art.place(v, Rect2(QUESTION.position, Vector2(QUESTION.size.x, ANSWERS.end.y - QUESTION.position.y)))
	v.add_child(_ink("Victoire !" if won else "%s gagne" % _opponent(), 28 if won else 22, Color("b5650d") if won else Painted.INK, true))
	var why_win := {"cartes": "%s n'a plus de cartes.", "abandon": "%s a abandonné la partie.", "deconnexion": "%s n'est pas revenu à temps."}
	var why_lose := {"cartes": "Tu n'as plus de cartes.", "abandon": "Tu as abandonné la partie.", "deconnexion": "Tu n'es pas revenu à temps."}
	v.add_child(_ink((str(why_win.get(reason, "%s a perdu.")) % _opponent()) if won else str(why_lose.get(reason, "")), 11, Color("6b4a24"), false))
	if not won:
		var left := int(view.get("mainAdverse", 0))
		if left > 0:
			v.add_child(_ink("Ses %d cartes survivantes gardent leur secret." % left if left > 1 else "Sa carte survivante garde son secret.", 10, Color("6b4a24"), false))
	var gain := int(fin.get("gain", _stake() if won else -_stake()))
	v.add_child(_recap("Mise remportée" if won else "Mise perdue", "+%d talents" % gain if won else "−%d talents" % absi(gain), Color("1d7a47") if won else Color("b3261e")))
	v.add_child(_recap("Tes talents", str(int(fin.get("talents", Online.talents()))), Color("8a5a00")))
	var xp := int(fin.get("xp", 0))
	v.add_child(_recap("Expérience", "+%d XP" % xp if xp > 0 else "0 XP", Color("0e6e69")))
	var level_now := int(fin.get("niveau", 0))
	if level_now > int(fin.get("niveauAvant", level_now)):
		v.add_child(_ink("Niveau %d atteint : %s" % [level_now, Progression.rank(level_now)], 13, Color("b5650d"), true))
	var link := Button.new()
	link.text = "Voir les cartes détruites"
	link.flat = true
	link.focus_mode = Control.FOCUS_NONE
	link.add_theme_font_override("font", P.body_font(900))
	link.add_theme_font_size_override("font_size", _fs(11))
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		link.add_theme_color_override(s, Color("8a3c12"))
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		link.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	link.pressed.connect(_show_destroyed)
	v.add_child(link)

	_rematch_note = Label.new()
	_rematch_note.add_theme_font_override("font", P.TITLE_FONT)
	_rematch_note.add_theme_font_size_override("font_size", _fs(11))
	_rematch_note.add_theme_color_override("font_color", Color("ffd76a"))
	_rematch_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_rematch_note.add_theme_constant_override("outline_size", _fs(2))
	_rematch_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_art.place(_rematch_note, Rect2(20, 560, 280, 18))
	_rematch_button = _below_button("Revanche pour %d talents" % _stake(), _rematch, true, Rect2(40, 580, 240, 42))
	_below_button("Retour à l'accueil", _leave, false, Rect2(60, 630, 200, 36))
	_update_rematch()


func _ink(text: String, img_px: float, color: Color, title: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", P.TITLE_FONT if title else P.body_font(800))
	l.add_theme_font_size_override("font_size", _fs(img_px))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _recap(caption: String, value: String, color: Color) -> Control:
	var row := PanelContainer.new()
	var st := P.box(Painted.SLOT, _fs(8), _fs(10), _fs(4))
	st.border_color = Color("d3a85a")
	st.set_border_width_all(maxi(1, _fs(1)))
	row.add_theme_stylebox_override("panel", st)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var c := _ink(caption, 12, Painted.INK, false)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)
	var v := _ink(value, 14, color, true)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(v)
	return row


func _update_rematch() -> void:
	var r = view.get("revanche")
	if not r is Dictionary:
		_rematch_button.visible = false
		_rematch_note.text = ""
		return
	var possible: bool = r.get("possible", false)
	var they: bool = r.get("adversaire", false)
	var me: bool = r.get("moi", false)
	_rematch_button.visible = true
	if not possible:
		_rematch_note.text = "%s est parti." % _opponent() if not _opponent_present() else "La revanche n'est plus possible."
		_rematch_button.disabled = true
		_rematch_button.text = "Revanche impossible"
		return
	_rematch_note.text = "%s veut sa revanche !" % _opponent() if they else "Même difficulté, même mise : les deux doivent accepter."
	_rematch_button.disabled = me
	_rematch_button.text = "En attente de %s…" % _opponent() if me else "Revanche pour %d talents" % _stake()
	if Online.talents() < _stake() and not me:
		_rematch_button.disabled = true
		_rematch_button.text = "Il te faut %d talents" % _stake()


func _opponent_present() -> bool:
	var a = view.get("adversaire")
	return a is Dictionary and a.get("present", false)


func _rematch() -> void:
	if _sent:
		return
	_sent = true
	Online.duel_send(Online.OP_REVANCHE, {"accepte": true})
	_rematch_button.disabled = true
	_rematch_button.text = "En attente de %s…" % _opponent()


func _show_destroyed() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.15, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.add_child(dim)
	var m := P.margins(16, 50, 16, 20)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(m)
	var col := P.vbox(12)
	m.add_child(col)
	col.add_child(P.title("Cartes détruites", 30, Color("ffd76a"), HORIZONTAL_ALIGNMENT_LEFT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := P.vbox(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var destroyed: Array = view.get("detruites", [[], []])
	for p in destroyed.size():
		for d in destroyed[p]:
			if not d is Dictionary:
				continue
			var data := CardData.from_dict(d)
			var card := PanelContainer.new()
			var cs := P.box(Painted.PARCHMENT, P.px(14), P.px(14), P.px(12))
			cs.border_color = Color("c99a3c")
			cs.set_border_width_all(P.px(2))
			card.add_theme_stylebox_override("panel", cs)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var v := P.vbox(6)
			card.add_child(v)
			var owner_text := "Ta carte" if p == 0 else "Carte de %s" % _opponent()
			v.add_child(P.label("%s, %s" % [owner_text, data.category_label().to_lower()], 12, Color("6b4a24"), 800, HORIZONTAL_ALIGNMENT_LEFT))
			v.add_child(P.label(data.question, 15, Painted.INK, 900, HORIZONTAL_ALIGNMENT_LEFT))
			v.add_child(P.title(data.answer, 19, Color("1d7a47"), HORIZONTAL_ALIGNMENT_LEFT))
			v.add_child(P.title(data.reference, 14, Color("8a3c12"), HORIZONTAL_ALIGNMENT_LEFT))
			list.add_child(card)
	if list.get_child_count() == 0:
		list.add_child(P.label("Aucune carte détruite.", 16, Color("c9d6f5")))
	col.add_child(Painted.navy_button("Retour", dim.queue_free, P.px(54), P.px(17)))


func _show_cancelled() -> void:
	var reasons := {
		"deux_deconnectes": "Vous avez été déconnectés tous les deux : chacun récupère sa mise.",
		"talents": "Un joueur n'avait plus assez de talents pour la mise.",
		"adversaire_absent": "Ton adversaire n'est pas arrivé. Aucune mise n'a été prise.",
		"createur_parti": "La partie a été annulée par celui qui l'a créée.",
		"personne": "Personne n'a rejoint la partie à temps.",
	}
	_base("")
	_ribbon("Partie annulée")
	_parchment_message("Partie annulée", str(reasons.get(str(view.get("annulation", "")), "La partie a été annulée.")))
	_below_button("Retour à l'accueil", _leave, true, Rect2(40, 600, 240, 46))


# ---------------------------------------------------------------- Déconnexions

func _overlay_panel(layer: Control) -> VBoxContainer:
	var box := PanelContainer.new()
	var st := P.box(Color(0.03, 0.09, 0.27, 0.97), P.px(26), P.px(20), P.px(22))
	st.border_color = Color("c99a3c")
	st.set_border_width_all(P.px(2))
	box.add_theme_stylebox_override("panel", st)
	box.anchor_left = 0.06
	box.anchor_right = 0.94
	box.anchor_top = 0.45
	box.anchor_bottom = 0.45
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(box)
	var v := P.vbox(14)
	box.add_child(v)
	return v


func _update_pause() -> void:
	var pause = view.get("pause")
	var away: bool = pause is Dictionary and pause.get("adversaireAbsent", false)
	if not away:
		if is_instance_valid(_pause_layer):
			_pause_layer.queue_free()
		_pause_layer = null
		return
	var seconds := int(pause.get("reconnexion", 0))
	if not is_instance_valid(_pause_layer):
		_pause_layer = ColorRect.new()
		(_pause_layer as ColorRect).color = Color(0.02, 0.04, 0.12, 0.78)
		_pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
		_top.add_child(_pause_layer)
		var v := _overlay_panel(_pause_layer)
		var face := G.avatar(_opponent(), Color("5b4f7d"), 84, Color(1, 1, 1, 0.35))
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		face.modulate = Color(1, 1, 1, 0.75)
		v.add_child(face)
		v.add_child(P.title("%s a perdu la connexion" % _opponent(), 26, P.CREAM))
		v.add_child(P.label("La partie est en pause, les minuteurs sont arrêtés.", 14, Color("c9d6f5"), 800))
		_pause_ring = Countdown.new()
		_pause_ring.custom_minimum_size = Vector2(P.px(120), P.px(120))
		_pause_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_pause_ring.show_number = true
		v.add_child(_pause_ring)
		v.add_child(P.label("S'il ne revient pas à temps, tu gagnes la partie et les deux mises.", 14, Color("ffe7a6"), 800))
	_pause_ring.set_time(seconds, 30.0)


## Ce téléphone a perdu la connexion : Online se reconnecte et rejoint la partie.
func _on_link(lost: bool) -> void:
	if is_instance_valid(_link_layer):
		_link_layer.queue_free()
	_link_layer = null
	if not lost:
		return
	_link_layer = ColorRect.new()
	(_link_layer as ColorRect).color = Color(0.02, 0.04, 0.12, 0.85)
	_link_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_link_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_top.add_child(_link_layer)
	var v := _overlay_panel(_link_layer)
	var gone := Online.duel_match_id.is_empty()
	v.add_child(P.title("Connexion perdue" if not gone else "Impossible de revenir", 30, Color("ffd76a")))
	v.add_child(P.label("On essaie de te ramener dans la partie. Tu as 30 secondes." if not gone
		else "La partie a continué sans toi. Vérifie ta connexion à Internet.", 16, Color("d8e3ff"), 800))
	if gone:
		v.add_child(Painted.gold_button("Retour à l'accueil", _to_menu, P.px(58), P.px(20)))


# ---------------------------------------------------------------- Quitter

## Toucher le minuteur (ou le bouton retour d'Android) propose d'abandonner.
func _ask_quit() -> void:
	var step := str(view.get("etape", ""))
	if step in ["finie", "annulee", "attente", ""] or (step == "resultat" and view.get("fin") != null):
		_leave()
		return
	if _quit_box:
		return
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.12, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.add_child(dim)
	_quit_box = dim
	var v := _overlay_panel(dim)
	v.add_child(P.title("Abandonner la partie ?", 30, Color("ffd76a")))
	v.add_child(P.label("Ta mise de %d talents va à %s, et tu ne gagnes pas d'XP." % [_stake(), _opponent()], 16, Color("d8e3ff")))
	v.add_child(Painted.gold_button("Continuer la partie", func():
		_quit_box.queue_free()
		_quit_box = null, P.px(58), P.px(20)))
	v.add_child(Painted.navy_button("Abandonner", func():
		_quit_box.queue_free()
		_quit_box = null
		Online.duel_send(Online.OP_ABANDONNER), P.px(50), P.px(17)))


func _leave() -> void:
	await Online.duel_leave()
	_to_menu()


func _to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_ask_quit()


## Minuteur rond doré, posé sur celui de l'image (rouge quand il reste peu de temps).
class Countdown extends Control:
	var value := 1.0
	var number := ""
	var show_number := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_time(left: float, total: float) -> void:
		value = clampf(left / total, 0.0, 1.0)
		number = str(int(ceil(left)))
		queue_redraw()

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		var w := r * 0.16
		draw_circle(c, r, Color("0a1638"))
		draw_arc(c, r - w / 2, 0, TAU, 96, Color(1, 1, 1, 0.12), w, true)
		var urgent := value <= 0.27
		var col := Color("ff6b6b") if urgent else Color("ffc84a")
		if value > 0:
			draw_arc(c, r - w / 2, -PI / 2, -PI / 2 + TAU * value, 96, col, w, true)
		var font := UiTheme.TITLE_FONT
		var fs := int(r * (0.8 if show_number else 0.5))
		var text := number if show_number else "VS"
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, Vector2(c.x - ts.x / 2, c.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col if show_number else Color("ffd76a"))


## Halo doré qui bat autour de l'avatar du joueur qui doit agir.
class Halo extends Control:
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		var k := 0.5 + 0.5 * sin(_t * 4.0)
		draw_circle(c, r, Color(1, 0.82, 0.3, 0.18 + 0.2 * k))
		draw_arc(c, r * 0.82, 0, TAU, 64, Color(1, 0.85, 0.35, 0.9), r * 0.1, true)
