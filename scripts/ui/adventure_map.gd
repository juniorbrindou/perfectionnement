extends Control
## Arcade solo : la carte d'aventure (maquettes « Arcade solo : la carte d'aventure »,
## « choisir la difficulté du niveau », « invité sans compte »).
##
## Chaque niveau se joue contre le Scribe dans l'une des trois difficultés ; chaque
## difficulté gagnée donne son étoile, et la première victoire ouvre le niveau suivant.
## La progression et les talents viennent du serveur (RPC « arcade »).

const P := preload("res://scripts/ui/ui_theme.gd")
const ADVENTURE_PATH := "res://data/aventure.json"
const DIFFICULTIES: Array[String] = ["lait", "manne", "solide"]
const STAKES := {"lait": 2, "manne": 5, "solide": 10}
## Centres des niveaux sur la maquette (390 px de large) ; MAP_TOP..MAP_BOTTOM est la
## bande de la maquette répartie sur la hauteur disponible.
const POINTS := [Vector2(195, 720), Vector2(300, 660), Vector2(190, 590), Vector2(80, 520),
	Vector2(180, 440), Vector2(300, 380), Vector2(210, 300), Vector2(100, 230)]
const MAP_TOP := 190.0
const MAP_BOTTOM := 750.0
const GRASS := Color("5fb36a")

var _chapter: Dictionary = {}
var _stars: Dictionary = {}  ## "niveau" → difficultés gagnées
var _loaded := false
var _map: MapArt
var _nodes: Array = []
var _header_stars: Label
var _play: Button
var _overlay: Control
var _sheet_level := 0
var _sheet_choice := ""
var _sheet_error: Label


func _ready() -> void:
	theme = P.get_theme()
	var data = JSON.parse_string(FileAccess.get_file_as_string(ADVENTURE_PATH))
	if data is Dictionary and not data.get("chapitres", []).is_empty():
		_chapter = data["chapitres"][0]
	var bg := ColorRect.new()
	bg.color = GRASS
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_map = MapArt.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.offset_top = P.px(96)
	_map.offset_bottom = -P.px(92)
	_map.resized.connect(_layout_nodes)
	add_child(_map)
	for i in _levels().size():
		var n := LevelNode.new(i + 1)
		n.pressed.connect(_on_node.bind(i + 1))
		_map.add_child(n)
		_nodes.append(n)

	_build_header()
	var m := P.margins(16, 0, 16, 18)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	var v := P.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_END
	m.add_child(v)
	_play = P.button("Chargement…", _on_play, 22)
	_play.custom_minimum_size = Vector2(0, P.px(62))
	_play.disabled = true
	v.add_child(_play)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_refresh()

	if not Online.is_online():
		_show_notice("L'arcade se joue en ligne", "Vérifie ta connexion à Internet, puis réessaie.", "Réessayer", _retry)
	elif not Online.has_email():
		_show_guest()
	else:
		_load_progress()


func _levels() -> Array:
	return _chapter.get("niveaux", [])


func _level_name(level: int) -> String:
	for l in _levels():
		if int(l["id"]) == level:
			return str(l["nom"])
	return "Niveau %d" % level


func _won(level: int) -> Array:
	return _stars.get(str(level), [])


func _is_open(level: int) -> bool:
	return is_open(_stars, level)


func _current_level() -> int:
	return current_level(_stars, _levels().size())


## Même règle que le serveur : le niveau 1 est ouvert, puis il faut une étoile au précédent.
static func is_open(stars: Dictionary, level: int) -> bool:
	return level == 1 or not stars.get(str(level - 1), []).is_empty()


## Le niveau à jouer : le premier ouvert sans étoile, sinon le dernier ouvert.
static func current_level(stars: Dictionary, count: int) -> int:
	var last := 1
	for level in range(1, count + 1):
		if not is_open(stars, level):
			break
		last = level
		if stars.get(str(level), []).is_empty():
			return level
	return last


func _load_progress() -> void:
	var r := await Online.arcade({"action": "etat"})
	if r.has("erreur"):
		_play.text = "Réessayer"
		_play.disabled = false
		_toast(r["erreur"])
		return
	_stars = r.get("etoiles", {})
	_loaded = true
	_refresh()
	if Session.arcade_open_level > 0:
		var level := Session.arcade_open_level
		Session.arcade_open_level = 0
		if _is_open(level):
			_show_level(level)


func _on_play() -> void:
	if _loaded:
		_show_level(_current_level())
	else:
		get_tree().reload_current_scene()


func _refresh() -> void:
	var total := 0
	for i in _nodes.size():
		var level := i + 1
		var won := _won(level).size()
		total += won
		var state := LevelNode.State.LOCKED
		if _loaded and _is_open(level):
			state = LevelNode.State.CURRENT if level == _current_level() else LevelNode.State.OPEN
		_nodes[i].set_state(state, won)
	_header_stars.text = "%d / %d" % [total, _levels().size() * 3]
	if _loaded:
		_play.text = "Jouer le niveau %d" % _current_level()
		_play.disabled = false


func _layout_nodes() -> void:
	for i in _nodes.size():
		var n: LevelNode = _nodes[i]
		n.position = _map.to_local_point(POINTS[i]) - n.size / 2


func _on_node(level: int) -> void:
	if _loaded and _is_open(level):
		_show_level(level)
	elif _loaded:
		_toast("Gagne le niveau %d pour ouvrir celui-ci." % (level - 1))


# ---------------------------------------------------------------- En-tête

func _build_header() -> void:
	var bar := PanelContainer.new()
	var s := P.box(P.VIOLET, 0, P.px(16), P.px(12))
	s.corner_radius_bottom_left = P.px(26)
	s.corner_radius_bottom_right = P.px(26)
	s.content_margin_top = P.px(40)
	s.shadow_color = Color(P.NIGHT, 0.4)
	s.shadow_offset = Vector2(0, P.px(6))
	bar.add_theme_stylebox_override("panel", s)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var row := P.hbox(10)
	bar.add_child(row)
	var back := P.button("‹", _to_menu, 26, "GhostButton")
	back.custom_minimum_size = Vector2(P.px(40), P.px(40))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(back)
	var titles := P.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(P.title(str(_chapter.get("nom", "Aventure")), 22, P.YELLOW, HORIZONTAL_ALIGNMENT_LEFT))
	titles.add_child(P.label(str(_chapter.get("resume", "")), 13, P.LILAC, 800, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(titles)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", P.box(Color(1, 1, 1, 0.12), P.px(999), P.px(12), P.px(6)))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph := P.hbox(5)
	ph.add_child(Shapes.Stars.new(1, 1, 15))
	_header_stars = P.label("", 14, P.CREAM, 900)
	_header_stars.autowrap_mode = TextServer.AUTOWRAP_OFF
	ph.add_child(_header_stars)
	pill.add_child(ph)
	row.add_child(pill)


# ---------------------------------------------------------------- Panneau du niveau

func _clear_overlay() -> void:
	for c in _overlay.get_children():
		c.queue_free()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _dim(alpha: float) -> void:
	var dim := ColorRect.new()
	dim.color = Color(P.NIGHT, alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP


func _show_level(level: int) -> void:
	_sheet_level = level
	if _sheet_choice.is_empty() or not _sheet_choice in DIFFICULTIES:
		_sheet_choice = "lait"
		for d in DIFFICULTIES:
			if not d in _won(level):
				_sheet_choice = d
				break
	_build_sheet()


func _build_sheet() -> void:
	_clear_overlay()
	_dim(0.55)
	var level := _sheet_level
	_overlay.add_child(_talents_pill())

	var sheet := PanelContainer.new()
	var s := P.box(P.VIOLET, 0, P.px(18), P.px(22))
	s.corner_radius_top_left = P.px(30)
	s.corner_radius_top_right = P.px(30)
	s.border_color = P.YELLOW
	s.border_width_top = P.px(4)
	s.content_margin_bottom = P.px(14)
	sheet.add_theme_stylebox_override("panel", s)
	sheet.anchor_top = 1.0
	sheet.anchor_bottom = 1.0
	sheet.anchor_right = 1.0
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(sheet)
	var v := P.vbox(0)
	sheet.add_child(v)

	var head := P.hbox(12)
	var badge := P.circle(P.YELLOW, 52)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var num := P.title(str(level), 26, P.NIGHT)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(num)
	head.add_child(badge)
	var titles := P.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_child(P.title(_level_name(level), 26, P.YELLOW, HORIZONTAL_ALIGNMENT_LEFT))
	titles.add_child(P.label(_content_text(), 14, P.LILAC, 800, HORIZONTAL_ALIGNMENT_LEFT))
	head.add_child(titles)
	v.add_child(head)

	v.add_child(P.spacer(16))
	var foe := PanelContainer.new()
	foe.add_theme_stylebox_override("panel", P.box(Color(1, 1, 1, 0.08), P.px(14), P.px(12), P.px(8)))
	foe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fh := P.hbox(10)
	var av := scribe_avatar(38)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fh.add_child(av)
	var fl := P.label("Ton adversaire : le Scribe. Il se trompe plus souvent quand la difficulté monte.", 14, P.CREAM, 800, HORIZONTAL_ALIGNMENT_LEFT)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(fl)
	foe.add_child(fh)
	v.add_child(foe)

	v.add_child(P.spacer(18))
	v.add_child(P.title("Choisis ta difficulté", 18, P.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(P.spacer(10))
	var choices := P.vbox(10)
	for i in DIFFICULTIES.size():
		choices.add_child(_difficulty_button(DIFFICULTIES[i], i + 1, level))
	v.add_child(choices)

	v.add_child(P.spacer(14))
	var hint := "Chaque difficulté gagnée donne son étoile."
	if level < _levels().size() and _is_open(level + 1):
		hint += " Le niveau %d est déjà ouvert." % (level + 1)
	v.add_child(P.label(hint, 14, P.LILAC))
	_sheet_error = P.label("", 14, Color("ff8fb8"), 900)
	_sheet_error.visible = false
	v.add_child(_sheet_error)

	v.add_child(P.spacer(16))
	var stake: int = STAKES[_sheet_choice]
	var enough := Online.talents() >= stake
	var go := P.button("Jouer en %s : %d talents" % [CardData.DIFFICULTY_LABELS[_sheet_choice], stake] if enough
		else "Il te faut %d talents" % stake, func(): pass, 22)
	go.custom_minimum_size = Vector2(0, P.px(62))
	go.disabled = not enough
	go.pressed.connect(_start.bind(go))
	v.add_child(go)
	var back := _link("Retour à la carte", _clear_overlay)
	v.add_child(back)


func _content_text() -> String:
	var books: Array[String] = []
	books.assign(_chapter.get("livres", []))
	var pool := Session.bank.cards_by_id.values().filter(func(c: CardData):
		return c.difficulty == _sheet_choice and c.books.any(func(b): return b in books))
	# Même règle que le serveur : toute la Bible tant que le chapitre n'a pas assez de cartes.
	if pool.size() >= Duel.HAND_SIZE * 2:
		return "Questions sur %s" % ", ".join(books)
	return "Questions sur toute la Bible"


func _difficulty_button(diff: String, rank: int, level: int) -> Button:
	var selected := diff == _sheet_choice
	var won := diff in _won(level)
	var color := P.difficulty_color(diff)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, P.px(64))
	var s := P.box(color, P.px(16), P.px(14), 0)
	s.border_color = color.darkened(0.35)
	s.border_width_bottom = P.px(4)
	if selected:
		s.border_color = P.CREAM
		s.set_border_width_all(P.px(4))
		s.shadow_color = Color(P.YELLOW, 0.45)
		s.shadow_size = P.px(6)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, s)
	var dark := diff == "manne"
	var text_color := P.NIGHT if dark else P.CREAM
	var row := P.hbox(12)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = P.px(14)
	row.offset_right = -P.px(14)
	var name_label := P.title(CardData.DIFFICULTY_LABELS[diff], 21, text_color, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name_label)
	var stars := Shapes.Stars.new(rank, 3, 17)
	stars.on_color = P.NIGHT if dark else P.YELLOW
	stars.off_color = Color(P.NIGHT, 0.3) if dark else Color(1, 1, 1, 0.35)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stars)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", P.box(Color(P.NIGHT, 0.15 if dark else 0.3), P.px(999), P.px(10), P.px(4)))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := P.label("Gagné" if won else "Mise %d" % STAKES[diff], 14, text_color, 900)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.add_child(tl)
	row.add_child(tag)
	b.add_child(row)
	b.pressed.connect(func():
		_sheet_choice = diff
		_build_sheet())
	return b


func _start(go: Button) -> void:
	go.disabled = true
	go.text = "Préparation de la partie…"
	var r := await Online.arcade({"action": "commencer", "niveau": _sheet_level, "difficulte": _sheet_choice})
	if r.has("erreur"):
		_sheet_error.text = r["erreur"]
		_sheet_error.visible = true
		go.disabled = false
		go.text = "Réessayer"
		return
	Session.arcade_start = r
	get_tree().change_scene_to_file("res://scenes/arcade_match.tscn")


# ---------------------------------------------------------------- Invité, hors ligne

func _show_guest() -> void:
	var v := _notice_card("L'arcade demande un compte",
		"Crée ton compte pour affronter le Scribe sur la carte d'aventure. Tu gardes ton pseudo, tes talents et ton XP.")
	var acc := PanelContainer.new()
	acc.add_theme_stylebox_override("panel", P.box(Color(1, 1, 1, 0.08), P.px(16), P.px(12), P.px(10)))
	acc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ah := P.hbox(10)
	var av := P.avatar(Online.username, P.TEAL, 42)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ah.add_child(av)
	var who := P.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var un := P.label(Online.username, 16, P.CREAM, 900, HORIZONTAL_ALIGNMENT_LEFT)
	un.autowrap_mode = TextServer.AUTOWRAP_OFF
	who.add_child(un)
	who.add_child(P.label("Invité sur ce téléphone", 13, P.LILAC, 800, HORIZONTAL_ALIGNMENT_LEFT))
	ah.add_child(who)
	var tal := P.label("%d talents" % Online.talents(), 15, P.YELLOW, 900)
	tal.autowrap_mode = TextServer.AUTOWRAP_OFF
	tal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ah.add_child(tal)
	acc.add_child(ah)
	v.add_child(acc)
	v.add_child(P.spacer(6))
	v.add_child(P.button("Créer mon compte", _open_profile.bind(1), 22))
	v.add_child(P.button("J'ai déjà un compte", _open_profile.bind(2), 19, "GhostButton"))
	_add_home_link()


func _show_notice(title: String, text: String, action: String, on_action: Callable) -> void:
	var v := _notice_card(title, text)
	v.add_child(P.spacer(6))
	v.add_child(P.button(action, on_action, 22))
	_add_home_link()


func _notice_card(title: String, text: String) -> VBoxContainer:
	_clear_overlay()
	_dim(0.72)
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_theme_constant_override("margin_left", P.px(20))
	holder.add_theme_constant_override("margin_right", P.px(20))
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(holder)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(center)
	# Le médaillon du cadenas chevauche le haut de la carte (séparation négative).
	var stack := P.vbox(-44)
	center.add_child(stack)
	var lock := P.circle(P.NIGHT, 88, P.YELLOW, 4)
	lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lock.z_index = 1
	var icon := Shapes.Icon.new("cadenas", P.YELLOW, 44)
	icon.position = Vector2(P.px(22), P.px(22))
	lock.add_child(icon)
	stack.add_child(lock)
	var card := PanelContainer.new()
	var s := P.box(P.VIOLET, P.px(26), P.px(22), P.px(22))
	s.content_margin_top = P.px(64)
	s.border_color = P.YELLOW
	s.set_border_width_all(P.px(4))
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_offset = Vector2(0, P.px(8))
	card.add_theme_stylebox_override("panel", s)
	card.custom_minimum_size = Vector2(P.px(350), 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.add_child(card)
	var v := P.vbox(14)
	card.add_child(v)
	v.add_child(P.title(title, 28, P.YELLOW))
	v.add_child(P.label(text, 16, P.LILAC, 800))
	return v


func _add_home_link() -> void:
	var m := P.margins(0, 0, 0, 30)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(m)
	var v := P.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_END
	m.add_child(v)
	v.add_child(_link("Retour à l'accueil", _to_menu))


func _open_profile(view: int) -> void:
	Session.profile_view = view
	get_tree().change_scene_to_file("res://scenes/profile.tscn")


func _retry() -> void:
	_clear_overlay()
	await Online.connect_guest()
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- Commun

func _talents_pill() -> Control:
	var pill := PanelContainer.new()
	var s := P.box(P.VIOLET, P.px(999), P.px(6), P.px(5))
	s.border_color = P.YELLOW
	s.set_border_width_all(P.px(2))
	pill.add_theme_stylebox_override("panel", s)
	pill.anchor_left = 1.0
	pill.anchor_right = 1.0
	pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pill.offset_right = -P.px(16)
	pill.offset_top = P.px(44)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := P.hbox(6)
	var coin := P.circle(P.YELLOW, 24)
	var t := P.title("T", 15, P.NIGHT)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin.add_child(t)
	row.add_child(coin)
	var l := P.label("%d talents" % Online.talents(), 15, P.CREAM, 900)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	row.add_child(P.spacer(0))
	pill.add_child(row)
	return pill


func _link(text: String, on_pressed: Callable) -> Button:
	var b := P.button(text, on_pressed, 15)
	b.flat = true
	b.custom_minimum_size = Vector2(0, P.px(44))
	b.add_theme_font_override("font", P.body_font(900))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, P.CREAM)
	return b


func _toast(text: String) -> void:
	var box := PanelContainer.new()
	var s := P.box(P.NIGHT, P.px(18), P.px(18), P.px(12))
	s.border_color = P.YELLOW
	s.set_border_width_all(P.px(3))
	box.add_theme_stylebox_override("panel", s)
	box.anchor_left = 0.08
	box.anchor_right = 0.92
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(P.title(text, 18, P.CREAM))
	add_child(box)
	var t := box.create_tween()
	t.tween_interval(1.8)
	t.tween_property(box, "modulate:a", 0.0, 0.4)
	t.tween_callback(box.queue_free)


## Pastille du Scribe : rouleau sur fond parchemin.
static func scribe_avatar(diameter: float) -> Control:
	var c := P.circle(Color("e7c98a"), diameter, P.CREAM, 3)
	var icon := Shapes.Icon.new("scribe", Color("4a3418"), diameter * 0.6)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(icon)
	return c


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _sheet_level > 0 and _overlay.get_child_count() > 0 and Online.has_email():
			_sheet_level = 0
			_clear_overlay()
		else:
			_to_menu()


# ---------------------------------------------------------------- Dessin de la carte

## Le décor : prairie, jardin, arche, pays de Canaan et le chemin entre les niveaux.
class MapArt extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	## Point de la maquette (390 px de large) → position dans ce contrôle.
	func to_local_point(p: Vector2) -> Vector2:
		var t := (p.y - MAP_TOP) / (MAP_BOTTOM - MAP_TOP)
		return Vector2(p.x / 390.0 * size.x, t * size.y)

	func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
		draw_set_transform(center, 0, radii / radii.x)
		draw_circle(Vector2.ZERO, radii.x, color)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	func _caption(text: String, at: Vector2, color: Color) -> void:
		var font := UiTheme.body_font(900)
		var fs := UiTheme.px(12)
		draw_string(font, at + Vector2(0, UiTheme.px(1)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

	func _draw() -> void:
		if size.x < 40 or size.y < 40:
			return
		var k := size.x / 390.0
		# Jardin d'Éden (en haut à gauche), arche (à droite), pays de Canaan (en bas).
		_ellipse(to_local_point(Vector2(55, 170)), Vector2(85, 60) * k, Color("3e9150"))
		_ellipse(to_local_point(Vector2(29, 160)), Vector2(17, 23) * k, Color("2f7a3f"))
		_ellipse(to_local_point(Vector2(72, 152)), Vector2(20, 27) * k, Color("2f7a3f"))
		_caption("Le jardin d'Éden", to_local_point(Vector2(12, 205)), UiTheme.CREAM)
		var ark := to_local_point(Vector2(317, 490))
		var hull := PackedVector2Array([ark + Vector2(-55, -18) * k, ark + Vector2(55, -18) * k, ark + Vector2(40, 18) * k, ark + Vector2(-40, 18) * k])
		draw_colored_polygon(hull, Color("8a5a2b"))
		draw_rect(Rect2(ark + Vector2(-25, -42) * k, Vector2(50, 26) * k), Color("a46d36"))
		_caption("L'arche de Noé", to_local_point(Vector2(270, 530)), UiTheme.CREAM)
		_ellipse(to_local_point(Vector2(80, 645)), Vector2(60, 35) * k, Color("e7c98a"))
		_caption("Le pays de Canaan", to_local_point(Vector2(26, 700)), Color("4a3418"))

		var curve := Curve2D.new()
		var pts: Array[Vector2] = []
		for p in POINTS:
			pts.append(to_local_point(p))
		for i in pts.size():
			var prev := pts[maxi(i - 1, 0)]
			var next := pts[mini(i + 1, pts.size() - 1)]
			var tangent := (next - prev) * 0.25
			curve.add_point(pts[i], -tangent, tangent)
		var line := curve.tessellate()
		var outer := Color("b58552")
		draw_polyline(line, outer, 26 * k, true)
		draw_polyline(line, Color("d6a86f"), 16 * k, true)
		# Pointillés : des coupures régulières dans le sable du chemin.
		var length := curve.get_baked_length()
		var d := 0.0
		var step := 28.0 * k
		while d < length:
			var a := curve.sample_baked(d + 18 * k)
			var b := curve.sample_baked(minf(d + step, length))
			if d + 18 * k < length:
				draw_line(a, b, outer, 16 * k, true)
			d += step


## Un niveau sur la carte : pastille numérotée et ses étoiles.
class LevelNode extends Control:
	signal pressed
	enum State { LOCKED, OPEN, CURRENT }
	var level := 1
	var state := State.LOCKED
	var stars := 0

	func _init(n: int) -> void:
		level = n
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(UiTheme.px(80), UiTheme.px(80))
		size = custom_minimum_size

	func set_state(s: State, won: int) -> void:
		state = s
		stars = won
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		var c := size / 2
		var current := state == State.CURRENT
		var r := UiTheme.px(34 if current else 24)
		var fill := UiTheme.VIOLET
		var ring := UiTheme.YELLOW
		var text_color := UiTheme.CREAM
		if state == State.LOCKED:
			fill = Color("8d86a3")
			ring = Color("d9d4e6")
		elif current:
			draw_circle(c + Vector2(0, UiTheme.px(6)), r + UiTheme.px(5), UiTheme.EMBER)
			draw_circle(c, r + UiTheme.px(9), Color(UiTheme.YELLOW, 0.35))
			fill = UiTheme.YELLOW
			ring = UiTheme.CREAM
			text_color = UiTheme.NIGHT
		draw_circle(c, r + UiTheme.px(4 if not current else 5), ring)
		draw_circle(c, r, fill)
		var font := UiTheme.TITLE_FONT
		var fs := UiTheme.px(30 if current else 22)
		var t := str(level)
		var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, Vector2(c.x - ts.x / 2, c.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		if state != State.LOCKED and stars > 0:
			var s := UiTheme.px(13)
			for i in 3:
				var sc := Vector2(c.x + (i - 1) * (s + UiTheme.px(2)), c.y - r - UiTheme.px(12))
				draw_colored_polygon(Shapes.Stars.star_points(sc, s / 2), UiTheme.YELLOW if i < stars else Color(1, 1, 1, 0.45))
