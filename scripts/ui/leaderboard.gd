extends Control
## Classement général par XP (maquette de l'utilisateur, 2026-11-24) : titre entre deux
## branches de laurier, podium des trois premiers sur des médailles d'or, d'argent et de
## bronze, la liste jusqu'au 50e, et ta place épinglée en bas avec ta progression vers le Rang S. Les 10 premiers portent le Rang S.
## Le serveur tient le classement (leaderboard « xp », docs/SERVEUR.md) ; on ne fait que le lire.

const P := preload("res://scripts/ui/ui_theme.gd")
const LIMIT := 50
## Avatars : une couleur tirée du pseudo, pour qu'un joueur garde toujours la même.
const COLORS := [Color("1fa9a3"), Color("3a6fd8"), Color("7a52e0"), Color("c4501f"), Color("2fae68"), Color("b8185a")]

var _content: VBoxContainer  ## Zone entre le titre et ta place : chargement, message ou liste.
var _me_slot: Control


func _ready() -> void:
	theme = P.get_theme()
	Glass.background(self, 0.8)
	var bar := TopBar.attach(self)
	var m := P.margins(16, 8, 16, 16)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.offset_top = bar.bottom()
	add_child(m)
	var v := P.vbox(8)
	m.add_child(v)
	v.add_child(_heading())
	_content = P.vbox(8)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_content)
	_me_slot = P.vbox(0)
	v.add_child(_me_slot)
	var back := Glass.back_button(_to_menu)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(back)
	_load()


func _load() -> void:
	_message("Chargement du classement…", "")
	if not Online.is_online():
		_message("Le classement se consulte en ligne.", "Vérifie ta connexion à Internet, puis réessaie.", true)
		return
	var data := await Online.leaderboard(LIMIT)
	if not is_inside_tree():
		return
	if data.is_empty():
		_message("Le classement n'a pas pu être chargé.", Online.last_error, true)
		return
	show_data(data)


## Affiche un classement : {"top": [{place, name, xp, me}], "me": {…} ou {}}.
func show_data(data: Dictionary) -> void:
	_clear(_content)
	_clear(_me_slot)
	var top: Array = data.get("top", [])
	var me: Dictionary = data.get("me", {})
	if top.is_empty():
		_message("Personne n'est encore classé.", "Gagne de l'XP en jouant contre le Scribe ou en duel : tu seras le premier.")
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_content.add_child(scroll)
		var list := P.vbox(8)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		list.add_child(_podium(top.slice(0, 3)))
		for row in top.slice(3):
			list.add_child(_row(row))
	_me_slot.add_child(_my_row(me, top))


# ---------------------------------------------------------------- Titre et podium

## « Classement » entre deux branches de laurier, la règle du Rang S, une étincelle.
func _heading() -> Control:
	var v := P.vbox(2)
	var row := P.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_branch(-1.0))
	var titles := P.vbox(0)
	for l: Label in [Glass.title("Classement", 34), P.label("Les %d premiers portent le Rang S" % Progression.RANK_S_PLACES, 14, P.CREAM, 800)]:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		titles.add_child(l)
	row.add_child(titles)
	row.add_child(_branch(1.0))
	v.add_child(row)
	var spark := Ornaments.Sparkle.new(P.px(14))
	spark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(spark)
	return v


func _branch(side: float) -> Control:
	var l := Ornaments.Laurel.new()
	l.custom_minimum_size = Vector2(P.px(34), P.px(62))
	l.sides = [side]
	l.center = Vector2(1.0 if side < 0 else 0.0, 0.42)
	l.radius = 0.62
	return l


func _podium(rows: Array) -> Control:
	var h := P.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	# 2e à gauche, 1er au centre (plus haut), 3e à droite, alignés par le bas.
	for place in [2, 1, 3]:
		if place > rows.size():
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(P.px(100), 0)
			h.add_child(gap)
			continue
		var step := _podium_step(rows[place - 1])
		step.size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(step)
	return h


## Une marche du podium : la médaille posée sur le haut d'un panneau, le pseudo, l'XP.
func _podium_step(row: Dictionary) -> Control:
	var place: int = row["place"]
	var first := place == 1
	var v := P.vbox(0)
	v.add_theme_constant_override("separation", -P.px(26))  # La médaille chevauche le panneau.
	var medal := Ornaments.Medal.new(place, P.px(76 if first else 62))
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	medal.z_index = 1
	v.add_child(medal)
	var panel := PanelContainer.new()
	var s := P.box(Color(0.09, 0.2, 0.47, 0.94), P.px(14), P.px(8), P.px(8))
	s.content_margin_top = P.px(30)
	if first:
		s.bg_color = Color(0.12, 0.25, 0.56, 0.96)
		s.border_color = Color("f0c05a")
		s.set_border_width_all(P.px(3))
		s.shadow_color = Color(1.0, 0.84, 0.42, 0.45)
		s.shadow_size = P.px(10)
	else:
		s.border_color = Color(1, 1, 1, 0.3)
		s.set_border_width_all(P.px(2))
	panel.add_theme_stylebox_override("panel", s)
	panel.custom_minimum_size = Vector2(P.px(122 if first else 104), P.px(92 if first else 78))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := P.vbox(4)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(inner)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", P.box(Color("fff1d6"), P.px(10), P.px(8), P.px(2)))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := P.title("Toi" if row.get("me", false) else str(row["name"]), 16 if first else 13, Glass.INK)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	pill.add_child(n)
	inner.add_child(pill)
	inner.add_child(P.title(_xp(row["xp"]), 18 if first else 15, Glass.GOLD))
	v.add_child(panel)
	return v


# ---------------------------------------------------------------- Lignes

func _row(row: Dictionary) -> Control:
	var mine: bool = row.get("me", false)
	var p := Glass.panel(Color(0.07, 0.15, 0.36, 0.9), 12, Color(Glass.RING, 0.8) if mine else Color(1, 1, 1, 0.14), 12, 6)
	var h := P.hbox(10)
	p.add_child(h)
	var place := P.title(str(row["place"]), 18, P.CREAM)
	place.custom_minimum_size = Vector2(P.px(26), 0)
	place.autowrap_mode = TextServer.AUTOWRAP_OFF
	place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(place)
	h.add_child(Glass.avatar(row["name"], _color_of(row["name"]), 32, Color(1, 1, 1, 0.85)))
	var n := P.title("Toi" if mine else str(row["name"]), 16, P.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(n)
	var xp := P.title(_xp(row["xp"]), 16, Glass.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	xp.autowrap_mode = TextServer.AUTOWRAP_OFF
	xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(xp)
	return p

## Ta ligne, épinglée sous la liste : ta place et ce qu'il te manque pour le Rang S.
func _my_row(me: Dictionary, top: Array) -> Control:
	var p := PanelContainer.new()
	var s := Glass.panel_style(Color(0.086, 0.227, 0.525, 0.95), 18, Glass.RING, 12, 8)
	s.set_border_width_all(P.px(2))
	s.shadow_color = Color(1.0, 0.84, 0.42, 0.3)
	s.shadow_size = P.px(8)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := P.hbox(10)
	p.add_child(h)
	var place: int = me.get("place", 0)
	var pl := P.title(str(place) if place > 0 else "–", 22, Glass.GOLD)
	pl.custom_minimum_size = Vector2(P.px(34), 0)
	pl.autowrap_mode = TextServer.AUTOWRAP_OFF
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(pl)
	h.add_child(Glass.avatar(Online.username, Glass.ME, 42))
	var who := P.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top_line := P.hbox(6)
	var n := P.title("Toi", 17, P.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_line.add_child(n)
	var my_xp: int = me.get("xp", Online.xp())
	var xl := P.title(_xp(my_xp), 16, Glass.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	xl.autowrap_mode = TextServer.AUTOWRAP_OFF
	top_line.add_child(xl)
	who.add_child(top_line)
	who.add_child(P.label(_my_status(place, my_xp, top), 12, Glass.SOFT, 800, HORIZONTAL_ALIGNMENT_LEFT))
	who.add_child(_progress_bar(_rank_s_ratio(place, my_xp, top)))
	h.add_child(who)
	return p


## Part du chemin parcouru vers le Rang S (l'XP du 10e).
func _rank_s_ratio(place: int, my_xp: int, top: Array) -> float:
	if Progression.has_rank_s(place) or top.size() < Progression.RANK_S_PLACES:
		return 1.0 if place > 0 else 0.0
	var target := int(top[Progression.RANK_S_PLACES - 1]["xp"]) + 1
	return clampf(float(my_xp) / float(maxi(target, 1)), 0.0, 1.0)


func _progress_bar(ratio: float) -> Control:
	var bar := Panel.new()
	bar.add_theme_stylebox_override("panel", P.box(Color(1, 1, 1, 0.16), P.px(4)))
	bar.custom_minimum_size = Vector2(0, P.px(7))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", P.box(Color("f6b93b"), P.px(4)))
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_bottom = 1.0
	fill.anchor_right = ratio
	fill.visible = ratio > 0.0
	bar.add_child(fill)
	return bar


func _my_status(place: int, my_xp: int, top: Array) -> String:
	var rank := _rank_name(my_xp)
	if place <= 0:
		return "%s : pas encore classé. Gagne de l'XP en jouant." % rank
	if Progression.has_rank_s(place):
		return "%s : tu portes le Rang S." % rank
	var last: Dictionary = top[Progression.RANK_S_PLACES - 1] if top.size() >= Progression.RANK_S_PLACES else {}
	if last.is_empty():
		return rank
	return "%s : encore %s pour le Rang S." % [rank, _xp(int(last["xp"]) - my_xp + 1)]


# ---------------------------------------------------------------- Commun

func _message(title: String, text: String, retry: bool = false) -> void:
	_clear(_content)
	var v := P.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(P.title(title, 20, P.CREAM))
	if not text.is_empty():
		v.add_child(P.label(text, 14, Glass.PALE))
	if retry:
		v.add_child(P.spacer(6))
		var b := Glass.gold_button("Réessayer", _retry, 20, 56)
		v.add_child(b)
	_content.add_child(v)


func _retry() -> void:
	if not Online.is_online():
		await Online.connect_guest()
	_load()


func _clear(c: Control) -> void:
	for child in c.get_children():
		child.queue_free()


func _rank_name(xp: int) -> String:
	return Progression.rank(int(Progression.from_xp(xp)["level"]))


## « 3 120 XP » : milliers séparés par une espace (la police n'a pas d'espace insécable).
func _xp(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = " " + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out + " XP"


func _color_of(player: String) -> Color:
	return COLORS[absi(player.hash()) % COLORS.size()]


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_to_menu()
