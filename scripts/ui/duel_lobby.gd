extends Control
## Duels en ligne, avant la partie : choix de la difficulté, recherche d'un adversaire,
## créer ou rejoindre une partie entre amis. La partie elle-même est dans duel_match.gd.
##
## Les écrans « recherche », « créer » et « rejoindre » sont les images peintes validées
## (assets/duel/, 2026-11-23) ; le code pose par-dessus ce qui change et rend leurs boutons
## touchables (voir painted.gd). Les rectangles sont en pixels de ces images.

const P := preload("res://scripts/ui/ui_theme.gd")
const G := preload("res://scripts/ui/glass.gd")
const MATCH_SCENE := "res://scenes/duel_match.tscn"
const ART_SEARCH := preload("res://assets/duel/recherche.png")
const ART_CREATE := preload("res://assets/duel/creer.png")
const ART_JOIN := preload("res://assets/duel/rejoindre.png")
const STAKES := {"lait": 5, "manne": 20, "solide": 50}
const LEVELS := [
	["lait", "Les grands récits, pour commencer"],
	["manne", "Des détails, pour les habitués"],
	["solide", "Pour les connaisseurs"],
]
const OFFER_AFTER := 30.0  ## Personne trouvé : on propose un ami ou le Scribe.
const FRIEND_WAIT := 600.0  ## Le serveur garde une partie entre amis 10 minutes.
const CODE_LENGTH := 6

# Image « recherche » (284 × 679).
const S_BACK := Rect2(10, 20, 40, 40)
const S_HOME := Rect2(236, 20, 40, 40)
const S_TITLE := Rect2(54, 26, 178, 30)
const S_RING := Rect2(42, 90, 200, 200)
const S_CLOCK := Rect2(130, 412, 76, 34)
const S_OFFER := Rect2(18, 352, 248, 50)
const S_MIDDLE := Rect2(14, 286, 256, 280)
const S_CANCEL := Rect2(40, 584, 204, 44)
# Image « créer » (280 × 679).
const C_BACK := Rect2(10, 20, 40, 40)
const C_HOME := Rect2(228, 20, 40, 40)
const C_CODE := Rect2(32, 258, 176, 38)
const C_COPY := Rect2(212, 254, 44, 46)
const C_SHARE := Rect2(20, 312, 240, 50)
const C_NAME := Rect2(104, 503, 72, 22)
const C_EXPIRE := Rect2(62, 538, 160, 30)
const C_CANCEL := Rect2(38, 582, 204, 42)
# Image « rejoindre » (287 × 679).
const J_BACK := Rect2(10, 20, 40, 40)
const J_HOME := Rect2(239, 20, 40, 40)
const J_BOXES := [14.0, 58.0, 102.0, 146.0, 190.0, 234.0]
const J_BOX_Y := 256.0
const J_BOX := Vector2(40, 60)
const J_PANEL := Rect2(18, 334, 252, 150)
const J_HOST := Rect2(128, 364, 120, 28)
const J_LEVEL := Rect2(138, 414, 100, 22)
const J_STAKE := Rect2(140, 448, 110, 22)
const J_JOIN := Rect2(20, 494, 248, 54)
const J_REFUSE := Rect2(56, 576, 176, 40)

enum Screen { CHOICE, SEARCH, CREATE, JOIN }

var screen := Screen.CHOICE
var _layer: Control
var _busy := false
var _cards := {}
var _elapsed := 0.0
var _clock: Label
var _offer: Control
var _code := ""
var _code_left := 0.0
var _code_label: Label
var _expire: Label
var _code_input: LineEdit
var _letters: Array = []
var _invite_cover: Control
var _invite_note: Label
var _host_label: Label
var _level_label: Label
var _stake_label: Label
var _join_block: Control
var _join_match := ""
var _art: Painted
var _bar: TopBar


func _ready() -> void:
	theme = P.get_theme()
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_bar = TopBar.attach(self)
	Online.duel_matched.connect(_on_matched)
	Online.duel_view_received.connect(_on_view)
	Online.account_changed.connect(_on_account)
	_show_choice()


func _exit_tree() -> void:
	if screen == Screen.SEARCH:
		Online.duel_cancel_search()


func _process(delta: float) -> void:
	if screen == Screen.SEARCH and is_instance_valid(_clock):
		_elapsed += delta
		_clock.text = "%02d:%02d" % [int(_elapsed) / 60, int(_elapsed) % 60]
		if _elapsed >= OFFER_AFTER and is_instance_valid(_offer) and not _offer.visible:
			_offer.visible = true
			_offer.modulate.a = 0.0
			_offer.create_tween().tween_property(_offer, "modulate:a", 1.0, 0.4)
	elif screen == Screen.CREATE and is_instance_valid(_expire) and not _code.is_empty():
		_code_left = maxf(_code_left - delta, 0.0)
		_expire.text = "Expire dans : %02d:%02d" % [int(_code_left) / 60, int(_code_left) % 60]


func _difficulty() -> String:
	return Session.duel_difficulty


func _stake() -> int:
	return STAKES.get(_difficulty(), 5)


func _clear() -> void:
	for c in _layer.get_children():
		c.queue_free()
	_letters.clear()


## Écran peint : l'image en fond, ses boutons « retour » et « accueil » touchables.
func _painted(texture: Texture2D, back: Rect2, home: Rect2, on_back: Callable) -> Painted:
	_clear()
	_art = Painted.cover(_layer, texture, _bar.bottom())
	_art.tap(back, on_back)
	_art.tap(home, func():
		await _leave_current()
		_to_menu())
	return _art


func _leave_current() -> void:
	match screen:
		Screen.SEARCH:
			await Online.duel_cancel_search()
		Screen.CREATE:
			await Online.duel_leave()
	screen = Screen.CHOICE


# ---------------------------------------------------------------- 1. Choisir la difficulté

func _show_choice() -> void:
	screen = Screen.CHOICE
	_busy = false
	var art := _painted(ART_SEARCH, S_BACK, S_HOME, _to_menu)
	art.patch(Color("0b1d52"), S_TITLE, 6)
	art.text("Duel rapide", 17, Color.WHITE, S_TITLE)
	# Le centre de l'image (anneau, textes) laisse place aux trois difficultés.
	var veil := art.patch(Color(0.02, 0.06, 0.2, 0.9), Rect2(10, 70, 264, 566), 16)
	veil.add_theme_stylebox_override("panel", _veil_style(art.s))
	var col := P.vbox(12)
	art.place(col, Rect2(22, 82, 240, 546))
	col.add_child(P.label("Un adversaire au hasard, des questions sur toute la Bible. Choisis ta difficulté :", 14, Color("d8e3ff"), 800))
	_cards.clear()
	for level in LEVELS:
		var card := _level_card(level[0], level[1])
		col.add_child(card)
		_cards[level[0]] = card
	_mark_choice()
	col.add_child(P.expander())
	col.add_child(Painted.gold_button("Trouver un adversaire", _search, P.px(62), P.px(22)))
	var friends := GridContainer.new()
	friends.columns = 2
	friends.add_theme_constant_override("h_separation", P.px(10))
	for b in [Painted.navy_button("Créer une partie", _show_create, P.px(52), P.px(16)),
			Painted.navy_button("J'ai un code", _show_join, P.px(52), P.px(16))]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		friends.add_child(b)
	col.add_child(friends)


func _veil_style(s: float) -> StyleBoxFlat:
	var st := P.box(Color(0.025, 0.07, 0.22, 1.0), int(16 * s))
	st.border_color = Color("c99a3c")
	st.set_border_width_all(maxi(2, int(1.2 * s)))
	return st


func _level_card(diff: String, text: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, P.px(84))
	b.pressed.connect(func():
		Session.duel_difficulty = diff
		_mark_choice())
	var row := P.hbox(12)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = P.px(12)
	row.offset_right = -P.px(12)
	b.add_child(row)
	var medal := Panel.new()
	medal.custom_minimum_size = Vector2(P.px(50), P.px(50))
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ms := P.box(P.difficulty_color(diff), P.px(25))
	ms.border_color = Color("e8b54a")
	ms.set_border_width_all(P.px(2.5))
	medal.add_theme_stylebox_override("panel", ms)
	var icon := Shapes.Icon.new(diff, P.CREAM, 28)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	medal.add_child(icon)
	row.add_child(medal)
	var texts := P.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_child(P.title(G.difficulty_name(diff), 20, P.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	var sub := P.label(text, 12, Color("c9d6f5"), 800, HORIZONTAL_ALIGNMENT_LEFT)
	texts.add_child(sub)
	row.add_child(texts)
	var stake := P.vbox(0)
	stake.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var amount := P.hbox(4)
	amount.alignment = BoxContainer.ALIGNMENT_END
	amount.add_child(G.icon(G.COINS, 22, 19))
	var n := P.title(str(STAKES[diff]), 22, Painted.GOLD_TEXT)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount.add_child(n)
	stake.add_child(amount)
	stake.add_child(P.label("talents", 11, Color("c9d6f5"), 800, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(stake)
	b.set_meta("sub", sub)
	b.set_meta("text", text)
	return b


func _mark_choice() -> void:
	for diff in _cards:
		var b: Button = _cards[diff]
		var chosen: bool = diff == _difficulty()
		var short := Online.is_online() and Online.talents() < int(STAKES[diff])
		var base := P.difficulty_color(diff).darkened(0.55)
		var s := P.box(Color(base, 0.92), P.px(18))
		s.border_color = Color("ffd34d") if chosen else Color("8a6a2a")
		s.set_border_width_all(P.px(3) if chosen else P.px(1.5))
		if chosen:
			s.shadow_color = Color(1, 0.82, 0.3, 0.55)
			s.shadow_size = P.px(10)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(state, s)
		b.modulate = Color(1, 1, 1, 0.55) if short else Color.WHITE
		var sub: Label = b.get_meta("sub")
		sub.text = "Il te faut %d talents" % STAKES[diff] if short else str(b.get_meta("text"))


func _on_account() -> void:
	if screen == Screen.CHOICE and not _cards.is_empty():
		_mark_choice()


# ---------------------------------------------------------------- 2. Recherche

func _search() -> void:
	if _busy:
		return
	if not Online.is_online():
		G.toast(self, "Pas de connexion au serveur. Vérifie ta connexion à Internet.")
		return
	if Online.talents() < _stake():
		G.toast(self, "Il te faut %d talents pour jouer en %s." % [_stake(), G.difficulty_name(_difficulty())])
		return
	_busy = true
	var error := await Online.duel_search(_difficulty())
	_busy = false
	if not error.is_empty():
		G.toast(self, error)
		return
	_show_search()


func _show_search() -> void:
	screen = Screen.SEARCH
	_elapsed = 0.0
	var art := _painted(ART_SEARCH, S_BACK, S_HOME, _cancel_search)
	var rings := Rings.new()
	art.place(rings, S_RING)
	art.patch(Painted.PILL, S_CLOCK, 4)
	_clock = art.text("00:00", 22, Color("ffcc3d"), S_CLOCK)
	art.tap(S_CANCEL, _cancel_search)

	# Au bout de 30 s : inviter un ami, ou jouer contre le Scribe (comptes seulement).
	_offer = Control.new()
	_offer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer.visible = false
	art.place(_offer, S_MIDDLE)
	var veil := Panel.new()
	veil.add_theme_stylebox_override("panel", _veil_style(art.s))
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer.add_child(veil)
	var m := P.margins(14, 14, 14, 14)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	_offer.add_child(m)
	var v := P.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)
	v.add_child(P.title("Personne pour l'instant", 22, Color.WHITE))
	v.add_child(P.label("La recherche continue. En attendant, tu peux aussi :", 14, Color("d8e3ff"), 800))
	v.add_child(Painted.gold_button("Inviter un ami avec un code", func():
		await Online.duel_cancel_search()
		_show_create(), P.px(56), P.px(18)))
	if Online.has_account():
		# Le portrait du Scribe sert d'icône au bouton (un conteneur dans un bouton n'a pas de largeur).
		var scribe := Painted.navy_button("Jouer contre le Scribe", func():
			await Online.duel_cancel_search()
			screen = Screen.CHOICE
			get_tree().change_scene_to_file("res://scenes/adventure.tscn"), P.px(58), P.px(17))
		scribe.icon = G.SCRIBE
		scribe.expand_icon = true
		scribe.add_theme_constant_override("icon_max_width", P.px(40))
		scribe.add_theme_constant_override("h_separation", P.px(12))
		v.add_child(scribe)


func _cancel_search() -> void:
	await Online.duel_cancel_search()
	_show_choice()


func _on_matched() -> void:
	if screen == Screen.SEARCH:
		screen = Screen.CHOICE  # La recherche est finie : rien à annuler en partant.
		get_tree().change_scene_to_file(MATCH_SCENE)


# ---------------------------------------------------------------- 3. Créer une partie entre amis

func _show_create() -> void:
	if not Online.is_online():
		G.toast(self, "Pas de connexion au serveur. Vérifie ta connexion à Internet.")
		return
	if Online.talents() < _stake():
		G.toast(self, "Il te faut %d talents pour jouer en %s." % [_stake(), G.difficulty_name(_difficulty())])
		return
	screen = Screen.CREATE
	_code = ""
	var art := _painted(ART_CREATE, C_BACK, C_HOME, _cancel_create)
	art.patch(Painted.NAVY_DEEP, C_CODE, 4)
	_code_label = art.text("······", 28, Color.WHITE, C_CODE)
	art.tap(C_COPY, func():
		if not _code.is_empty():
			DisplayServer.clipboard_set(_code)
			G.toast(self, "Code copié."))
	art.tap(C_SHARE, _share)
	art.patch(Color("444486"), C_NAME, 10)
	art.text(Online.username, 12, Color.WHITE, C_NAME)
	var ex := art.patch(Color(0.04, 0.09, 0.27, 0.92), C_EXPIRE, 15)
	ex.add_theme_stylebox_override("panel", _veil_style(art.s))
	_expire = art.text("Création de la partie…", 13, Color("ffcc3d"), C_EXPIRE, true)
	art.tap(C_CANCEL, _cancel_create)
	var chip := G.chip("%s, mise de %d" % [G.difficulty_name(_difficulty()), _stake()], P.difficulty_color(_difficulty()), true)
	art.place(chip, Rect2(70, 62, 140, 22))

	var r := await Online.duel_friend({"action": "creer", "difficulte": _difficulty()})
	if screen != Screen.CREATE:
		return
	if r.has("erreur"):
		_expire.text = "Impossible de créer la partie"
		G.toast(self, str(r["erreur"]))
		return
	var error := await Online.duel_join(str(r["matchId"]))
	if screen != Screen.CREATE:
		Online.duel_leave()
		return
	if not error.is_empty():
		_expire.text = "Impossible de créer la partie"
		G.toast(self, error)
		return
	_code = str(r["code"])
	_code_left = FRIEND_WAIT
	var spaced := ""
	for ch in _code:
		spaced += ch + " "
	_code_label.text = spaced.strip_edges()
	_code_label.pivot_offset = _code_label.size / 2
	_code_label.scale = Vector2(0.6, 0.6)
	_code_label.create_tween().tween_property(_code_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Partage par WhatsApp (le plus utilisé) ; le message reste aussi dans le presse-papiers.
func _share() -> void:
	if _code.is_empty():
		return
	var text := "Viens jouer contre moi dans Perfectionnement ! Dans En ligne, touche « J'ai un code » et entre : %s" % _code
	DisplayServer.clipboard_set(text)
	OS.shell_open("https://wa.me/?text=" + text.uri_encode())


func _cancel_create() -> void:
	screen = Screen.CHOICE
	_code = ""
	await Online.duel_leave()
	_show_choice()


# ---------------------------------------------------------------- 4. Rejoindre avec un code

func _show_join() -> void:
	screen = Screen.JOIN
	_join_match = ""
	var art := _painted(ART_JOIN, J_BACK, J_HOME, _show_choice)
	for x in J_BOXES:
		_letters.append(art.text("", 26, Color.WHITE, Rect2(Vector2(x, J_BOX_Y), J_BOX)))
	# Champ invisible par-dessus les cases : il ouvre le clavier et reçoit la saisie.
	_code_input = LineEdit.new()
	_code_input.max_length = CODE_LENGTH
	_code_input.flat = true
	_code_input.context_menu_enabled = false
	_code_input.caret_blink = true
	_code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_code_input.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	_code_input.add_theme_color_override("caret_color", Color(0, 0, 0, 0))
	_code_input.add_theme_color_override("selection_color", Color(0, 0, 0, 0))
	for st in ["normal", "focus", "read_only"]:
		_code_input.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_code_input.text_changed.connect(_on_code_typed)
	art.place(_code_input, Rect2(J_BOXES[0], J_BOX_Y, J_BOXES[5] + J_BOX.x - J_BOXES[0], J_BOX.y))
	# Le cadre « Partie proposée par » reste caché tant qu'aucune partie n'est trouvée.
	_host_label = _value_patch(art, J_HOST, 18)
	_level_label = _value_patch(art, J_LEVEL, 13, "Niveau : ")
	_stake_label = _value_patch(art, J_STAKE, 13, "Mise : ")
	_invite_cover = art.patch(Painted.NAVY, J_PANEL, 10)
	_invite_note = P.label("Entre les 6 caractères du code : la partie de ton ami s'affichera ici.", 14, Color("c9d6f5"), 800)
	_invite_note.set_anchors_preset(Control.PRESET_FULL_RECT)
	_invite_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_invite_cover.add_child(_invite_note)
	art.tap(J_JOIN, _join)
	_join_block = art.patch(Color(0.02, 0.05, 0.15, 0.55), J_JOIN, 27)
	art.tap(J_REFUSE, _show_choice)
	_code_input.grab_focus.call_deferred()


func _value_patch(art: Painted, img: Rect2, px: float, prefix: String = "") -> Label:
	art.patch(Color("0a1f5b"), img, 4)
	var l := art.text("", px, Color.WHITE, img, prefix.is_empty(), HORIZONTAL_ALIGNMENT_LEFT)
	l.set_meta("prefix", prefix)
	return l


func _on_code_typed(text: String) -> void:
	var clean := ""
	for ch in text.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			clean += ch
	if clean != text:
		_code_input.text = clean
		_code_input.caret_column = clean.length()
	for i in _letters.size():
		(_letters[i] as Label).text = clean[i] if i < clean.length() else ""
	_join_match = ""
	_join_block.visible = true
	_invite_cover.visible = true
	_invite_note.text = "Entre les 6 caractères du code : la partie de ton ami s'affichera ici."
	_invite_note.add_theme_color_override("font_color", Color("c9d6f5"))
	if clean.length() == CODE_LENGTH:
		_look_up(clean)


func _look_up(code: String) -> void:
	_invite_note.text = "Recherche de la partie…"
	var r := await Online.duel_friend({"action": "voir", "code": code})
	if screen != Screen.JOIN or _code_input.text != code:
		return
	if r.has("erreur"):
		_invite_note.text = str(r["erreur"])
		_invite_note.add_theme_color_override("font_color", Color("ff8f8f"))
		return
	var stake := int(r.get("mise", 0))
	var host := str(r.get("createur", ""))
	_host_label.text = host if not host.is_empty() else "Ton ami"
	_level_label.text = "Niveau : %s" % G.difficulty_name(str(r.get("difficulte", "lait")))
	_stake_label.text = "Mise : %d talents" % stake
	_invite_cover.visible = false
	_join_match = str(r.get("matchId", ""))
	var enough := Online.talents() >= stake
	_join_block.visible = not enough or _join_match.is_empty()
	if not enough:
		G.toast(self, "Il te faut %d talents pour cette partie : tu en as %d." % [stake, Online.talents()])
	_code_input.release_focus()


func _join() -> void:
	if _join_match.is_empty() or _busy or _join_block.visible:
		return
	_busy = true
	_join_block.visible = true
	var error := await Online.duel_join(_join_match)
	_busy = false
	if not error.is_empty():
		_join_block.visible = false
		G.toast(self, error)
		return
	G.toast(self, "Connexion à la partie…")
	# La partie commence dès que les deux joueurs sont là : les vues suivent (_on_view).
	if not Online.duel_view.is_empty() and Online.duel_view.get("etape") != "attente":
		get_tree().change_scene_to_file(MATCH_SCENE)


# ---------------------------------------------------------------- Vues du serveur

func _on_view(view: Dictionary) -> void:
	if screen != Screen.CREATE and screen != Screen.JOIN:
		return
	var step := str(view.get("etape", ""))
	if step == "attente":
		return
	if step == "annulee":
		Online.duel_leave()
		G.toast(self, "La partie a été annulée.")
		_show_choice()
		return
	screen = Screen.CHOICE
	get_tree().change_scene_to_file(MATCH_SCENE)


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	match screen:
		Screen.CHOICE:
			_to_menu()
		Screen.SEARCH:
			_cancel_search()
		Screen.CREATE:
			_cancel_create()
		Screen.JOIN:
			_show_choice()


## Ondes dorées qui partent de l'anneau de l'image pendant la recherche.
class Rings extends Control:
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		for i in 3:
			var k := fposmod(_t / 2.4 + i / 3.0, 1.0)
			var radius := r * lerpf(0.62, 1.15, k)
			draw_arc(c, radius, 0, TAU, 96, Color(1, 0.82, 0.35, 0.7 * (1.0 - k)), UiTheme.px(2.5), true)
		# Un éclat qui tourne sur l'anneau.
		var a := _t * TAU / 3.0
		var p := c + Vector2(cos(a), sin(a)) * r * 0.66
		draw_circle(p, UiTheme.px(5), Color(1, 0.95, 0.7, 0.9))
		draw_circle(p, UiTheme.px(10), Color(1, 0.85, 0.4, 0.25))
