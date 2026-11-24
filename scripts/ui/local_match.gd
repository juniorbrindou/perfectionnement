extends Control
## Partie à deux sur le même téléphone (PRD §2 et §3.2), selon les maquettes validées :
## la carte occupe l'écran, la question et les réponses sont écrites dessus.
##
## Déroulement : question de départ en écran partagé → le poseur choisit une carte de
## sa main (10 s) → « Passe le téléphone » → l'autre répond en touchant la carte (15 s)
## → résultat → l'ancien répondant, qui tient déjà le téléphone, pose à son tour.

const P := preload("res://scripts/ui/ui_theme.gd")
const STARTER_TIME := 20.0
const CHOOSE_TIME := 20.0
const ANSWER_TIME := 30.0
const PLAYER_COLORS := [UiTheme.TEAL, UiTheme.FRAMBOISE]

enum Step { STARTER, PASS, CHOOSE, ANSWER, RESULT, END }

var duel: Duel
var step := Step.STARTER
var names: Array[String] = []

var _rng := RandomNumberGenerator.new()
var _starter_queue: Array = []
var _options_before := 0
var _reserve_before := 0
var _selected := -1
var _card: CardView
var _burning := false  ## La carte détruite brûle avant la suite.
var _minis: Array = []
var _hand_area: Control
var _play_button: Button

# Minuteur
var _time_left := 0.0
var _time_total := 0.0
var _on_timeout := Callable()
var _paused := false
var _rings: Array = []

# Calques
var _screen: Control
var _top: Control
var _quit_box: Control


func _ready() -> void:
	theme = P.get_theme()
	_rng.randomize()
	names = Session.player_names.duplicate()
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

	var pool := Session.bank.filter(Session.filter)
	var hands := DeckBuilder.deal(pool, LocalHistory.recent_ids(), _rng)
	duel = Duel.new(hands[0], hands[1], _rng)
	var ids: Array[String] = []
	for p in 2:
		for c in duel.hands[p]:
			ids.append(c.data.id)
	LocalHistory.record(ids)
	_show_starter()


func _process(delta: float) -> void:
	if _on_timeout.is_null() or _paused:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	for r in _rings:
		if is_instance_valid(r):
			r.set_time(_time_left, _time_total)
	if _time_left <= 0.0:
		var cb := _on_timeout
		_stop_timer()
		cb.call()


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


## Vide l'écran et renvoie une colonne aux marges des maquettes.
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


# ---------------------------------------------------------------- Question de départ

func _show_starter() -> void:
	step = Step.STARTER
	if _starter_queue.is_empty():
		_starter_queue = Session.bank.starters.duplicate()
		Rand.shuffle(_starter_queue, _rng)
	var starter := StarterRound.new(_starter_queue.pop_back(), _rng)
	var resolved := [false]
	var buttons: Array = [[], []]

	var col := _new_screen(0, 0, 0)
	col.add_theme_constant_override("separation", 0)
	for p in [1, 0]:  # Joueur 2 en haut (retourné), joueur 1 en bas.
		var half := Control.new()
		half.size_flags_vertical = Control.SIZE_EXPAND_FILL
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var margin := P.margins(14, 14, 14, 14)
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		half.add_child(margin)
		var v := P.vbox(8)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		margin.add_child(v)
		v.add_child(P.title(names[p], 20, P.YELLOW))
		var bubble := Shapes.SpeechBubble.new("Question de départ")
		bubble.add_child(P.label(starter.question.question, 17, P.NIGHT, 900))
		v.add_child(bubble)
		var band := PanelContainer.new()
		band.add_theme_stylebox_override("panel", P.box(P.FRAMBOISE, P.px(16), P.px(6), P.px(6)))
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rows := P.vbox(5)
		band.add_child(rows)
		for i in starter.options.size():
			var option: String = starter.options[i]
			var b := CardView.make_answer_button(CardView.LETTERS[i], option, 40)
			b.pressed.connect(func(): _on_starter_answer(starter, p, option, resolved, buttons))
			rows.add_child(b)
			buttons[p].append([b, option])
		v.add_child(band)
		col.add_child(half)
		if p == 1:
			# Les conteneurs annulent la rotation de leurs enfants : on tourne le contenu.
			margin.resized.connect(func(): margin.pivot_offset = margin.size / 2)
			margin.rotation = PI
			var middle := P.hbox(10)
			middle.alignment = BoxContainer.ALIGNMENT_CENTER
			middle.add_child(_line())
			middle.add_child(_timer_ring())
			middle.add_child(_line())
			col.add_child(middle)

	_start_timer(STARTER_TIME, func():
		if resolved[0]:
			return
		resolved[0] = true
		_flash("Personne n'a répondu.\nNouvelle question.")
		get_tree().create_timer(1.6).timeout.connect(_show_starter))


func _line() -> ColorRect:
	var l := ColorRect.new()
	l.color = P.YELLOW
	l.custom_minimum_size = Vector2(0, P.px(3))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _on_starter_answer(starter: StarterRound, player: int, choice: String, resolved: Array, buttons: Array) -> void:
	if resolved[0]:
		return
	resolved[0] = true
	_stop_timer()
	for p in 2:
		for pair in buttons[p]:
			var b: Button = pair[0]
			b.disabled = true
			if pair[1] == starter.question.answer:
				CardView.tint(b, true)
			elif pair[1] == choice and p == player:
				CardView.tint(b, false)
	var first := starter.resolve(player, choice)
	var msg := "%s a trouvé !" % names[player] if first == player else "Mauvaise réponse de %s." % names[player]
	_flash("%s\n%s commence." % [msg, names[first]])
	get_tree().create_timer(2.2).timeout.connect(func():
		duel.start_with(first)
		_show_pass(first, "Tu commences : choisis la carte à poser.", _begin_choose))


# ---------------------------------------------------------------- Passage du téléphone

## Un voile couvre l'écran ; il se lève quand le bon joueur a le téléphone.
func _show_pass(player: int, subtitle: String, next: Callable) -> void:
	step = Step.PASS
	_stop_timer()
	var veil := Control.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_top.add_child(veil)
	var bg := ColorRect.new()
	bg.color = P.VIOLET
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(bg)
	var rings := Shapes.RingPattern.new()
	rings.set_anchors_preset(Control.PRESET_FULL_RECT)
	rings.colors = [Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.04)]
	veil.add_child(rings)

	var m := P.margins(28, 0, 28, 0)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.add_child(m)
	var v := P.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)
	v.add_child(P.label("Passe le téléphone à", 18, P.LILAC))
	var av := P.avatar(names[player], PLAYER_COLORS[player], 96)
	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(av)
	v.add_child(P.title(names[player], 44, P.YELLOW))
	v.add_child(P.label(subtitle, 16, P.CREAM))
	v.add_child(P.spacer(30))
	var go := P.button("Je suis %s" % names[player], func(): pass, 23)
	go.custom_minimum_size = Vector2(0, P.px(64))
	go.pressed.connect(func():
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := veil.create_tween()
		t.tween_property(veil, "position:y", -veil.size.y, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_callback(veil.queue_free)
		next.call())
	v.add_child(go)


# ---------------------------------------------------------------- Choisir la carte à poser

func _begin_choose() -> void:
	step = Step.CHOOSE
	_selected = -1
	var poser := duel.poser
	var col := _new_screen(44, 20, 0)

	var head := P.hbox(10)
	var titles := P.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(P.title("À toi, %s" % names[poser], 22, P.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	titles.add_child(P.label("Choisis la carte que %s devra deviner" % names[duel.answerer()], 14, P.LILAC, 800, HORIZONTAL_ALIGNMENT_LEFT))
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
	var color := P.difficulty_color(Session.filter.difficulty)
	for i in duel.hands[poser].size():
		var mini := Shapes.MiniCard.new(color)
		mini.size = mini.custom_minimum_size
		mini.pressed.connect(_select_card.bind(i))
		_hand_area.add_child(mini)
		_minis.append(mini)
	_hand_area.resized.connect(_layout_hand)
	_layout_hand.call_deferred()
	_start_timer(CHOOSE_TIME, _on_choose_timeout)


## Main en éventail ; la carte choisie se soulève.
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
	if step != Step.CHOOSE or _paused:
		return
	_selected = index
	for i in _minis.size():
		_minis[i].set_selected(i == index)
	_layout_hand()
	var card: CardInPlay = duel.hands[duel.poser][index]
	_card.flip(func(): _card.show_owner(card, ""))
	_play_button.disabled = false


func _next_card() -> void:
	_select_card((_selected + 1) % duel.hands[duel.poser].size())


func _play_selected() -> void:
	if step != Step.CHOOSE or _selected < 0:
		return
	duel.play(_selected)
	_after_play("")


func _on_choose_timeout() -> void:
	duel.play_random()
	_after_play("Temps écoulé : une carte a été posée au hasard.")


func _after_play(message: String) -> void:
	step = Step.PASS
	_stop_timer()
	_play_button.disabled = true
	_card.flip(_card.show_back)
	if not message.is_empty():
		_flash(message)
	get_tree().create_timer(1.0 if message.is_empty() else 2.2).timeout.connect(func():
		_show_pass(duel.answerer(), "%s te pose une question." % names[duel.poser], _begin_answer))


# ---------------------------------------------------------------- Répondre sur la carte

func _top_bar() -> HBoxContainer:
	var bar := P.hbox(8)
	for p in [0, 1]:
		var block := P.hbox(8)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if p == 1:
			block.alignment = BoxContainer.ALIGNMENT_END
		var av := P.avatar(names[p], PLAYER_COLORS[p], 40)
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var info := P.vbox(3)
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var n := P.label(names[p], 15, P.CREAM, 900, HORIZONTAL_ALIGNMENT_RIGHT if p == 1 else HORIZONTAL_ALIGNMENT_LEFT)
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		info.add_child(n)
		var count := P.hbox(3)
		count.alignment = BoxContainer.ALIGNMENT_END if p == 1 else BoxContainer.ALIGNMENT_BEGIN
		for i in duel.hands[p].size():
			var c := ColorRect.new()
			c.color = P.YELLOW
			c.custom_minimum_size = Vector2(P.px(10), P.px(14))
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count.add_child(c)
		info.add_child(count)
		if p == 0:
			block.add_child(av)
			block.add_child(info)
		else:
			block.add_child(info)
			block.add_child(av)
		bar.add_child(block)
		if p == 0:
			bar.add_child(_timer_ring())
	return bar


func _begin_answer() -> void:
	step = Step.ANSWER
	_options_before = duel.played.option_count()
	_reserve_before = duel.played.reserve.size()
	var col := _new_screen(44, 16, 18)
	col.add_child(_top_bar())
	_card = CardView.new()
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card.answered.connect(_on_answer)
	col.add_child(_card)
	col.add_child(P.label("Touche ta réponse sur la carte", 14, P.LILAC))
	var data := duel.played.data
	var presented := duel.presented
	var owner_name := names[duel.poser]
	_card.flip(func(): _card.show_question(data, presented, owner_name))
	_start_timer(ANSWER_TIME, _on_answer_timeout)


func _on_answer(choice: String) -> void:
	if step != Step.ANSWER:
		return
	step = Step.RESULT
	_stop_timer()
	var correct := duel.played.is_correct(choice)
	_card.mark_answer(choice, correct)
	var result := duel.answer(choice)
	get_tree().create_timer(0.8).timeout.connect(_show_result.bind(result, choice, false))


func _on_answer_timeout() -> void:
	if step != Step.ANSWER:
		return
	step = Step.RESULT
	_card.set_answers_enabled(false)
	_show_result(duel.answer_timeout(), "", true)


# ---------------------------------------------------------------- Résultat

func _show_result(result: Dictionary, choice: String, timed_out: bool) -> void:
	step = Step.RESULT
	var owner_idx: int = result["owner"]
	var data: CardData = result["card"]
	var in_play: CardInPlay = result["in_play"]
	var correct: bool = result["correct"]

	var col := _new_screen(54, 18, 24)
	var headline := "Bonne réponse !" if correct else ("Temps écoulé !" if timed_out else "Raté !")
	var title := P.title(headline, 40, P.YELLOW if correct else Color("ff8fa3"))
	title.add_theme_color_override("font_shadow_color", P.EMBER if correct else P.VIOLET)
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

	var stamp: Control = null
	if correct:
		_card.flip(func(): _card.show_reveal(data, Session.bank.story_title(data.story)))
		stamp = PanelContainer.new()
		var ss := P.box(P.FRAMBOISE, P.px(10), P.px(12), P.px(6))
		ss.border_color = P.YELLOW
		ss.set_border_width_all(P.px(3))
		stamp.add_theme_stylebox_override("panel", ss)
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stamp_text := P.title("Carte de %s détruite" % names[owner_idx], 16, P.CREAM)
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
		var now := in_play.option_count()
		var weakened := "Elle n'a plus que %d réponses." % now
		if now == _options_before:
			weakened = "Elle garde 2 réponses, mais l'une d'elles change." if in_play.reserve.size() < _reserve_before \
				else "Elle garde ses 2 réponses."
		var note := PanelContainer.new()
		note.add_theme_stylebox_override("panel", P.box(P.CREAM, P.px(18), P.px(16), P.px(14)))
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.anchor_left = 0.08
		note.anchor_right = 0.92
		note.anchor_top = 0.5
		note.anchor_bottom = 0.5
		note.grow_vertical = Control.GROW_DIRECTION_BOTH
		var nv := P.vbox(6)
		if not timed_out:
			nv.add_child(P.label("« %s » n'est pas la bonne réponse." % choice, 16, P.NIGHT, 900))
		nv.add_child(P.title("La carte retourne chez %s." % names[owner_idx], 20, P.VIOLET))
		nv.add_child(P.label(weakened, 15, Color("6b5a8e"), 800))
		note.add_child(nv)
		stage.add_child(note)

	var go := P.button("Continuer", func():
		if _burning:
			return
		if correct:
			await _burn(stamp)
		if duel.phase == Duel.Phase.FINISHED:
			_show_end()
		else:
			_begin_choose(), 23)
	go.custom_minimum_size = Vector2(0, P.px(62))
	col.add_child(go)


## Carte détruite : elle brûle au feu doré avec son tampon, avant la suite.
func _burn(stamp: Control) -> void:
	_burning = true
	var fire := FeuDore.burn(_card, P.px(22))
	if stamp:
		stamp.create_tween().tween_property(stamp, "modulate:a", 0.0, 0.25).set_delay(0.05)
	await fire.consumed
	await get_tree().create_timer(0.35).timeout
	_burning = false


# ---------------------------------------------------------------- Fin

func _show_end() -> void:
	step = Step.END
	_stop_timer()
	var col := _new_screen(60, 24, 28)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var av := P.avatar(names[duel.winner], PLAYER_COLORS[duel.winner], 110)
	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(av)
	var winner := P.title(names[duel.winner], 46, P.YELLOW)
	winner.add_theme_color_override("font_shadow_color", P.EMBER)
	winner.add_theme_constant_override("shadow_offset_y", P.px(4))
	col.add_child(winner)
	col.add_child(P.title("remporte la partie !", 24, P.CREAM))
	col.add_child(P.label("%s n'a plus de cartes. Il en reste %d à %s." % [
		names[duel.loser()], duel.hands[duel.winner].size(), names[duel.winner]], 15, P.LILAC))
	col.add_child(P.spacer(30))
	col.add_child(P.button("Rejouer", func(): get_tree().reload_current_scene(), 23))
	col.add_child(P.button("Revoir les cartes détruites", _show_destroyed, 18, "GhostButton"))
	col.add_child(P.button("Retour au menu", _to_menu, 18, "GhostButton"))


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
	for p in 2:
		for data: CardData in duel.destroyed[p]:
			var card := PanelContainer.new()
			var cs := P.box(P.CREAM, P.px(14), P.px(14), P.px(12))
			cs.border_color = P.difficulty_color(data.difficulty)
			cs.border_width_left = P.px(8)
			card.add_theme_stylebox_override("panel", cs)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var v := P.vbox(6)
			card.add_child(v)
			v.add_child(P.label("Carte de %s, %s" % [names[p], data.category_label().to_lower()], 12, Color("6b5a8e"), 800, HORIZONTAL_ALIGNMENT_LEFT))
			v.add_child(P.label(data.question, 15, P.NIGHT, 900, HORIZONTAL_ALIGNMENT_LEFT))
			v.add_child(P.title(data.answer, 19, Color("1d7a47"), HORIZONTAL_ALIGNMENT_LEFT))
			v.add_child(P.title(data.reference, 14, P.FRAMBOISE, HORIZONTAL_ALIGNMENT_LEFT))
			list.add_child(card)
	col.add_child(P.button("Retour", _show_end, 18, "GhostButton"))


# ---------------------------------------------------------------- Commun

## Message bref au centre de l'écran.
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


func _ask_quit() -> void:
	if _quit_box:
		return
	_paused = true
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
	v.add_child(P.title("Quitter la partie ?", 32, P.YELLOW))
	v.add_child(P.label("La partie en cours sera perdue.", 16, P.LILAC))
	v.add_child(P.spacer(16))
	v.add_child(P.button("Continuer la partie", func():
		_quit_box.queue_free()
		_quit_box = null
		_paused = false, 22))
	v.add_child(P.button("Quitter", _to_menu, 18, "GhostButton"))


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_ask_quit()
