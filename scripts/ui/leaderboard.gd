extends Control
## Classement général par XP (maquette validée le 2026-11-24) : le podium des trois premiers,
## la liste jusqu'au 50e, et ta place épinglée en bas. Les 10 premiers portent le Rang S.
## Le serveur tient le classement (leaderboard « xp », docs/SERVEUR.md) ; on ne fait que le lire.

const P := preload("res://scripts/ui/ui_theme.gd")
const LIMIT := 50
## Avatars : une couleur tirée du pseudo, pour qu'un joueur garde toujours la même.
const COLORS := [Color("1fa9a3"), Color("3a6fd8"), Color("7a52e0"), Color("c4501f"), Color("2fae68"), Color("b8185a")]
const PODIUM_RINGS := {1: Color("ffc84a"), 2: Color("c8d3e6"), 3: Color("d9925a")}

var _content: VBoxContainer  ## Zone entre le titre et ta place : chargement, message ou liste.
var _me_slot: Control


func _ready() -> void:
	theme = P.get_theme()
	Glass.background(self, 0.6)
	var bar := TopBar.attach(self)
	var m := P.margins(16, 8, 16, 16)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.offset_top = bar.bottom()
	add_child(m)
	var v := P.vbox(8)
	m.add_child(v)
	v.add_child(Glass.title("Classement", 32))
	v.add_child(P.label("Les %d premiers portent le Rang S" % Progression.RANK_S_PLACES, 14, Glass.PALE))
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


# ---------------------------------------------------------------- Podium

func _podium(rows: Array) -> Control:
	var h := P.hbox(4)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	# 2e à gauche, 1er au centre (plus grand), 3e à droite.
	for place in [2, 1, 3]:
		if place > rows.size():
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(P.px(104), 0)
			h.add_child(gap)
			continue
		h.add_child(_podium_step(rows[place - 1]))
	return h


func _podium_step(row: Dictionary) -> Control:
	var place: int = row["place"]
	var first := place == 1
	var v := P.vbox(4)
	v.custom_minimum_size = Vector2(P.px(112), 0)
	v.alignment = BoxContainer.ALIGNMENT_END
	if first:
		var crown := Glass.icon(Glass.CROWN, 36, 30)
		crown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(crown)
	else:
		v.add_child(P.spacer(24 if place == 2 else 40))
	var d := 84.0 if first else 66.0
	var ring: Color = PODIUM_RINGS[place]
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(P.px(d), P.px(d))
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var halo := RingHalo.new(ring)
	halo.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(halo)
	var face := Glass.avatar(row["name"], _color_of(row["name"]), d, ring)
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(face)
	var badge := Glass.s_badge(22)
	badge.position = Vector2(-P.px(4), -P.px(4))
	badge.size = badge.custom_minimum_size
	holder.add_child(badge)
	var num := P.circle(ring, 24)
	num.position = Vector2(P.px(d - 22), P.px(d - 22))
	num.size = num.custom_minimum_size
	var nl := P.title(str(place), 14, Glass.INK)
	nl.set_anchors_preset(Control.PRESET_FULL_RECT)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_child(nl)
	holder.add_child(num)
	v.add_child(holder)
	var n := P.title("Toi" if row.get("me", false) else str(row["name"]), 15, P.CREAM)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	v.add_child(n)
	v.add_child(P.label(_xp(row["xp"]), 13, Glass.GOLD, 900))
	return v


# ---------------------------------------------------------------- Lignes

func _row(row: Dictionary) -> Control:
	var mine: bool = row.get("me", false)
	var p := Glass.panel(Glass.PANEL, 14, Color(Glass.RING, 0.8) if mine else Glass.EDGE, 10, 6)
	var h := P.hbox(10)
	p.add_child(h)
	var place := P.title(str(row["place"]), 18, Glass.GOLD)
	place.custom_minimum_size = Vector2(P.px(30), 0)
	place.autowrap_mode = TextServer.AUTOWRAP_OFF
	place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(place)
	h.add_child(Glass.avatar(row["name"], _color_of(row["name"]), 36))
	var who := P.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := P.title("Toi" if mine else str(row["name"]), 16, P.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	who.add_child(n)
	who.add_child(P.label(_rank_name(row["xp"]), 12, Glass.SOFT, 800, HORIZONTAL_ALIGNMENT_LEFT))
	h.add_child(who)
	if Progression.has_rank_s(row["place"]):
		h.add_child(Glass.s_badge(22))
	var xp := P.title(_xp(row["xp"]), 15, Glass.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
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
	h.add_child(who)
	return p


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


## Halo de la couleur du podium autour d'un avatar.
class RingHalo extends Control:
	var _color: Color

	func _init(color: Color) -> void:
		_color = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		for i in 6:
			draw_circle(c, r + UiTheme.px(2 + i * 2.5), Color(_color, 0.07))
