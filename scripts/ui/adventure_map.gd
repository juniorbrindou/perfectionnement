extends Control
## Arcade solo : la carte d'aventure, d'après l'image peinte validée (assets/aventure/aventure.png,
## préparée par tools/aventure_image.ps1 : numéros, étoiles et « Niveau 1 » effacés).
##
## Les niveaux sont posés sur le chemin peint : une pièce dorée quand le niveau est ouvert, une
## pierre au cadenas sinon. Le panneau du bas montre le niveau choisi et ses trois difficultés ;
## « Jouer » lance la partie contre le Scribe. Chaque difficulté gagnée donne son étoile, et la
## première victoire ouvre le niveau suivant. La progression et les talents viennent du serveur
## (RPC « arcade »). Les coordonnées sont des pixels de l'image (941 px de large).

const P := preload("res://scripts/ui/ui_theme.gd")
const ART := preload("res://assets/aventure/aventure.png")
const COIN := preload("res://assets/aventure/piece.png")
const STONE := preload("res://assets/aventure/pierre.png")
const STAR := preload("res://assets/aventure/etoile.png")
const ADVENTURE_PATH := "res://data/aventure.json"
const DIFFICULTIES: Array[String] = ["lait", "manne", "solide"]
const STAKES := {"lait": 2, "manne": 5, "solide": 10}

const ART_W := 941.0
const ART_H := 1672.0
const ART_CUT := 142.0  ## L'image commence sous sa barre peinte (remplacée par TopBar).
const SKY_HIGH := Color("1a4fae")
const SKY_AT_CUT := Color("2c9ffd")  ## Ciel de l'image à la hauteur ART_CUT.

## Les niveaux sur le chemin, du bas vers le château : centre, largeur visible, ce que l'image
## y peint déjà (« piece », « pierre » ou rien) et, pour une pierre peinte, le centre de son cadenas.
const SPOTS := [
	[Vector2(265, 958), 194.0, "piece", Vector2.ZERO],
	[Vector2(462, 1002), 104.0, "", Vector2.ZERO],
	[Vector2(585, 895), 174.0, "pierre", Vector2(586, 880)],
	[Vector2(452, 842), 100.0, "", Vector2.ZERO],
	[Vector2(420, 730), 160.0, "pierre", Vector2(420, 720)],
	[Vector2(614, 678), 96.0, "", Vector2.ZERO],
	[Vector2(537, 568), 145.0, "pierre", Vector2(539, 560)],
	[Vector2(720, 440), 140.0, "pierre", Vector2(720, 430)],
]
const RIBBON := Rect2(330, 1136, 281, 56)
const CELLS := [Rect2(44, 1180, 284, 278), Rect2(333, 1180, 276, 278), Rect2(614, 1180, 288, 278)]
## Étoiles de chaque difficulté (Lait 1, Manne 2, Nourriture solide 3), à leur place peinte.
const CELL_STARS := [[Vector2(189, 1411)], [Vector2(444, 1411), Vector2(497, 1411)],
	[Vector2(711, 1411), Vector2(759, 1411), Vector2(806, 1411)]]
const CELL_STAR_W := 52.0
const PLAY := Rect2(222, 1450, 500, 112)
const STAKE_PILL := Rect2(596, 1428, 140, 46)
const BACK := Rect2(32, 1520, 114, 114)

var _chapter: Dictionary = {}
var _stars: Dictionary = {}  ## "niveau" → difficultés gagnées
var _loaded := false
var _busy := false
var _s := 1.0
var _top := 0.0
var _nodes: Array = []
var _selected := 0
var _choice := "lait"
var _ribbon: Label
var _cell_marks: Array = []
var _cell_stars: Array = []
var _stake: Label
var _play_veil: Panel
var _overlay: Control


func _ready() -> void:
	theme = P.get_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var data = JSON.parse_string(FileAccess.get_file_as_string(ADVENTURE_PATH))
	if data is Dictionary and not data.get("chapitres", []).is_empty():
		_chapter = data["chapitres"][0]
	var screen := get_viewport_rect().size
	_s = screen.x / ART_W
	_top = maxf(screen.y - ART_H * _s, 0.0)
	var bar := TopBar.attach(self)

	# Le ciel et ses nuages entre la barre du haut et l'image, comme à l'accueil.
	var art_y := _top + ART_CUT * _s
	_gradient(Rect2(0, 0, screen.x, art_y + 2), SKY_HIGH, SKY_AT_CUT)
	var clouds := SkyClouds.new()
	clouds.position = Vector2(0, bar.bottom())
	clouds.size = Vector2(screen.x, maxf(art_y - bar.bottom() + 30 * _s, 0))
	add_child(clouds)
	var art := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = ART
	atlas.region = Rect2(0, ART_CUT, ART_W, ART_H - ART_CUT)
	art.texture = atlas
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(0, art_y)
	art.size = Vector2(screen.x, (ART_H - ART_CUT) * _s)
	add_child(art)
	_gradient(Rect2(0, art_y, screen.x, 40 * _s), SKY_AT_CUT, Color(SKY_AT_CUT, 0))

	for i in mini(_levels().size(), SPOTS.size()):
		var n := LevelNode.new(i + 1, SPOTS[i], _s)
		n.position = _r(Rect2(SPOTS[i][0], Vector2.ZERO)).position - n.size / 2
		n.pressed.connect(_on_node.bind(i + 1))
		add_child(n)
		_nodes.append(n)
	_build_panel()

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_refresh()

	if not Online.is_online():
		_show_notice("L'arcade se joue en ligne", "Vérifie ta connexion à Internet, puis réessaie.", "Réessayer", _retry)
	elif not Online.has_account():
		_show_guest()
	else:
		_load_progress()


func _levels() -> Array:
	return _chapter.get("niveaux", [])


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
	if not is_inside_tree():
		return
	if r.has("erreur"):
		_show_notice("Carte indisponible", str(r["erreur"]), "Réessayer", _retry)
		return
	_stars = r.get("etoiles", {})
	_loaded = true
	var level := _current_level()
	if Session.arcade_open_level > 0 and _is_open(Session.arcade_open_level):
		level = Session.arcade_open_level
	Session.arcade_open_level = 0
	_select(level)


## Choisit un niveau : la difficulté proposée est la première qu'il reste à gagner.
func _select(level: int) -> void:
	_selected = level
	_choice = "lait"
	for d in DIFFICULTIES:
		if not d in _won(level):
			_choice = d
			break
	_refresh()


func _refresh() -> void:
	for i in _nodes.size():
		var level := i + 1
		(_nodes[i] as LevelNode).set_state(_loaded and _is_open(level), _won(level).size(), level == _selected)
	_ribbon.text = "Niveau %d" % maxi(_selected, 1)
	for i in DIFFICULTIES.size():
		var d := DIFFICULTIES[i]
		(_cell_marks[i] as Control).visible = _loaded and d == _choice
		for star in _cell_stars[i]:
			(star as TextureRect).modulate = Color.WHITE if d in _won(_selected) else LevelNode.DIM
	var stake: int = STAKES[_choice]
	_stake.text = str(stake)
	_play_veil.visible = not _loaded or _busy or Online.talents() < stake


func _on_node(level: int) -> void:
	if not _loaded or _busy:
		return
	if _is_open(level):
		_select(level)
	else:
		_toast("Gagne le niveau %d pour ouvrir celui-ci." % (level - 1))


# ---------------------------------------------------------------- Panneau du bas

func _build_panel() -> void:
	_ribbon = P.title("", RIBBON.size.y * 0.62 * _s / P.SCALE, Color("fff1d6"))
	_ribbon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_ribbon, RIBBON)

	for i in CELLS.size():
		var mark := Panel.new()
		var st := P.box(Color(1.0, 0.85, 0.4, 0.0), int(22 * _s))
		st.border_color = Color("e8a417")
		st.set_border_width_all(maxi(3, int(7 * _s)))
		mark.add_theme_stylebox_override("panel", st)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(mark, CELLS[i].grow(-6))
		_cell_marks.append(mark)
		var stars: Array = []
		for c in CELL_STARS[i]:
			var star := TextureRect.new()
			star.texture = STAR
			star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var w := CELL_STAR_W * float(STAR.get_width()) / 68.0
			_place(star, Rect2(c - Vector2(w, w) / 2, Vector2(w, w)))
			stars.append(star)
		_cell_stars.append(stars)
		var diff := DIFFICULTIES[i]
		_tap(CELLS[i], func():
			if _loaded and not _busy:
				_choice = diff
				_refresh())

	# Mise du niveau, en pastille sur le coin du bouton « Jouer ».
	var pill := Panel.new()
	var ps := P.box(Color("10235c"), int(STAKE_PILL.size.y * _s / 2))
	ps.border_color = Color("f2c14e")
	ps.set_border_width_all(maxi(2, int(3 * _s)))
	pill.add_theme_stylebox_override("panel", ps)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(pill, STAKE_PILL)
	var row := P.hbox(int(6 * _s))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var coins := TextureRect.new()
	coins.texture = TopBar.COINS
	coins.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coins.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coins.custom_minimum_size = Vector2(34, 30) * _s
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(coins)
	_stake = P.title("", 30 * _s / P.SCALE, Color.WHITE)
	_stake.autowrap_mode = TextServer.AUTOWRAP_OFF
	_stake.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_stake)

	# Bouton grisé tant que la partie ne peut pas partir (chargement, talents insuffisants).
	_play_veil = Panel.new()
	_play_veil.add_theme_stylebox_override("panel", P.box(Color(0.12, 0.1, 0.08, 0.45), int(PLAY.size.y * _s / 2)))
	_play_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_play_veil, PLAY.grow(-6))
	move_child(pill, -1)  # Au-dessus du voile, mais sous les fenêtres ajoutées ensuite.
	_tap(PLAY, _on_play)
	_tap(BACK, _to_menu)


func _on_play() -> void:
	if not _loaded or _busy:
		return
	var stake: int = STAKES[_choice]
	if Online.talents() < stake:
		_toast("Il te faut %d talents pour jouer en %s." % [stake, CardData.DIFFICULTY_LABELS[_choice]])
		return
	_busy = true
	_refresh()
	var r := await Online.arcade({"action": "commencer", "niveau": _selected, "difficulte": _choice})
	if not is_inside_tree():
		return
	if r.has("erreur"):
		_busy = false
		_refresh()
		_toast(str(r["erreur"]))
		return
	Session.arcade_start = r
	get_tree().change_scene_to_file("res://scenes/arcade_match.tscn")


# ---------------------------------------------------------------- Image

func _r(r: Rect2) -> Rect2:
	return Rect2(r.position * _s + Vector2(0, _top), r.size * _s)


func _place(c: Control, r: Rect2) -> void:
	var rr := _r(r)
	c.position = rr.position
	c.size = rr.size
	add_child(c)


func _tap(r: Rect2, action: Callable) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.pressed.connect(action)
	_place(b, r)


func _gradient(r: Rect2, from: Color, to: Color) -> void:
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.position = r.position
	tr.size = r.size
	add_child(tr)


# ---------------------------------------------------------------- Fenêtres

func _clear_overlay() -> void:
	for c in _overlay.get_children():
		c.queue_free()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _dim(alpha: float) -> void:
	var dim := ColorRect.new()
	dim.color = Color(Glass.DEEP, alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP


# ---------------------------------------------------------------- Invité, hors ligne

func _show_guest() -> void:
	var v := _notice_card("L'arcade demande un compte",
		"Crée ton compte pour affronter le Scribe sur la carte d'aventure. Tu gardes ton pseudo, tes talents et ton XP.")
	var acc := PanelContainer.new()
	acc.add_theme_stylebox_override("panel", Glass.panel_style(Glass.PANEL_DARK, 16, Glass.EDGE, 12, 10))
	acc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ah := P.hbox(10)
	var av := Glass.avatar(Online.username, Glass.ME, 42)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ah.add_child(av)
	var who := P.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var un := P.label(Online.username, 16, P.CREAM, 900, HORIZONTAL_ALIGNMENT_LEFT)
	un.autowrap_mode = TextServer.AUTOWRAP_OFF
	who.add_child(un)
	who.add_child(P.label("Invité sur ce téléphone", 13, Glass.SOFT, 800, HORIZONTAL_ALIGNMENT_LEFT))
	ah.add_child(who)
	var tal := P.label("%d talents" % Online.talents(), 15, Glass.GOLD, 900)
	tal.autowrap_mode = TextServer.AUTOWRAP_OFF
	tal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ah.add_child(tal)
	acc.add_child(ah)
	v.add_child(acc)
	v.add_child(P.spacer(6))
	v.add_child(Glass.gold_button("Créer mon compte", _open_profile.bind(0)))
	v.add_child(Glass.button("J'ai déjà un compte", _open_profile.bind(2), 19))
	v.add_child(_link("Retour à l'accueil", _to_menu))


func _show_notice(title: String, text: String, action: String, on_action: Callable) -> void:
	var v := _notice_card(title, text)
	v.add_child(P.spacer(6))
	v.add_child(Glass.gold_button(action, on_action))
	v.add_child(_link("Retour à l'accueil", _to_menu))


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
	var lock := P.circle(Glass.DEEP, 88, Glass.RING, 4)
	lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lock.z_index = 1
	var icon := Shapes.Icon.new("cadenas", Glass.GOLD, 44)
	icon.position = Vector2(P.px(22), P.px(22))
	lock.add_child(icon)
	stack.add_child(lock)
	var card := PanelContainer.new()
	var s := P.box(Color(0.05, 0.1, 0.24, 0.97), P.px(26), P.px(22), P.px(22))
	s.content_margin_top = P.px(64)
	s.border_color = Glass.RING
	s.set_border_width_all(P.px(3))
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_offset = Vector2(0, P.px(8))
	card.add_theme_stylebox_override("panel", s)
	card.custom_minimum_size = Vector2(P.px(350), 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.add_child(card)
	var v := P.vbox(14)
	card.add_child(v)
	v.add_child(P.title(title, 28, Glass.GOLD))
	v.add_child(P.label(text, 16, Glass.PALE, 800))
	return v



func _open_profile(view: int) -> void:
	Session.profile_view = view
	get_tree().change_scene_to_file("res://scenes/profile.tscn")


func _retry() -> void:
	_clear_overlay()
	await Online.connect_guest()
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- Commun

func _link(text: String, on_pressed: Callable) -> Button:
	var b := P.button(text, on_pressed, 15)
	b.flat = true
	b.custom_minimum_size = Vector2(0, P.px(44))
	b.add_theme_font_override("font", P.body_font(900))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, P.CREAM)
	return b


func _toast(text: String) -> void:
	Glass.toast(self, text)


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
		_to_menu()


# ---------------------------------------------------------------- Niveaux

## Un niveau sur le chemin : pièce dorée numérotée et ses étoiles s'il est ouvert, pierre au
## cadenas numéroté sinon. Une pierre déjà peinte dans l'image n'est pas redessinée : on n'écrit
## que son numéro ; une pièce posée dessus est un peu plus large pour la couvrir.
class LevelNode extends Control:
	signal pressed
	const DIM := Color(0.4, 0.34, 0.3)  ## Étoile pas encore gagnée.
	## Repères dans les découpes : centre de la pièce visible (192 px) et de la pierre (174 px).
	const COIN_CENTER := Vector2(105, 83)
	const COIN_W := 194.0
	const COIN_FACE := Vector2(105, 60)
	const STONE_CENTER := Vector2(95, 75)
	const STONE_W := 174.0
	const STONE_LOCK := Vector2(96, 60)

	var level := 1
	var width := 100.0  ## Largeur visible à l'écran.
	var painted := ""
	var lock := Vector2.ZERO  ## Cadenas peint, relatif au centre (écran).
	var open := false
	var won := 0
	var selected := false
	var _t := 0.0

	func _init(n: int, spot: Array, s: float) -> void:
		level = n
		width = float(spot[1]) * s
		painted = spot[2]
		if painted == "pierre":
			lock = (Vector2(spot[3]) - Vector2(spot[0])) * s
		mouse_filter = Control.MOUSE_FILTER_STOP
		size = Vector2(width, width) * 1.15

	func set_state(is_open: bool, stars: int, is_selected: bool) -> void:
		open = is_open
		won = stars
		selected = is_selected and is_open
		set_process(selected)
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		var c := size / 2
		if open:
			var w := width * (1.12 if painted == "pierre" else 1.0)
			if selected:
				# Halo qui respire sous le niveau choisi.
				var pulse := 0.75 + 0.25 * sin(_t * 3.0)
				for i in 12:
					var r := w * (0.6 + i * 0.045)
					draw_set_transform(c + Vector2(0, w * 0.05), 0, Vector2(1, 0.78))
					draw_circle(Vector2.ZERO, r, Color(1.0, 0.86, 0.4, 0.11 * pulse))
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			var k := w / COIN_W
			draw_texture_rect(COIN, Rect2(c - COIN_CENTER * k, Vector2(COIN.get_width(), COIN.get_height()) * k), false)
			_number(c + (COIN_FACE - COIN_CENTER) * k, w * 0.42, Color("4a2208"), Color("ffe6a0"))
			# Les petites étapes ne montrent leurs étoiles que choisies (sinon elles se chevauchent).
			if painted.is_empty() and not selected:
				return
			for i: int in [0, 2, 1]:
				var dx: float = (i - 1) * 0.29 * w
				var dy: float = -0.55 * w if i == 1 else -0.495 * w
				var sw: float = (0.36 if i == 1 else 0.27) * w
				_star(c + Vector2(dx, dy), sw, (i - 1) * 0.25, i < won)
		elif painted == "pierre":
			_number(c + lock, width * 0.2, Color("f4f1ea"), Color("1d1f27"))
		else:
			var k := width / STONE_W
			draw_texture_rect(STONE, Rect2(c - STONE_CENTER * k, Vector2(STONE.get_width(), STONE.get_height()) * k), false)
			_number(c + (STONE_LOCK - STONE_CENTER) * k, width * 0.2, Color("f4f1ea"), Color("1d1f27"))

	## Étoile de la découpe (68 px visibles), tournée et grisée si elle n'est pas gagnée.
	func _star(at: Vector2, w: float, angle: float, gained: bool) -> void:
		var tw := w * STAR.get_width() / 68.0
		var th := tw * STAR.get_height() / STAR.get_width()
		draw_set_transform(at, angle, Vector2.ONE)
		draw_texture_rect(STAR, Rect2(-tw / 2, -th / 2, tw, th), false, Color.WHITE if gained else DIM)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	func _number(at: Vector2, font_size: float, color: Color, outline: Color) -> void:
		var font := UiTheme.TITLE_FONT
		var fs := int(font_size)
		var t := str(level)
		var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2(at.x - ts.x / 2, at.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2)
		draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(fs * 0.12)), outline)
		draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
