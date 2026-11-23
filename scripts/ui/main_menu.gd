extends Control
## Écran d'accueil, d'après l'illustration validée (assets/accueil/accueil.png).
##
## L'image porte le décor, le titre et les cartes des modes. Le code pose par-dessus ce
## qui change (pseudo, talents, progression de l'aventure, pain quotidien), rend les
## cartes touchables et les anime : elles s'allument à l'arrivée, l'Aventure respire et un
## reflet la traverse, une carte touchée se soulève. Les coordonnées ci-dessous sont des
## pixels de l'image (941 px de large).

const P := preload("res://scripts/ui/ui_theme.gd")
const Map := preload("res://scripts/ui/adventure_map.gd")
const ART := preload("res://assets/accueil/accueil.png")
const ADVENTURE_PATH := "res://data/aventure.json"

const ART_W := 941.0

const AVATAR := Rect2(46, 18, 124, 124)
const NAME_PATCH := Rect2(186, 34, 292, 102)  ## Pseudo, niveau et barre d'XP de l'image.
const PROFILE_TAP := Rect2(40, 18, 444, 124)
const CROWN := Rect2(200, 76, 36, 32)
const XP_BAR := Rect2(200, 115, 232, 13)
const TALENT_PATCH := Rect2(604, 43, 96, 44)
const TALENT_PILL := Rect2(500, 32, 214, 92)
const BELL := Rect2(751, 35, 74, 74)
const GEAR := Rect2(842, 35, 74, 74)
const LOGO_GLOW := Rect2(300, 150, 340, 180)
const ADVENTURE := Rect2(28, 583, 888, 384)
const LEVEL_PILL := Rect2(489, 796, 394, 54)
const STAR_ON := Rect2(745, 801, 44, 42)
const STAR_OFF := Rect2(826, 801, 44, 42)
const TWO := Rect2(28, 1000, 276, 332)
const ONLINE := Rect2(330, 1000, 279, 332)
const ROOMS := Rect2(636, 1000, 280, 332)
const ONLINE_BUTTON := Rect2(376, 1260, 191, 54)
const ROOMS_BUTTON := Rect2(680, 1260, 191, 54)
const BREAD := Rect2(25, 1362, 890, 143)
const BREAD_TEXT := Rect2(298, 1432, 494, 50)
const CHECK := Rect2(794, 1394, 90, 90)

const PANEL_BLUE := Color("1e3c6e")
const PARCHMENT := Color("fcda9f")
const INK := Color("3a2412")
const SKY_HIGH := Color("1a4fae")
const SKY_LOW := Color("296dd7")  ## Ciel en haut de l'image.
const ART_H := 1672.0
const NAV_TOP := 1526.0  ## Barre d'onglets de l'image, de NAV_TOP à ART_H.
## Onglets de la barre du bas (abscisses dans l'image).
const NAV_TABS := [
	[30.0, 200.0, ""],
	[210.0, 390.0, "Le classement arrive bientôt."],
	[395.0, 580.0, "Les récompenses arrivent bientôt."],
	[585.0, 760.0, "Les règles du jeu arrivent bientôt."],
	[765.0, 915.0, "profil"],
]

var _s := 1.0  ## Échelle image → écran.
var _top := 0.0  ## Décalage vertical de l'image.
var _name: Label
var _initial: Label
var _level: Label
var _xp_fill: Panel
var _talents: Label
var _level_text: Label
var _stars: Array = []
var _bread_text: Label
var _check: Control
var _check_patch: Control
var _adventure: Control
var _cards: Array = []


func _ready() -> void:
	theme = P.get_theme()
	# L'image est réduite à l'écran : les mipmaps évitent le crénelage.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var screen := get_viewport_rect().size
	_s = screen.x / ART_W
	# L'image entière (barre d'onglets comprise) est calée en bas de l'écran. Un écran plus
	# allongé qu'elle (19,5:9 contre 16:9) gagne du ciel en haut, où passent des nuages.
	var art_h := ART_H * _s
	_top = maxf(screen.y - art_h, 0.0)
	_add_gradient(Rect2(0, 0, screen.x, _top + 2), SKY_HIGH, SKY_LOW)
	var clouds := Clouds.new()
	clouds.position = Vector2.ZERO
	clouds.size = Vector2(screen.x, _top + 30 * _s)
	add_child(clouds)
	_add_crop(Rect2(0, 0, ART_W, ART_H), Rect2(0, _top, screen.x, art_h))
	_add_gradient(Rect2(0, _top, screen.x, 16 * _s), SKY_LOW, Color(SKY_LOW, 0))
	_build_nav(_top + NAV_TOP * _s)

	var glow := Shapes.Glow.new()
	glow.color = Color(1.0, 0.92, 0.65, 0.5)
	glow.radius_ratio = 0.5
	_place(glow, LOGO_GLOW)
	add_child(glow)
	var gt := glow.create_tween().set_loops()
	gt.tween_property(glow, "modulate:a", 0.25, 1.8).set_trans(Tween.TRANS_SINE)
	gt.tween_property(glow, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)

	_build_top_bar()
	_build_cards()
	_build_bread()
	_refresh()
	Online.account_changed.connect(_refresh)
	Online.state_changed.connect(_on_online_state)
	Online.bread_received.connect(_on_bread)
	_load_progress()
	_deal()


# ---------------------------------------------------------------- Image

func _r(r: Rect2) -> Rect2:
	return Rect2(r.position * _s + Vector2(0, _top), r.size * _s)


func _place(c: Control, r: Rect2) -> void:
	var rr := _r(r)
	c.position = rr.position
	c.size = rr.size


func _crop_texture(region: Rect2) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = ART
	t.region = region
	return t


func _texture_rect(region: Rect2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _crop_texture(region)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _add_crop(region: Rect2, screen_rect: Rect2) -> TextureRect:
	var tr := _texture_rect(region)
	tr.position = screen_rect.position
	tr.size = screen_rect.size
	add_child(tr)
	return tr


## Onglets de la barre du bas de l'image.
func _build_nav(y: float) -> void:
	for tab in NAV_TABS:
		var message: String = tab[2]
		if message.is_empty():
			continue
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		b.position = Vector2(tab[0] * _s, y)
		b.size = Vector2((tab[1] - tab[0]) * _s, (ART_H - NAV_TOP) * _s)
		b.pressed.connect(_open_profile if message == "profil" else _toast.bind(message))
		add_child(b)


## Dégradé vertical, du haut vers le bas.
func _add_gradient(screen_rect: Rect2, from: Color, to: Color) -> void:
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
	tr.position = screen_rect.position
	tr.size = screen_rect.size
	add_child(tr)


## Pièce posée sur une carte : rectangle de l'image, relatif à la carte.
func _on_card(card_region: Rect2, r: Rect2, c: Control, parent: Control) -> void:
	c.position = (r.position - card_region.position) * _s
	c.size = r.size * _s
	parent.add_child(c)


func _patch(color: Color, radius_img: float) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", P.box(color, int(radius_img * _s)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Texte dont la taille est donnée en pixels de l'image, pour s'aligner sur ses textes.
func _text(text: String, img_px: float, color: Color, weight: int = 900) -> Label:
	var l := P.label(text, img_px * _s / P.SCALE, color, weight, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


# ---------------------------------------------------------------- Barre du haut

func _build_top_bar() -> void:
	# Chaque pièce reprend la place exacte de celle de l'image qu'elle remplace.
	var patch := _patch(PANEL_BLUE, 10)
	_place(patch, NAME_PATCH)
	add_child(patch)
	_name = _text("", 30, P.CREAM)
	_place(_name, Rect2(200, 38, 270, 34))
	add_child(_name)
	var crown := _texture_rect(CROWN)
	_place(crown, CROWN)
	add_child(crown)
	_level = _text("Niveau 1", 25, P.CREAM, 800)
	_place(_level, Rect2(242, 76, 220, 32))
	add_child(_level)
	var bar := _patch(Color("2c3b52"), 6)
	_place(bar, XP_BAR)
	add_child(bar)
	_xp_fill = _patch(Color("f6b93b"), 6)
	_xp_fill.position = Vector2.ZERO
	_xp_fill.size = Vector2(0, bar.size.y)
	bar.add_child(_xp_fill)

	var avatar := Control.new()
	_place(avatar, AVATAR)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(avatar)
	var ring := Panel.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", _round(Color("1f8f8c"), Color("f6c24a"), AVATAR.size.x * _s))
	avatar.add_child(ring)
	_initial = P.title("", 26, P.CREAM)
	_initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(_initial)

	var tp := _patch(Color("1f3a6b"), 8)
	_place(tp, TALENT_PATCH)
	add_child(tp)
	_talents = _text("", 38, P.CREAM)
	_talents.set_anchors_preset(Control.PRESET_FULL_RECT)
	tp.add_child(_talents)

	_tap_zone(PROFILE_TAP, _open_profile)
	_tap_zone(TALENT_PILL, func(): _toast("Les talents se gagnent en jouant, et 10 arrivent chaque jour avec le pain quotidien."))
	_tap_zone(BELL, func(): _toast("Aucune notification pour l'instant."))
	_tap_zone(GEAR, _open_profile)


func _round(fill: Color, border: Color, diameter: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(int(diameter))
	s.border_color = border
	s.set_border_width_all(int(maxf(3, 6 * _s)))
	s.anti_aliasing = true
	return s


func _tap_zone(r: Rect2, action: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_place(b, r)
	b.pressed.connect(action)
	add_child(b)
	return b


func _open_profile() -> void:
	get_tree().change_scene_to_file("res://scenes/profile.tscn")


# ---------------------------------------------------------------- Cartes des modes

func _build_cards() -> void:
	_adventure = _card(ADVENTURE, 30, _go.bind("res://scenes/adventure.tscn"))
	var pill := _patch(Color(0.09, 0.07, 0.07, 0.92), 26)
	_on_card(ADVENTURE, LEVEL_PILL, pill, _adventure)
	_level_text = _text("Genèse, niveau 1/8", 25, P.CREAM)
	_on_card(ADVENTURE, Rect2(508, 798, 232, 50), _level_text, _adventure)
	_stars.clear()
	for x in [745.0, 787.0, 827.0]:
		var star := _texture_rect(STAR_OFF)
		_on_card(ADVENTURE, Rect2(x, STAR_ON.position.y, STAR_ON.size.x, STAR_ON.size.y), star, _adventure)
		_stars.append(star)
	_add_shine(_adventure, 30)
	# L'Aventure respire doucement (jamais en dessous de sa taille : l'image reste cachée).
	var bt := _adventure.create_tween().set_loops()
	bt.tween_property(_adventure, "scale", Vector2(1.015, 1.015), 1.9).set_trans(Tween.TRANS_SINE)
	bt.tween_property(_adventure, "scale", Vector2.ONE, 1.9).set_trans(Tween.TRANS_SINE)

	_card(TWO, 26, _go.bind("res://scenes/local_setup.tscn"))
	var online := _card(ONLINE, 26, func(): _toast("Les parties en ligne arrivent bientôt."))
	_soon(online, ONLINE, ONLINE_BUTTON, Color("eef3e2"))
	var rooms := _card(ROOMS, 26, func(): _toast("Les salons arrivent bientôt."))
	_soon(rooms, ROOMS, ROOMS_BUTTON, Color("f6e4fb"))


## Une carte de l'image, touchable : elle se soulève quand on la touche.
func _card(region: Rect2, radius_img: float, action: Callable) -> Control:
	var card := Control.new()
	_place(card, region)
	card.pivot_offset = card.size / 2
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var art := _texture_rect(region)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(art)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.z_index = 2
	b.button_down.connect(func():
		var t := card.create_tween()
		t.tween_property(card, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.button_up.connect(func():
		var t := card.create_tween()
		t.tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.pressed.connect(action)
	card.add_child(b)
	card.set_meta("radius", radius_img)
	_cards.append(card)
	return card


## Mode pas encore disponible : son bouton devient « Bientôt ».
func _soon(card: Control, region: Rect2, button: Rect2, fill: Color) -> void:
	var p := _patch(fill, button.size.y / 2)
	_on_card(region, button, p, card)
	var row := P.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(row)
	var lock := Shapes.Icon.new("cadenas", Color("33264f"), 16)
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lock)
	row.add_child(_text("Bientôt", 28, Color("33264f")))


## Reflet qui traverse la carte de temps en temps.
func _add_shine(card: Control, radius_img: float) -> void:
	var mask := Panel.new()
	mask.add_theme_stylebox_override("panel", P.box(Color.WHITE, int(radius_img * _s)))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(mask)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.38))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	var band := TextureRect.new()
	band.texture = tex
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(card.size.x * 0.35, card.size.y * 1.8)
	band.rotation_degrees = 18
	band.position = Vector2(-band.size.x * 2, -card.size.y * 0.4)
	mask.add_child(band)
	var t := band.create_tween().set_loops()
	t.tween_interval(2.5)
	t.tween_property(band, "position:x", card.size.x * 1.3, 1.1).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func(): band.position.x = -band.size.x * 2)


## Arrivée : les cartes s'allument l'une après l'autre.
func _deal() -> void:
	for i in _cards.size():
		var c: Control = _cards[i]
		c.modulate = Color(1.7, 1.6, 1.3)
		var t := c.create_tween()
		t.tween_interval(0.12 * i + 0.1)
		t.tween_property(c, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)


func _go(scene: String) -> void:
	get_tree().change_scene_to_file(scene)


# ---------------------------------------------------------------- Pain quotidien

func _build_bread() -> void:
	var bread := _card(BREAD, 18, func(): _toast("10 talents arrivent chaque jour, à ta première connexion."))
	var patch := _patch(PARCHMENT, 10)
	_on_card(BREAD, BREAD_TEXT, patch, bread)
	_bread_text = _text("", 27, INK, 800)
	_bread_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bread_text.offset_left = 10 * _s
	patch.add_child(_bread_text)
	_check_patch = _patch(PARCHMENT, 45)
	_on_card(BREAD, CHECK, _check_patch, bread)
	_check = _texture_rect(CHECK)
	_check.pivot_offset = CHECK.size * _s / 2
	_on_card(BREAD, CHECK, _check, bread)


func _on_bread(gain: int) -> void:
	Online.bread_today = true
	Online.bread_gain = gain
	_refresh()
	_check.scale = Vector2(0.2, 0.2)
	var t := _check.create_tween()
	t.tween_property(_check, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- Données

func _on_online_state(_s2) -> void:
	_refresh()
	if Online.is_online():
		_load_progress()


func _refresh() -> void:
	var online: bool = Online.is_online()
	_name.text = Online.username if online else ("Connexion…" if Online.state == Online.State.CONNECTING else "Hors ligne")
	_initial.text = (Online.username.substr(0, 1) if online else "?").to_upper()
	_talents.text = str(Online.talents()) if online else "–"
	var p := Progression.from_xp(Online.xp() if online else 0)
	_level.text = "Niveau %d" % p["level"]
	var ratio := float(p["in_level"]) / float(p["to_next"])
	var fill_w := XP_BAR.size.x * _s * ratio
	_xp_fill.visible = ratio > 0.0
	# Un minimum visible, pour que la barre ne paraisse pas cassée à 1 XP.
	_xp_fill.size.x = maxf(fill_w, XP_BAR.size.y * _s)
	if Online.bread_gain > 0:
		_bread_text.text = "Tu as reçu %d talents !" % Online.bread_gain
	elif Online.bread_today:
		_bread_text.text = "Déjà reçu. Reviens demain !"
	else:
		_bread_text.text = "Connecte-toi pour le recevoir."
	var shown := Online.bread_today
	_check.visible = shown
	_check_patch.visible = not shown


func _load_progress() -> void:
	if not Online.is_online() or not Online.has_account():
		return
	var r := await Online.arcade({"action": "etat"})
	if r.has("erreur") or not is_inside_tree():
		return
	var stars: Dictionary = r.get("etoiles", {})
	var count := 8
	var data = JSON.parse_string(FileAccess.get_file_as_string(ADVENTURE_PATH))
	if data is Dictionary and not data.get("chapitres", []).is_empty():
		count = data["chapitres"][0].get("niveaux", []).size()
	var level := Map.current_level(stars, count)
	_level_text.text = "Genèse, niveau %d/%d" % [level, count]
	var won: Array = stars.get(str(level), [])
	for i in 3:
		(_stars[i] as TextureRect).texture = _crop_texture(STAR_ON if i < won.size() else STAR_OFF)


# ---------------------------------------------------------------- Commun

func _toast(text: String) -> void:
	var box := PanelContainer.new()
	var s := P.box(Color(0.08, 0.1, 0.2, 0.94), P.px(18), P.px(18), P.px(12))
	s.border_color = Color("f6c24a")
	s.set_border_width_all(P.px(2))
	box.add_theme_stylebox_override("panel", s)
	box.anchor_left = 0.08
	box.anchor_right = 0.92
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 10
	box.add_child(P.label(text, 16, P.CREAM, 800))
	add_child(box)
	var t := box.create_tween()
	t.tween_interval(2.2)
	t.tween_property(box, "modulate:a", 0.0, 0.4)
	t.tween_callback(box.queue_free)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


## Nuages qui dérivent lentement dans le ciel ajouté au-dessus de l'image.
class Clouds extends Control:
	const PUFFS := [Vector2(0, 0), Vector2(0.9, -0.35), Vector2(1.8, -0.1), Vector2(2.5, 0.15), Vector2(1.2, 0.25)]
	const RADII := [0.8, 1.0, 0.9, 0.6, 0.85]
	var _t := 0.0
	## Position de départ (fraction de largeur, fraction de hauteur), taille, vitesse (px/s).
	var _clouds := [[0.15, 0.35, 22.0, 6.0], [0.62, 0.6, 30.0, 9.0], [0.9, 0.22, 16.0, 4.5]]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if size.y < 20:
			return
		var w := size.x
		for c in _clouds:
			var r: float = c[2] * size.x / 390.0
			var span := w + r * 6
			var x := fposmod(c[0] * w + _t * c[3], span) - r * 3
			var y: float = c[1] * size.y
			for i in PUFFS.size():
				var p: Vector2 = PUFFS[i]
				draw_circle(Vector2(x + p.x * r, y + p.y * r + r * 0.12), RADII[i] * r, Color(0.78, 0.86, 1.0, 0.45))
			for i in PUFFS.size():
				var p: Vector2 = PUFFS[i]
				draw_circle(Vector2(x + p.x * r, y + p.y * r), RADII[i] * r, Color(1, 1, 1, 0.85))
