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
var _status_box: Control
var _status: Label
var _timer_bar: ProgressBar
var _timer_label: Label
var _count_labels: Array[Label] = []
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
	var urgent := _time_left <= 4.0
	_timer_bar.modulate = Color(1.6, 0.35, 0.4) if urgent else Color.WHITE
	_timer_label.modulate = Color(1, 0.55, 0.55) if urgent else Color.WHITE
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

	var root := _modal(0.94)
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
			margin.add_theme_constant_override("margin_" + side, 24)
		half.add_child(margin)
		var col := UiTheme.vbox(8)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		margin.add_child(col)
		var who := UiTheme.scripture(names[p], 30, false, true)
		who.add_theme_color_override("font_color", UiTheme.OR)
		col.add_child(who)
		col.add_child(UiTheme.scripture(starter.question.question, 28, false))
		for option in starter.options:
			var b := UiTheme.choice_button(option, func(): _on_starter_answer(starter, p, option, resolved, buttons), 24)
			b.custom_minimum_size = Vector2(0, 60)
			col.add_child(b)
			buttons[p].append(b)
		v.add_child(half)
		if p == 1:
			# Les conteneurs annulent la rotation de leurs enfants : on tourne le contenu.
			margin.resized.connect(func(): margin.pivot_offset = margin.size / 2)
			margin.rotation = PI
			var middle := UiTheme.weave_band(18)
			v.add_child(middle)

	_start_timer(STARTER_TIME, func():
		if resolved[0]:
			return
		resolved[0] = true
		_flash("Personne n'a répondu. Nouvelle question.")
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
				UiTheme.tint_choice(b, UiTheme.OLIVE)
			elif b.text == choice and p == player:
				UiTheme.tint_choice(b, UiTheme.CRAMOISI)
	var first := starter.resolve(player, choice)
	var msg := "%s a trouvé." % names[player] if first == player else "Mauvaise réponse de %s." % names[player]
	_flash("%s\n%s commence." % [msg, names[first]])
	get_tree().create_timer(2.2).timeout.connect(func():
		duel.start_with(first)
		_show_pass(first, "Tu commences. Choisis la carte à poser.", _begin_choose))


# ---------------------------------------------------------------- Passage du téléphone

## Le voile : une étoffe tissée couvre la table, puis se lève sur la partie.
func _show_pass(player: int, subtitle: String, next: Callable) -> void:
	step = Step.PASS
	_stop_timer()
	_table.layout(duel.hands, player)
	_set_status("")
	_clear_overlay()

	var veil := ColorRect.new()
	veil.color = UiTheme.NIGHT
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(veil)
	var cloth := TextureRect.new()
	cloth.texture = UiTheme.weave_texture("voile", 104, 16, true, 0, 2)
	cloth.stretch_mode = TextureRect.STRETCH_TILE
	cloth.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cloth.set_anchors_preset(Control.PRESET_FULL_RECT)
	cloth.modulate = Color(1, 1, 1, 0.16)
	cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(cloth)
	var hem := UiTheme.weave_band(22)
	hem.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hem.offset_top = -22
	veil.add_child(hem)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	veil.add_child(margin)
	var v := UiTheme.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(v)
	v.add_child(UiTheme.label("Passe le téléphone à", 30, "", HORIZONTAL_ALIGNMENT_LEFT))
	var who := UiTheme.scripture(names[player], 76, false, true)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(who)
	var sub := UiTheme.label(subtitle, 26, "", HORIZONTAL_ALIGNMENT_LEFT)
	sub.modulate = Color(1, 1, 1, 0.75)
	v.add_child(sub)
	v.add_child(UiTheme.spacer(48))
	v.add_child(UiTheme.button("Je suis %s" % names[player], func():
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.reparent(_hud)  # Hors de l'overlay, pour survivre à l'écran suivant.
		var t := veil.create_tween()
		t.tween_property(veil, "position:y", -veil.size.y, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_callback(veil.queue_free)
		next.call(), 30))


# ---------------------------------------------------------------- Choix de la carte

func _begin_choose() -> void:
	step = Step.CHOOSE
	_selected = null
	_clear_overlay()
	_table.layout(duel.hands, duel.poser)
	_set_status("Touche une carte pour la retourner, puis pose-la.")
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
	_set_status("")
	var panel := _linen_panel()
	panel.offset_top = 150
	_overlay.add_child(panel)
	var v := UiTheme.vbox(12)
	panel.add_child(v)
	var c := card.in_play
	v.add_child(UiTheme.card_header(c.data, c.option_count()))
	var q := UiTheme.scripture(c.data.question, 32, true, true)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(q)
	v.add_child(_answer_row(c.data.answer, true))
	for w in c.shown_wrongs:
		v.add_child(_answer_row(w, false))
	var hint := UiTheme.label("Ton adversaire verra ces %d choix, sans savoir lequel est le bon." % c.option_count(), 20, "InkLabel", HORIZONTAL_ALIGNMENT_LEFT)
	hint.modulate = Color(1, 1, 1, 0.65)
	v.add_child(hint)
	var h := UiTheme.hbox(12)
	var close := UiTheme.button("Garder", _close_detail, 26, "InkGhostButton")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var play := UiTheme.button("Poser cette carte", _play_selected, 26)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.size_flags_stretch_ratio = 1.6
	h.add_child(close)
	h.add_child(play)
	v.add_child(h)


## Une proposition dans le détail de sa propre carte ; la bonne est sur fond olive.
func _answer_row(text: String, correct: bool) -> Control:
	var box := PanelContainer.new()
	var style := UiTheme.box(UiTheme.OLIVE if correct else Color(UiTheme.INK, 0.06), 10, 16, 10)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UiTheme.hbox(10)
	box.add_child(h)
	var l := UiTheme.scripture(text, 26, not correct, correct)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if correct:
		var tag := UiTheme.label("bonne réponse", 18)
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(tag)
	return box


func _close_detail() -> void:
	if _selected:
		_selected.set_face_up(false)
	_selected = null
	_clear_overlay()
	_set_status("Touche une carte pour la retourner, puis pose-la.")


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
	_after_play(_table.card_for(duel.played), "Temps écoulé. Une carte a été posée au hasard.")


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
	var panel := _linen_panel()
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_bottom = -20
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_overlay.add_child(panel)
	var v := UiTheme.vbox(12)
	panel.add_child(v)
	var c := duel.played.data
	var from := UiTheme.label("La question de %s" % names[duel.poser], 22, "InkLabel", HORIZONTAL_ALIGNMENT_LEFT)
	from.modulate = Color(1, 1, 1, 0.65)
	v.add_child(from)
	v.add_child(UiTheme.card_header(c, duel.presented.size()))
	var q := UiTheme.scripture(c.question, 34, true, true)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(q)
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
	var panel := _linen_panel()
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var v := UiTheme.vbox(12)
	panel.add_child(v)

	if result["correct"]:
		card3d.destroy()
		_table.forget(in_play)
		var title := UiTheme.scripture("Bonne réponse", 44, true, true)
		title.add_theme_color_override("font_color", UiTheme.OLIVE)
		v.add_child(title)
		v.add_child(UiTheme.illustration_placeholder(data.story, Session.bank.story_title(data.story)))
		v.add_child(UiTheme.scripture(data.question, 24))
		v.add_child(UiTheme.scripture(data.answer, 38, true, true))
		v.add_child(UiTheme.scripture(data.reference, 24, true, false, true))
		if not data.explanation.is_empty():
			v.add_child(UiTheme.scripture(data.explanation, 24))
		v.add_child(UiTheme.label("La carte de %s est détruite." % names[owner_idx], 24, "InkLabel"))
	else:
		var title := UiTheme.scripture("Temps écoulé" if timed_out else "Raté", 44, true, true)
		title.add_theme_color_override("font_color", UiTheme.CRAMOISI)
		v.add_child(title)
		if not timed_out:
			v.add_child(UiTheme.scripture("« %s » n'est pas la bonne réponse." % choice, 26))
		v.add_child(UiTheme.label("La carte retourne chez %s." % names[owner_idx], 26, "InkLabel"))
		var now := in_play.option_count()
		var weakened := "Elle n'a plus que %d choix." % now
		if now == _options_before:
			weakened = "Elle garde 2 choix, mais l'un d'eux change." if in_play.reserve.size() < _reserve_before \
				else "Elle garde ses 2 choix."
		var w := UiTheme.label(weakened, 22, "InkLabel")
		w.modulate = Color(1, 1, 1, 0.7)
		v.add_child(w)
		card3d.refresh()

	_table.layout(duel.hands, duel.poser if duel.phase != Duel.Phase.FINISHED else owner_idx)
	_refresh_counts()
	v.add_child(UiTheme.spacer(4))
	v.add_child(UiTheme.button("Continuer", func():
		if duel.phase == Duel.Phase.FINISHED:
			_show_end()
		else:
			_begin_choose(), 28))


# ---------------------------------------------------------------- Fin

func _show_end() -> void:
	step = Step.END
	_stop_timer()
	var root := _modal(0.96)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	root.add_child(margin)
	var v := UiTheme.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(v)
	var winner := UiTheme.scripture(names[duel.winner], 76, false, true)
	winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	winner.add_theme_color_override("font_color", UiTheme.OR)
	v.add_child(winner)
	v.add_child(UiTheme.label("remporte la partie.", 32, "", HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(UiTheme.weave_band(14))
	var left: int = duel.hands[duel.winner].size()
	var recap := UiTheme.label("%s n'a plus de cartes. Il en reste %d à %s." % [
		names[duel.loser()], left, names[duel.winner]], 24, "", HORIZONTAL_ALIGNMENT_LEFT)
	recap.modulate = Color(1, 1, 1, 0.75)
	v.add_child(recap)
	v.add_child(UiTheme.spacer(36))
	v.add_child(UiTheme.button("Rejouer", func(): get_tree().reload_current_scene(), 30))
	v.add_child(UiTheme.button("Revoir les cartes détruites", _show_destroyed, 26, "GhostButton"))
	v.add_child(UiTheme.button("Retour au menu", _to_menu, 26, "GhostButton"))


func _show_destroyed() -> void:
	var root := _modal(1.0)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	root.add_child(margin)
	var outer := UiTheme.vbox(16)
	margin.add_child(outer)
	var title := UiTheme.scripture("Cartes détruites", 44, false, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
			card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.LIN, 14, 22, 16))
			var v := UiTheme.vbox(6)
			card.add_child(v)
			var head := UiTheme.hbox(10)
			head.add_child(UiTheme.difficulty_chip(data.difficulty))
			var owner_l := UiTheme.label("Carte de %s" % names[p], 20, "InkLabel", HORIZONTAL_ALIGNMENT_LEFT)
			owner_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(owner_l)
			v.add_child(head)
			var q := UiTheme.scripture(data.question, 24)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			v.add_child(q)
			var a := UiTheme.scripture(data.answer, 28, true, true)
			a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			v.add_child(a)
			var r := UiTheme.scripture(data.reference, 22, true, false, true)
			r.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			v.add_child(r)
			list.add_child(card)
	outer.add_child(UiTheme.button("Retour", _show_end, 26, "GhostButton"))


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
	bar.theme_type_variation = "NightPanel"
	bar.anchor_right = 1.0
	bar.offset_left = 12
	bar.offset_right = -12
	bar.offset_top = 12
	_hud.add_child(bar)
	var col := UiTheme.vbox(8)
	bar.add_child(col)
	var row := UiTheme.hbox(10)
	col.add_child(row)
	for p in 2:
		var align := HORIZONTAL_ALIGNMENT_LEFT if p == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var box := UiTheme.vbox(0)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := UiTheme.scripture(names[p], 28, false, true)
		n.horizontal_alignment = align
		var cnt := UiTheme.label("", 20, "", align)
		cnt.modulate = Color(1, 1, 1, 0.65)
		box.add_child(n)
		box.add_child(cnt)
		_count_labels.append(cnt)
		row.add_child(box)
		if p == 0:
			var quit := UiTheme.button("Quitter", _ask_quit, 20, "GhostButton")
			quit.custom_minimum_size = Vector2(120, 52)
			quit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(quit)
	var trow := UiTheme.hbox(10)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 8)
	_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_label = UiTheme.label("", 20)
	_timer_label.custom_minimum_size = Vector2(56, 0)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trow.add_child(_timer_bar)
	trow.add_child(_timer_label)
	col.add_child(trow)
	_stop_timer()

	var status := PanelContainer.new()
	status.theme_type_variation = "NightPanel"
	status.anchor_right = 1.0
	status.anchor_top = 1.0
	status.anchor_bottom = 1.0
	status.offset_left = 24
	status.offset_right = -24
	status.offset_bottom = -28
	status.grow_vertical = Control.GROW_DIRECTION_BEGIN
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = UiTheme.label("", 24)
	status.add_child(_status)
	_hud.add_child(status)
	_status_box = status

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_overlay)


func _linen_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.offset_left = 18
	panel.offset_right = -18
	return panel


func _refresh_counts() -> void:
	for p in 2:
		var n: int = duel.hands[p].size()
		_count_labels[p].text = "%d carte%s" % [n, "s" if n > 1 else ""]


func _set_status(text: String) -> void:
	_status.text = text
	_status_box.visible = not text.is_empty()


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


## Message bref au centre de l'écran.
func _flash(text: String) -> void:
	var box := PanelContainer.new()
	box.theme_type_variation = "NightPanel"
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
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.NIGHT, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(dim)
	_quit_box = dim
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	dim.add_child(margin)
	var v := UiTheme.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(v)
	var q := UiTheme.scripture("Quitter la partie ?", 44, false, true)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(q)
	v.add_child(UiTheme.label("La partie en cours sera perdue.", 26, "", HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(UiTheme.spacer(24))
	v.add_child(UiTheme.button("Continuer la partie", func():
		_quit_box.queue_free()
		_quit_box = null
		_paused = false, 28))
	v.add_child(UiTheme.button("Quitter", _to_menu, 26, "GhostButton"))


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_ask_quit()
