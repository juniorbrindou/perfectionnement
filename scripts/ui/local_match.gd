extends Node3D
## Partie à deux sur le même téléphone (PRD §2 et §3.2).
##
## Déroulement : question de départ en écran partagé → le poseur choisit une carte
## (10 s) → « Passe le téléphone » → l'autre répond (15 s) → résultat → l'ancien
## répondant, qui tient déjà le téléphone, pose à son tour.

const STARTER_TIME := 10.0
const CHOOSE_TIME := 10.0
const ANSWER_TIME := 15.0

enum Step { STARTER, PASS, CHOOSE, ANSWER, RESULT, END }

var duel: Duel
var step := Step.STARTER
var names: Array[String] = []

var _rng := RandomNumberGenerator.new()
var _table: Table3D
var _selected: Card3D
var _starter_queue: Array = []
var _options_before := 0
var _reserve_before := 0

# Minuteur
var _time_left := 0.0
var _time_total := 0.0
var _on_timeout := Callable()
var _paused := false

# Interface
var _hud: Control
var _overlay: Control
var _status: Label
var _timer_bar: ProgressBar
var _timer_label: Label
var _count_labels: Array[Label] = []
var _name_labels: Array[Label] = []
var _quit_box: Control


func _ready() -> void:
	_rng.randomize()
	names = Session.player_names.duplicate()
	get_viewport().physics_object_picking = true

	_table = Table3D.new()
	add_child(_table)
	_table.card_tapped.connect(_on_card_tapped)
	_build_hud()

	var pool := Session.bank.filter(Session.filter)
	var hands := DeckBuilder.deal(pool, LocalHistory.recent_ids(), _rng)
	duel = Duel.new(hands[0], hands[1], _rng)
	var ids: Array[String] = []
	for p in 2:
		for c in duel.hands[p]:
			_table.add_card(c, p)
			ids.append(c.data.id)
	LocalHistory.record(ids)
	_table.layout(duel.hands, 0)
	_refresh_counts()
	_show_starter()


func _process(delta: float) -> void:
	if _on_timeout.is_null() or _paused:
		return
	_time_left = max(_time_left - delta, 0.0)
	_timer_bar.value = _time_left / _time_total * 100.0
	_timer_label.text = "%d s" % ceil(_time_left)
	_timer_bar.modulate = Color(1, 0.45, 0.4) if _time_left <= 4.0 else Color.WHITE
	if _time_left <= 0.0:
		var cb := _on_timeout
		_stop_timer()
		cb.call()


func _start_timer(seconds: float, on_timeout: Callable) -> void:
	_time_total = seconds
	_time_left = seconds
	_on_timeout = on_timeout
	_timer_bar.visible = true
	_timer_label.visible = true


func _stop_timer() -> void:
	_on_timeout = Callable()
	_timer_bar.visible = false
	_timer_label.visible = false


# ---------------------------------------------------------------- Question de départ

func _show_starter() -> void:
	step = Step.STARTER
	_set_status("")
	if _starter_queue.is_empty():
		_starter_queue = Session.bank.starters.duplicate()
		Rand.shuffle(_starter_queue, _rng)
	var starter := StarterRound.new(_starter_queue.pop_back(), _rng)
	var resolved := [false]
	var buttons: Array = [[], []]

	var root := _modal(0.92)
	var v := UiTheme.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(v)

	for p in [1, 0]:  # Joueur 2 en haut (retourné), joueur 1 en bas.
		var half := Control.new()
		half.size_flags_vertical = Control.SIZE_EXPAND_FILL
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 22)
		half.add_child(margin)
		var col := UiTheme.vbox(8)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		margin.add_child(col)
		var who := UiTheme.label(names[p], 30)
		who.add_theme_color_override("font_color", UiTheme.GOLD)
		col.add_child(who)
		col.add_child(UiTheme.label(starter.question.question, 26))
		for option in starter.options:
			var b := UiTheme.choice_button(option, func(): _on_starter_answer(starter, p, option, resolved, buttons), 24)
			b.custom_minimum_size = Vector2(0, 62)
			col.add_child(b)
			buttons[p].append(b)
		v.add_child(half)
		if p == 1:
			half.resized.connect(func(): half.pivot_offset = half.size / 2)
			half.rotation = PI
			var line := ColorRect.new()
			line.color = UiTheme.GOLD
			line.custom_minimum_size = Vector2(0, 4)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(line)

	_set_status("")
	_start_timer(STARTER_TIME, func():
		if resolved[0]:
			return
		resolved[0] = true
		_flash("Personne n'a répondu : nouvelle question")
		get_tree().create_timer(1.4).timeout.connect(_show_starter))


func _on_starter_answer(starter: StarterRound, player: int, choice: String, resolved: Array, buttons: Array) -> void:
	if resolved[0]:
		return
	resolved[0] = true
	_stop_timer()
	for p in 2:
		for b: Button in buttons[p]:
			b.disabled = true
			if b.text == starter.question.answer:
				UiTheme.tint_choice(b, UiTheme.GREEN)
			elif b.text == choice and p == player:
				UiTheme.tint_choice(b, UiTheme.RED)
	var first := starter.resolve(player, choice)
	var msg := "%s a trouvé !" % names[player] if first == player else "%s s'est trompé." % names[player]
	_flash("%s %s commence." % [msg, names[first]])
	get_tree().create_timer(2.2).timeout.connect(func():
		duel.start_with(first)
		_show_pass(first, "Tu commences : choisis une carte à poser.", _begin_choose))


# ---------------------------------------------------------------- Passage du téléphone

func _show_pass(player: int, subtitle: String, next: Callable) -> void:
	step = Step.PASS
	_stop_timer()
	_table.layout(duel.hands, player)
	_set_status("")
	var root := _modal(1.0)
	var v := _centered_column(root, 26)
	v.add_child(UiTheme.label("Passe le téléphone à", 34))
	var who := UiTheme.label(names[player], 60)
	who.add_theme_color_override("font_color", UiTheme.GOLD)
	v.add_child(who)
	v.add_child(UiTheme.label(subtitle, 26))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	v.add_child(spacer)
	v.add_child(UiTheme.button("Je suis %s, continuer" % names[player], func():
		_clear_overlay()
		next.call(), 30))


# ---------------------------------------------------------------- Choix de la carte

func _begin_choose() -> void:
	step = Step.CHOOSE
	_selected = null
	_clear_overlay()
	_table.layout(duel.hands, duel.poser)
	_set_status("%s, touche une carte pour la retourner, puis pose-la." % names[duel.poser])
	_start_timer(CHOOSE_TIME, _on_choose_timeout)


func _on_card_tapped(card: Card3D) -> void:
	if step != Step.CHOOSE or _paused or card.owner_index != duel.poser:
		return
	if not card.in_play in duel.hands[duel.poser]:
		return
	if _selected == card:
		_close_detail()
		return
	if _selected:
		_selected.set_face_up(false)
	_selected = card
	card.set_face_up(true)
	_show_detail(card)


func _show_detail(card: Card3D) -> void:
	_clear_overlay()
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 150
	_overlay.add_child(panel)
	var v := UiTheme.vbox(12)
	panel.add_child(v)
	var c := card.in_play
	v.add_child(UiTheme.label("%s · %s · %d propositions" % [c.data.difficulty_label(), c.data.category_label(), c.option_count()], 22, true))
	v.add_child(UiTheme.label(c.data.question, 30, true))
	var options: Array[String] = [c.data.answer]
	options.append_array(c.shown_wrongs)
	for o in options:
		var l := UiTheme.label(("Bonne réponse : " + o) if o == c.data.answer else o, 26, true)
		if o == c.data.answer:
			l.add_theme_color_override("font_color", UiTheme.GREEN)
		v.add_child(l)
	var h := UiTheme.hbox(12)
	var close := UiTheme.button("Fermer", _close_detail, 26)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var play := UiTheme.button("Poser cette carte", _play_selected, 26)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(close)
	h.add_child(play)
	v.add_child(h)


func _close_detail() -> void:
	if _selected:
		_selected.set_face_up(false)
	_selected = null
	_clear_overlay()


func _play_selected() -> void:
	if step != Step.CHOOSE or _selected == null:
		return
	var card := _selected
	_selected = null
	duel.play(duel.hands[duel.poser].find(card.in_play))
	_after_play(card, "")


func _on_choose_timeout() -> void:
	if _selected:
		_selected.set_face_up(false)
		_selected = null
	duel.play_random()
	_after_play(_table.card_for(duel.played), "Temps écoulé : une carte a été posée au hasard.")


func _after_play(card: Card3D, message: String) -> void:
	step = Step.PASS
	_stop_timer()
	_clear_overlay()
	_set_status("")
	_table.to_center(card)
	_table.layout(duel.hands, duel.poser)
	if not message.is_empty():
		_flash(message)
	get_tree().create_timer(1.6 if message.is_empty() else 2.4).timeout.connect(func():
		_show_pass(duel.answerer(), "%s te pose une question." % names[duel.poser], _begin_answer))


# ---------------------------------------------------------------- Réponse

func _begin_answer() -> void:
	step = Step.ANSWER
	_table.layout(duel.hands, duel.answerer())
	_options_before = duel.played.option_count()
	_reserve_before = duel.played.reserve.size()
	_set_status("")
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 20
	panel.offset_right = -20
	panel.offset_bottom = -24
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_overlay.add_child(panel)
	var v := UiTheme.vbox(12)
	panel.add_child(v)
	var c := duel.played.data
	v.add_child(UiTheme.label("%s te pose une question" % names[duel.poser], 22, true))
	v.add_child(UiTheme.label("%s · %s · %d propositions" % [c.difficulty_label(), c.category_label(), duel.presented.size()], 22, true))
	v.add_child(UiTheme.label(c.question, 32, true))
	var buttons: Array[Button] = []
	for o in duel.presented:
		var b := UiTheme.choice_button(o, func(): _on_answer(o, buttons))
		v.add_child(b)
		buttons.append(b)
	_start_timer(ANSWER_TIME, func(): _show_result(duel.answer_timeout(), "", true))


func _on_answer(choice: String, buttons: Array[Button]) -> void:
	if step != Step.ANSWER:
		return
	for b in buttons:
		b.disabled = true
	_stop_timer()
	_show_result(duel.answer(choice), choice, false)


# ---------------------------------------------------------------- Résultat

func _show_result(result: Dictionary, choice: String, timed_out: bool) -> void:
	step = Step.RESULT
	_stop_timer()
	_clear_overlay()
	var owner_idx: int = result["owner"]
	var data: CardData = result["card"]
	var in_play: CardInPlay = result["in_play"]
	var card3d := _table.card_for(in_play)

	var root := _modal(0.55)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.offset_left = 24
	panel.offset_right = -24
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var v := UiTheme.vbox(14)
	panel.add_child(v)

	if result["correct"]:
		card3d.destroy()
		_table.forget(in_play)
		var title := UiTheme.label("Bonne réponse !", 44, true)
		title.add_theme_color_override("font_color", UiTheme.GREEN)
		v.add_child(title)
		v.add_child(UiTheme.illustration_placeholder(data.story, Session.bank.story_title(data.story)))
		v.add_child(UiTheme.label(data.question, 24, true))
		v.add_child(UiTheme.label(data.answer, 36, true))
		v.add_child(UiTheme.label(data.reference, 24, true))
		if not data.explanation.is_empty():
			v.add_child(UiTheme.label(data.explanation, 24, true))
		v.add_child(UiTheme.label("%s perd cette carte." % names[owner_idx], 26, true))
	else:
		var title := UiTheme.label("Temps écoulé !" if timed_out else "Raté !", 44, true)
		title.add_theme_color_override("font_color", UiTheme.RED)
		v.add_child(title)
		if not timed_out:
			v.add_child(UiTheme.label("« %s » n'était pas la bonne réponse." % choice, 26, true))
		v.add_child(UiTheme.label("La carte retourne chez %s." % names[owner_idx], 28, true))
		var now := in_play.option_count()
		var weakened := "Elle n'a plus que %d propositions." % now
		if now == _options_before:
			weakened = "Elle garde 2 propositions, mais l'une d'elles change." if in_play.reserve.size() < _reserve_before \
				else "Elle garde ses 2 propositions."
		v.add_child(UiTheme.label(weakened, 24, true))
		card3d.refresh()

	_table.layout(duel.hands, duel.poser if duel.phase != Duel.Phase.FINISHED else owner_idx)
	_refresh_counts()
	v.add_child(UiTheme.button("Continuer", func():
		if duel.phase == Duel.Phase.FINISHED:
			_show_end()
		else:
			_begin_choose(), 30))


# ---------------------------------------------------------------- Fin

func _show_end() -> void:
	step = Step.END
	_stop_timer()
	var root := _modal(0.95)
	var v := _centered_column(root, 22)
	var title := UiTheme.label("%s gagne !" % names[duel.winner], 54)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	v.add_child(title)
	v.add_child(UiTheme.label("%s n'a plus de cartes." % names[duel.loser()], 28))
	v.add_child(UiTheme.label("Cartes restantes : %s — %d · %s — %d" % [
		names[0], duel.hands[0].size(), names[1], duel.hands[1].size()], 24))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	v.add_child(spacer)
	v.add_child(UiTheme.button("Voir les cartes détruites", _show_destroyed, 28))
	v.add_child(UiTheme.button("Rejouer", func(): get_tree().reload_current_scene(), 30))
	v.add_child(UiTheme.button("Menu", _to_menu, 28))


func _show_destroyed() -> void:
	var root := _modal(1.0)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	root.add_child(margin)
	var outer := UiTheme.vbox(16)
	margin.add_child(outer)
	var title := UiTheme.label("Cartes détruites", 40)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	outer.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := UiTheme.vbox(14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for p in 2:
		for data: CardData in duel.destroyed[p]:
			var card := PanelContainer.new()
			var v := UiTheme.vbox(6)
			card.add_child(v)
			v.add_child(UiTheme.label("Carte de %s · %s" % [names[p], data.category_label()], 20, true))
			v.add_child(UiTheme.label(data.question, 24, true))
			v.add_child(UiTheme.label(data.answer + " — " + data.reference, 24, true))
			list.add_child(card)
	outer.add_child(UiTheme.button("Retour", _show_end, 28))


# ---------------------------------------------------------------- Interface commune

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.theme = UiTheme.get_theme()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)

	var bar := PanelContainer.new()
	bar.theme_type_variation = "DarkPanel"
	bar.anchor_right = 1.0
	bar.offset_left = 12
	bar.offset_right = -12
	bar.offset_top = 12
	_hud.add_child(bar)
	var col := UiTheme.vbox(6)
	bar.add_child(col)
	var row := UiTheme.hbox(10)
	col.add_child(row)
	for p in 2:
		var box := UiTheme.vbox(0)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := UiTheme.label(names[p], 24, false, HORIZONTAL_ALIGNMENT_LEFT if p == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
		n.add_theme_color_override("font_color", UiTheme.GOLD)
		var cnt := UiTheme.label("", 22, false, n.horizontal_alignment)
		box.add_child(n)
		box.add_child(cnt)
		_name_labels.append(n)
		_count_labels.append(cnt)
		row.add_child(box)
		if p == 0:
			var quit := UiTheme.button("Quitter", _ask_quit, 20)
			quit.custom_minimum_size = Vector2(130, 56)
			quit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(quit)
	var trow := UiTheme.hbox(10)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 16)
	_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_label = UiTheme.label("", 22)
	_timer_label.custom_minimum_size = Vector2(70, 0)
	trow.add_child(_timer_bar)
	trow.add_child(_timer_label)
	col.add_child(trow)
	_stop_timer()

	_status = UiTheme.label("", 24)
	_status.anchor_left = 0.0
	_status.anchor_right = 1.0
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_top = -330
	_status.offset_bottom = -280
	_status.offset_left = 24
	_status.offset_right = -24
	_hud.add_child(_status)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_overlay)


func _refresh_counts() -> void:
	for p in 2:
		var n: int = duel.hands[p].size()
		_count_labels[p].text = "%d carte%s" % [n, "s" if n > 1 else ""]


func _set_status(text: String) -> void:
	_status.text = text


func _clear_overlay() -> void:
	for child in _overlay.get_children():
		child.queue_free()


## Fond plein écran qui bloque la table ; renvoie le conteneur où placer le contenu.
func _modal(alpha: float) -> Control:
	_clear_overlay()
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.NIGHT, alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)
	return dim


func _centered_column(parent: Control, separation: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	parent.add_child(margin)
	var v := UiTheme.vbox(separation)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(v)
	return v


## Message bref au centre de l'écran.
func _flash(text: String) -> void:
	var box := PanelContainer.new()
	box.theme_type_variation = "DarkPanel"
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = 40
	box.offset_right = -40
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(UiTheme.label(text, 28))
	_hud.add_child(box)
	var t := box.create_tween()
	t.tween_interval(1.8)
	t.tween_property(box, "modulate:a", 0.0, 0.4)
	t.tween_callback(box.queue_free)


func _ask_quit() -> void:
	if _quit_box:
		return
	_paused = true
	_quit_box = ColorRect.new()
	(_quit_box as ColorRect).color = Color(UiTheme.NIGHT, 0.85)
	_quit_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_quit_box)
	var v := _centered_column(_quit_box, 20)
	v.add_child(UiTheme.label("Quitter la partie ?", 40))
	v.add_child(UiTheme.label("La partie en cours sera perdue.", 26))
	v.add_child(UiTheme.button("Oui, quitter", _to_menu, 28))
	v.add_child(UiTheme.button("Continuer la partie", func():
		_quit_box.queue_free()
		_quit_box = null
		_paused = false, 28))


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_ask_quit()
