extends Control
## Arcade solo : une partie contre le Scribe, jouée sur le serveur (server/src/arcade.ts).
## Maquettes « le Scribe répond à ta carte », « victoire », « défaite » ; les autres écrans
## reprennent ceux de la partie à deux (carte qu'on lit et qu'on touche).
##
## Le client n'invente rien : il envoie ses choix (RPC « arcade ») et affiche ce que le
## serveur répond. Le joueur est l'indice 0 du duel, le Scribe l'indice 1.

const P := preload("res://scripts/ui/ui_theme.gd")
const Map := preload("res://scripts/ui/adventure_map.gd")
const ADVENTURE_PATH := "res://data/aventure.json"
const STARTER_TIME := 20.0
const CHOOSE_TIME := 20.0
const ANSWER_TIME := 30.0

enum Step { STARTER, WAIT, CHOOSE, AI_ANSWERS, ANSWER, RESULT, END }

var view: Dictionary = {}  ## Dernière vue envoyée par le serveur.
var step := Step.WAIT
var fin: Dictionary = {}

var _busy := false
var _hand: Array[CardInPlay] = []
var _rng := RandomNumberGenerator.new()
var _selected := -1
var _card: CardView
var _minis: Array = []
var _hand_area: Control
var _play_button: Button
var _level_names := {}

# Minuteur
var _time_left := 0.0
var _time_total := 0.0
var _on_timeout := Callable()
var _rings: Array = []

# Calques
var _screen: Control
var _top: Control
var _quit_box: Control


func _ready() -> void:
	theme = P.get_theme()
	_rng.randomize()
	var data = JSON.parse_string(FileAccess.get_file_as_string(ADVENTURE_PATH))
	if data is Dictionary:
		for ch in data.get("chapitres", []):
			for l in ch.get("niveaux", []):
				_level_names[int(l["id"])] = str(l["nom"])
	P.night_background(self)
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)
	_top = Control.new()
	_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	var quit := P.button("×", _ask_quit, 20, "GhostButton")
	quit.custom_minimum_size = Vector2(P.px(34), P.px(34))
	quit.position = Vector2(P.px(8), P.px(6))
	quit.size = quit.custom_minimum_size
	_top.add_child(quit)

	var start: Dictionary = Session.arcade_start
	Session.arcade_start = {}
	if not start.has("vue"):
		_to_map.call_deferred()
		return
	_apply(start)
	_show_starter()


func _process(delta: float) -> void:
	if _on_timeout.is_null():
		return
	_time_left = maxf(_time_left - delta, 0.0)
	for r in _rings:
		if is_instance_valid(r):
			r.set_time(_time_left, _time_total)
	if _time_left <= 0.0:
		var cb := _on_timeout
		_stop_timer()
		cb.call()


# ---------------------------------------------------------------- Échanges avec le serveur

## Envoie une action ; renvoie la réponse, ou {} après avoir affiché l'erreur.
func _send(request: Dictionary) -> Dictionary:
	_busy = true
	var r := await Online.arcade(request)
	_busy = false
	if r.has("erreur"):
		_show_error(str(r["erreur"]))
		return {}
	_apply(r)
	return r


func _apply(r: Dictionary) -> void:
	if r.get("vue") is Dictionary:
		view = r["vue"]
	if r.get("fin") is Dictionary:
		fin = r["fin"]
	_hand.clear()
	for c: Dictionary in view.get("main", []):
		var card := CardInPlay.new(CardData.from_dict(c.get("carte", {})), _rng)
		card.shown_wrongs.assign(c.get("fausses", []))
		card.reserve.clear()
		for i in int(c.get("reserve", 0)):
			card.reserve.append("?")
		_hand.append(card)


## Les cartes de l'arcade ne sont pas dans l'APK (réserve en ligne) : le serveur envoie leur
## texte, et la réponse seulement pour nos cartes ou pour une carte du Scribe trouvée.
func _guess_card() -> CardData:
	return CardData.from_dict(view.get("carte", {}) if view.get("carte") is Dictionary else {})


func _level() -> int:
	return int(view.get("niveau", 1))


func _difficulty() -> String:
	return str(view.get("difficulte", "lait"))


func _stake() -> int:
	return int(view.get("mise", 0))


## Coup suivant : le Scribe pose sa carte, ou c'est au joueur de choisir.
func _next() -> void:
	if view.get("etape") == "finie":
		_show_end()
		return
	step = Step.WAIT
	var r := await _send({"action": "suite"})
	if r.is_empty():
		return
	if r.has("ia"):
		_flash("Le Scribe pose une carte.")
		await get_tree().create_timer(1.0).timeout
		_begin_answer()
	else:
		_begin_choose()


# ---------------------------------------------------------------- Minuteur et écran

func _timer_ring() -> Shapes.TimerRing:
	var r := Shapes.TimerRing.new()
	r.set_time(_time_left, maxf(_time_total, 1.0))
	_rings.append(r)
	return r


func _start_timer(seconds: float, on_timeout: Callable) -> void:
	_time_total = seconds
	_time_left = seconds
	_on_timeout = on_timeout
	for r in _rings:
		if is_instance_valid(r):
			r.set_time(_time_left, _time_total)


func _stop_timer() -> void:
	_on_timeout = Callable()


func _new_screen(top: float = 44, sides: float = 16, bottom: float = 18) -> VBoxContainer:
	_rings.clear()
	for child in _screen.get_children():
		child.queue_free()
	var m := P.margins(sides, top, sides, bottom)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(m)
	var v := P.vbox(12)
	m.add_child(v)
	return v


## Toi à gauche, le Scribe à droite, cartes restantes sous les noms, minuteur au milieu.
func _top_bar(with_timer: bool = true) -> HBoxContainer:
	var bar := P.hbox(8)
	var counts := [view.get("main", []).size(), int(view.get("mainIA", 0))]
	for p in [0, 1]:
		var block := P.hbox(8)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if p == 1:
			block.alignment = BoxContainer.ALIGNMENT_END
		var av := P.avatar(Online.username, P.TEAL, 40) if p == 0 else Map.scribe_avatar(40)
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var info := P.vbox(3)
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var n := P.label("Toi" if p == 0 else "Le Scribe", 15, P.CREAM, 900, HORIZONTAL_ALIGNMENT_RIGHT if p == 1 else HORIZONTAL_ALIGNMENT_LEFT)
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		info.add_child(n)
		var row := P.hbox(3)
		row.alignment = BoxContainer.ALIGNMENT_END if p == 1 else BoxContainer.ALIGNMENT_BEGIN
		for i in counts[p]:
			var c := ColorRect.new()
			c.color = P.YELLOW
			c.custom_minimum_size = Vector2(P.px(10), P.px(14))
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(c)
		info.add_child(row)
		if p == 0:
			block.add_child(av)
			block.add_child(info)
		else:
			block.add_child(info)
			block.add_child(av)
		bar.add_child(block)
		if p == 0:
			if with_timer:
				bar.add_child(_timer_ring())
			else:
				bar.add_child(P.spacer(0))
	return bar


# ---------------------------------------------------------------- Question de départ

func _show_starter() -> void:
	step = Step.STARTER
	var d: Dictionary = view.get("depart", {}) if view.get("depart") is Dictionary else {}
	var col := _new_screen(52, 16, 18)
	col.add_child(_top_bar())
	col.add_child(P.spacer(8))
	col.add_child(P.title("Question de départ", 26, P.YELLOW))
	col.add_child(P.label("Le premier qui répond juste commence. Le Scribe cherche aussi.", 14, P.LILAC))
	var bubble := Shapes.SpeechBubble.new("Question")
	bubble.add_child(P.label(str(d.get("question", "")), 20, P.NIGHT, 900))
	col.add_child(bubble)
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", P.box(P.FRAMBOISE, P.px(18), P.px(8), P.px(8)))
	band.size_flags_vertical = Control.SIZE_EXPAND_FILL
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := P.vbox(8)
	band.add_child(rows)
	var buttons := {}
	var options: Array = d.get("propositions", [])
	for i in options.size():
		var option: String = options[i]
		var b := CardView.make_answer_button(CardView.LETTERS[i], option, 54)
		b.pressed.connect(func(): _on_starter_answer(option, buttons))
		rows.add_child(b)
		buttons[option] = b
	col.add_child(band)
	_start_timer(STARTER_TIME, func(): _on_starter_answer("", buttons))


func _on_starter_answer(choice: String, buttons: Dictionary) -> void:
	if step != Step.STARTER or _busy:
		return
	step = Step.WAIT
	_stop_timer()
	for b in buttons.values():
		b.disabled = true
	var r := await _send({"action": "depart", "choix": choice})
	if r.is_empty():
		return
	if r.get("nouvelle", false):
		_flash("Personne n'a répondu.\nNouvelle question.")
		await get_tree().create_timer(1.6).timeout
		_show_starter()
		return
	var right := str(r.get("bonne", ""))
	if buttons.has(right):
		CardView.tint(buttons[right], true)
	if not choice.is_empty() and choice != right and buttons.has(choice):
		CardView.tint(buttons[choice], false)
	var me_first := int(r.get("commence", 0)) == 0
	var msg := ""
	if r.get("iaPremiere", false):
		var secs := str(r.get("iaTemps", 0)).replace(".", ",")
		msg = "Le Scribe a trouvé en %s s.\nIl commence." % secs if r.get("iaJuste", false) \
			else "Le Scribe s'est trompé.\nTu commences."
	else:
		msg = "Bien joué !\nTu commences." if me_first else "Raté.\nLe Scribe commence."
	_flash(msg)
	await get_tree().create_timer(2.4).timeout
	_next()


# ---------------------------------------------------------------- Choisir la carte à poser

func _begin_choose() -> void:
	step = Step.CHOOSE
	_selected = -1
	var col := _new_screen(44, 20, 0)
	var head := P.hbox(10)
	var titles := P.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(P.title("À toi de poser", 22, P.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	titles.add_child(P.label("Choisis la carte que le Scribe devra deviner", 14, P.LILAC, 800, HORIZONTAL_ALIGNMENT_LEFT))
	head.add_child(titles)
	head.add_child(_timer_ring())
	col.add_child(head)

	_card = CardView.new()
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_card)

	var actions := P.hbox(12)
	var other := P.button("Une autre", _next_card, 19, "GhostButton")
	other.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(other)
	_play_button = P.button("Poser cette carte", _play_selected, 21)
	_play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_button.size_flags_stretch_ratio = 1.7
	_play_button.disabled = true
	actions.add_child(_play_button)
	col.add_child(actions)

	_hand_area = Control.new()
	_hand_area.custom_minimum_size = Vector2(0, P.px(118))
	_hand_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hand_area)
	_minis.clear()
	var color := P.difficulty_color(_difficulty())
	for i in _hand.size():
		var mini := Shapes.MiniCard.new(color)
		mini.size = mini.custom_minimum_size
		mini.pressed.connect(_select_card.bind(i))
		_hand_area.add_child(mini)
		_minis.append(mini)
	_hand_area.resized.connect(_layout_hand)
	_layout_hand.call_deferred()
	_start_timer(CHOOSE_TIME, _play.bind(-1))


func _layout_hand() -> void:
	if not is_instance_valid(_hand_area):
		return
	var n := _minis.size()
	for i in n:
		var m: Control = _minis[i]
		var off := i - (n - 1) / 2.0
		var target := Vector2(_hand_area.size.x / 2 + off * P.px(68) - m.size.x / 2, P.px(22) + absf(off) * P.px(6))
		var rot := off * 6.0
		if i == _selected:
			target.y -= P.px(24)
			rot = 0.0
		var t := m.create_tween().set_parallel()
		t.tween_property(m, "position", target, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(m, "rotation_degrees", rot, 0.25)


func _select_card(index: int) -> void:
	if step != Step.CHOOSE or index >= _hand.size():
		return
	_selected = index
	for i in _minis.size():
		_minis[i].set_selected(i == index)
	_layout_hand()
	var card := _hand[index]
	_card.flip(func(): _card.show_owner(card, ""))
	_play_button.disabled = false


func _next_card() -> void:
	if not _hand.is_empty():
		_select_card((_selected + 1) % _hand.size())


func _play_selected() -> void:
	if _selected >= 0:
		_play(_selected)


func _play(index: int) -> void:
	if step != Step.CHOOSE or _busy:
		return
	step = Step.AI_ANSWERS
	_stop_timer()
	_play_button.disabled = true
	var before := {}
	for c in _hand:
		before[c.data.id] = [c.option_count(), c.reserve.size()]
	var r := await _send({"action": "jouer", "index": index})
	if r.is_empty():
		return
	var coup: Dictionary = r["coup"]
	if coup.get("auHasard", false):
		_flash("Temps écoulé : une carte a été posée au hasard.")
		await get_tree().create_timer(1.6).timeout
	_show_ai_answering(coup, before)


# ---------------------------------------------------------------- Le Scribe répond à ta carte

func _show_ai_answering(coup: Dictionary, before: Dictionary) -> void:
	step = Step.AI_ANSWERS
	var data := CardData.from_dict(coup["carte"])
	var presented: Array[String] = []
	presented.assign(coup["presentees"])
	var choice := str(coup["choix"])
	var col := _new_screen(44, 16, 18)
	col.add_child(_top_bar(false))
	_card = CardView.new()
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_card)
	_card.show_owner_answering(data, presented, "Ta carte")
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", P.box(P.VIOLET, P.px(999), P.px(10), P.px(6)))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph := P.hbox(10)
	var av := Map.scribe_avatar(32)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(av)
	var status := P.label("Le Scribe réfléchit…", 15, P.CREAM, 900)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(status)
	ph.add_child(P.spacer(0))
	pill.add_child(ph)
	col.add_child(pill)

	# Il hésite sur une ou deux propositions, puis répond.
	var others := presented.filter(func(o): return o != choice)
	others.shuffle()
	var path: Array = others.slice(0, mini(others.size(), 1 + _rng.randi_range(0, 1)))
	path.append(choice)
	await get_tree().create_timer(0.6).timeout
	for o in path:
		_card.highlight_owner_row(o, CardView.Highlight.HESITATE)
		status.text = "Le Scribe hésite sur %s…" % CardView.LETTERS[presented.find(o)]
		await get_tree().create_timer(0.75).timeout
	var correct: bool = coup["juste"]
	_card.highlight_owner_row(choice, CardView.Highlight.RIGHT if correct else CardView.Highlight.WRONG)
	status.text = "Le Scribe répond %s." % CardView.LETTERS[presented.find(choice)]
	await get_tree().create_timer(1.1).timeout
	var info := {"correct": correct, "card": data, "owner": 0, "choice": choice, "timed_out": false}
	if before.has(data.id):
		info["before"] = before[data.id]
	_show_result(info)


# ---------------------------------------------------------------- Répondre à la carte du Scribe

func _begin_answer() -> void:
	step = Step.ANSWER
	var c: Dictionary = view.get("carte", {}) if view.get("carte") is Dictionary else {}
	var data := _guess_card()
	var presented: Array[String] = []
	presented.assign(c.get("propositions", []))
	var col := _new_screen(44, 16, 18)
	col.add_child(_top_bar())
	_card = CardView.new()
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card.answered.connect(_on_answer.bind(presented.size()))
	col.add_child(_card)
	col.add_child(P.label("Touche ta réponse sur la carte", 14, P.LILAC))
	_card.flip(func(): _card.show_question(data, presented, "", "La carte du Scribe"))
	_start_timer(ANSWER_TIME, _on_answer.bind("", presented.size()))


func _on_answer(choice: String, options_before: int) -> void:
	if step != Step.ANSWER or _busy:
		return
	step = Step.WAIT
	_stop_timer()
	_card.set_answers_enabled(false)
	var data := _guess_card()
	var r := await _send({"action": "repondre", "choix": choice})
	if r.is_empty():
		return
	var coup: Dictionary = r["coup"]
	var correct: bool = coup["juste"]
	if coup.get("carte") is Dictionary:  # Carte trouvée : le serveur la révèle.
		data = CardData.from_dict(coup["carte"])
	var timed_out: bool = coup.get("tempsEcoule", false)
	if not timed_out:
		_card.mark_answer(choice, correct)
		await get_tree().create_timer(0.8).timeout
	_show_result({"correct": correct, "card": data, "owner": 1, "choice": choice, "timed_out": timed_out, "options_before": options_before})


# ---------------------------------------------------------------- Résultat d'un coup

func _show_result(info: Dictionary) -> void:
	step = Step.RESULT
	var data: CardData = info["card"]
	var correct: bool = info["correct"]
	var mine: bool = info["owner"] == 0
	var col := _new_screen(54, 18, 24)
	var headline := ""
	if mine:
		headline = "Le Scribe a trouvé !" if correct else "Le Scribe s'est trompé !"
	else:
		headline = "Bonne réponse !" if correct else ("Temps écoulé !" if info["timed_out"] else "Raté !")
	var good_for_me := correct != mine
	var title := P.title(headline, 36, P.YELLOW if good_for_me else Color("ff8fa3"))
	title.add_theme_color_override("font_shadow_color", P.EMBER if good_for_me else P.VIOLET)
	title.add_theme_constant_override("shadow_offset_y", P.px(4))
	title.add_theme_constant_override("shadow_offset_x", 0)
	col.add_child(title)

	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stage)
	_card = CardView.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_card)

	if correct:
		_card.flip(func(): _card.show_reveal(data, Session.bank.story_title(data.story)))
		var stamp := PanelContainer.new()
		var ss := P.box(P.FRAMBOISE, P.px(10), P.px(12), P.px(6))
		ss.border_color = P.YELLOW
		ss.set_border_width_all(P.px(3))
		stamp.add_theme_stylebox_override("panel", ss)
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stamp_text := P.title("Ta carte est détruite" if mine else "Carte du Scribe détruite", 16, P.CREAM)
		stamp_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		stamp.add_child(stamp_text)
		# Sur l'illustration : le parchemin dessous porte le texte du récit.
		stamp.anchor_left = 0.5
		stamp.anchor_right = 0.5
		stamp.anchor_top = 0.2
		stamp.anchor_bottom = 0.2
		stamp.grow_horizontal = Control.GROW_DIRECTION_BOTH
		stamp.grow_vertical = Control.GROW_DIRECTION_BOTH
		stamp.rotation_degrees = -8
		stamp.resized.connect(func(): stamp.pivot_offset = stamp.size / 2)
		stamp.scale = Vector2(1.6, 1.6)
		stamp.modulate.a = 0
		stage.add_child(stamp)
		var t := stamp.create_tween().set_parallel()
		t.tween_property(stamp, "scale", Vector2.ONE, 0.3).set_delay(0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(stamp, "modulate:a", 1.0, 0.2).set_delay(0.6)
	else:
		var note := PanelContainer.new()
		note.add_theme_stylebox_override("panel", P.box(P.CREAM, P.px(18), P.px(16), P.px(14)))
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.anchor_left = 0.08
		note.anchor_right = 0.92
		note.anchor_top = 0.5
		note.anchor_bottom = 0.5
		note.grow_vertical = Control.GROW_DIRECTION_BOTH
		var nv := P.vbox(6)
		var choice: String = info["choice"]
		if not choice.is_empty():
			nv.add_child(P.label("« %s » n'est pas la bonne réponse." % choice, 16, P.NIGHT, 900))
		nv.add_child(P.title("Ta carte te revient." if mine else "La carte retourne chez le Scribe.", 20, P.VIOLET))
		nv.add_child(P.label(_weakened_text(info), 15, Color("6b5a8e"), 800))
		note.add_child(nv)
		stage.add_child(note)

	var go := P.button("Continuer", func():
		if step != Step.RESULT:
			return
		_next(), 23)
	go.custom_minimum_size = Vector2(0, P.px(62))
	col.add_child(go)


func _weakened_text(info: Dictionary) -> String:
	if info["owner"] == 0:
		var id: String = info["card"].id
		for c in _hand:
			if c.data.id == id:
				var now := c.option_count()
				var was: Array = info.get("before", [now, c.reserve.size()])
				if now == int(was[0]):
					return "Elle garde 2 réponses, mais l'une d'elles change." if c.reserve.size() < int(was[1]) else "Elle garde ses 2 réponses."
				return "Elle n'a plus que %d réponses." % now
		return ""
	var before: int = info.get("options_before", 4)
	return "Elle n'a plus que %d réponses." % (before - 1) if before > 2 else "Elle garde 2 réponses, peut-être pas les mêmes."


# ---------------------------------------------------------------- Fin

func _show_end() -> void:
	step = Step.END
	_stop_timer()
	var won: bool = fin.get("gagne", int(view.get("gagnant", -1)) == 0)
	var col := _new_screen(70, 20, 22)
	if won:
		var stars := P.hbox(10)
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		var lit: int = fin.get("etoiles", []).size()
		for i in 3:
			var big: bool = fin.get("nouvelleEtoile", false) and i == lit - 1
			var s := Shapes.Stars.new(1 if i < lit else 0, 1, 96 if big else 66)
			s.off_color = Color(1, 1, 1, 0.14)
			s.size_flags_vertical = Control.SIZE_SHRINK_END
			stars.add_child(s)
		col.add_child(stars)
		if fin.get("nouvelleEtoile", false):
			var tag := PanelContainer.new()
			tag.add_theme_stylebox_override("panel", P.box(P.GREEN, P.px(999), P.px(14), P.px(4)))
			tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tl := P.label("Nouvelle étoile : %s" % CardData.DIFFICULTY_LABELS.get(_difficulty(), ""), 14, P.NIGHT, 900)
			tl.autowrap_mode = TextServer.AUTOWRAP_OFF
			tag.add_child(tl)
			col.add_child(tag)
		var t := P.title("Victoire !", 52, P.YELLOW)
		t.add_theme_color_override("font_shadow_color", P.EMBER)
		t.add_theme_constant_override("shadow_offset_y", P.px(5))
		t.add_theme_constant_override("shadow_offset_x", 0)
		col.add_child(t)
		col.add_child(P.label("Le Scribe n'a plus de cartes.\nNiveau %d : %s" % [_level(), _level_name(_level())], 17, P.LILAC))
	else:
		var av := Map.scribe_avatar(110)
		av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(av)
		col.add_child(P.title("Le Scribe gagne", 44, P.CREAM))
		var left := int(view.get("mainIA", 0))
		var why := "Tu as abandonné la partie." if not view.get("main", []).is_empty() else "Tu n'as plus de cartes."
		var secret := "Ses %d cartes survivantes gardent leur secret." % left if left > 1 else "Sa carte survivante garde son secret."
		col.add_child(P.label("%s\n%s" % [why, secret], 17, P.LILAC))

	var recap := PanelContainer.new()
	recap.add_theme_stylebox_override("panel", P.box(P.VIOLET, P.px(22), P.px(16), P.px(6)))
	recap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rv := P.vbox(0)
	var gain := int(fin.get("gain", _stake() if won else -_stake()))
	rv.add_child(_recap_row("Mise remportée" if won else "Mise perdue", "+%d talents" % gain if won else "−%d talents" % absi(gain), P.GREEN if won else Color("ff8fb8")))
	rv.add_child(_recap_row("Tes talents", str(int(fin.get("talents", Online.talents()))), P.YELLOW))
	var xp := int(fin.get("xp", 0))
	rv.add_child(_recap_row("Expérience", "+%d XP" % xp if xp > 0 else "0 XP (abandon)", P.TEAL.lightened(0.3)))
	recap.add_child(rv)
	col.add_child(P.spacer(10))
	col.add_child(recap)
	var level_now := int(fin.get("niveau", 0))
	if level_now > int(fin.get("niveauAvant", level_now)):
		var up := PanelContainer.new()
		up.add_theme_stylebox_override("panel", P.box(P.YELLOW, P.px(999), P.px(16), P.px(6)))
		up.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		up.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ul := P.title("Niveau %d atteint : %s" % [level_now, Progression.rank(level_now)], 18, P.NIGHT)
		ul.autowrap_mode = TextServer.AUTOWRAP_OFF
		up.add_child(ul)
		col.add_child(up)
		up.pivot_offset = Vector2(P.px(120), P.px(16))
		up.scale = Vector2(0.4, 0.4)
		var t := up.create_tween()
		t.tween_property(up, "scale", Vector2.ONE, 0.5).set_delay(0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	col.add_child(_link("Voir les cartes détruites", _show_destroyed))
	col.add_child(P.expander())

	var next_level := _level() + 1
	if won and _level_names.has(next_level):
		col.add_child(P.button("Niveau %d : %s" % [next_level, _level_names[next_level]], func():
			Session.arcade_open_level = next_level
			_to_map(), 22))
	elif not won:
		var again := P.button("Rejouer en %s : %d talents" % [CardData.DIFFICULTY_LABELS.get(_difficulty(), ""), _stake()], func(): pass, 22)
		again.pressed.connect(_replay.bind(again))
		again.disabled = Online.talents() < _stake()
		col.add_child(again)
	col.add_child(P.button("Retour à la carte", _to_map, 19, "GhostButton"))


func _recap_row(caption: String, value: String, color: Color) -> Control:
	var row := P.hbox(8)
	row.custom_minimum_size = Vector2(0, P.px(54))
	var c := P.label(caption, 16, P.CREAM, 800, HORIZONTAL_ALIGNMENT_LEFT)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)
	var v := P.title(value, 22, color, HORIZONTAL_ALIGNMENT_RIGHT)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	return row


func _replay(button: Button) -> void:
	button.disabled = true
	button.text = "Préparation de la partie…"
	var level := _level()
	var diff := _difficulty()
	var r := await Online.arcade({"action": "commencer", "niveau": level, "difficulte": diff})
	if r.has("erreur"):
		_show_error(str(r["erreur"]))
		return
	Session.arcade_start = r
	get_tree().reload_current_scene()


func _show_destroyed() -> void:
	var col := _new_screen(50, 16, 20)
	col.add_child(P.title("Cartes détruites", 30, P.YELLOW, HORIZONTAL_ALIGNMENT_LEFT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := P.vbox(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var destroyed: Array = view.get("detruites", [[], []])
	for p in 2:
		for d in destroyed[p]:
			if not d is Dictionary:
				continue
			var data := CardData.from_dict(d)
			var card := PanelContainer.new()
			var cs := P.box(P.CREAM, P.px(14), P.px(14), P.px(12))
			cs.border_color = P.difficulty_color(data.difficulty)
			cs.border_width_left = P.px(8)
			card.add_theme_stylebox_override("panel", cs)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var v := P.vbox(6)
			card.add_child(v)
			var owner := "Ta carte" if p == 0 else "Carte du Scribe"
			v.add_child(P.label("%s, %s" % [owner, data.category_label().to_lower()], 12, Color("6b5a8e"), 800, HORIZONTAL_ALIGNMENT_LEFT))
			v.add_child(P.label(data.question, 15, P.NIGHT, 900, HORIZONTAL_ALIGNMENT_LEFT))
			v.add_child(P.title(data.answer, 19, Color("1d7a47"), HORIZONTAL_ALIGNMENT_LEFT))
			v.add_child(P.title(data.reference, 14, P.FRAMBOISE, HORIZONTAL_ALIGNMENT_LEFT))
			list.add_child(card)
	if list.get_child_count() == 0:
		list.add_child(P.label("Aucune carte détruite.", 16, P.LILAC))
	col.add_child(P.button("Retour", _show_end, 18, "GhostButton"))


func _level_name(level: int) -> String:
	return str(_level_names.get(level, "Niveau %d" % level))


# ---------------------------------------------------------------- Commun

func _show_error(message: String) -> void:
	_stop_timer()
	step = Step.END
	var col := _new_screen(60, 24, 28)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(P.title("La partie est interrompue", 30, P.YELLOW))
	col.add_child(P.label(message, 16, P.LILAC))
	col.add_child(P.spacer(20))
	col.add_child(P.button("Retour à la carte", _to_map, 22))


func _flash(text: String) -> void:
	var box := PanelContainer.new()
	var s := P.box(P.NIGHT, P.px(18), P.px(18), P.px(14))
	s.border_color = P.YELLOW
	s.set_border_width_all(P.px(3))
	box.add_theme_stylebox_override("panel", s)
	box.anchor_left = 0.06
	box.anchor_right = 0.94
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(P.title(text, 20, P.CREAM))
	_top.add_child(box)
	var t := box.create_tween()
	t.tween_interval(1.8)
	t.tween_property(box, "modulate:a", 0.0, 0.4)
	t.tween_callback(box.queue_free)


func _link(text: String, on_pressed: Callable) -> Button:
	var b := P.button(text, on_pressed, 15)
	b.flat = true
	b.custom_minimum_size = Vector2(0, P.px(44))
	b.add_theme_font_override("font", P.body_font(900))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, P.CREAM)
	return b


## Le minuteur continue pendant la question : le serveur tient ses propres délais.
func _ask_quit() -> void:
	if step == Step.END:
		_to_map()
		return
	if _quit_box:
		return
	var dim := ColorRect.new()
	dim.color = Color(P.NIGHT, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.add_child(dim)
	_quit_box = dim
	var m := P.margins(28, 0, 28, 0)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(m)
	var v := P.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)
	v.add_child(P.title("Abandonner la partie ?", 32, P.YELLOW))
	v.add_child(P.label("Ta mise de %d talents est perdue." % _stake(), 16, P.LILAC))
	v.add_child(P.spacer(16))
	v.add_child(P.button("Continuer la partie", func():
		_quit_box.queue_free()
		_quit_box = null, 22))
	v.add_child(P.button("Abandonner", _abandon, 18, "GhostButton"))


func _abandon() -> void:
	if _quit_box:
		_quit_box.queue_free()
		_quit_box = null
	_stop_timer()
	step = Step.WAIT
	var r := await _send({"action": "abandonner"})
	if not r.is_empty():
		_show_end()


func _to_map() -> void:
	get_tree().change_scene_to_file("res://scenes/adventure.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_ask_quit()
