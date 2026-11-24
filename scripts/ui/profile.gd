extends Control
## Profil du joueur (maquette « Mon profil » du 2026-11-24 : bleu nuit semé de poussière d'or) :
## pseudo, niveau, sons, compte invité ou protégé, création et récupération de compte.

const P := preload("res://scripts/ui/ui_theme.gd")

enum View { PROFILE, CREATE, LOGIN }

var _view := View.PROFILE
var _body: Control
var _renaming := false
var _google_error: Label


func _ready() -> void:
	theme = P.get_theme()
	_background()
	_body = Control.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_body.offset_top = TopBar.attach(self).bottom()
	Online.account_changed.connect(_rebuild)
	Online.state_changed.connect(_on_online_state)
	_show(Session.profile_view as View)
	Session.profile_view = 0


func _on_online_state(_s) -> void:
	_rebuild()


func _show(v: View) -> void:
	_view = v
	_renaming = false
	_rebuild()


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	# Le contenu défile s'il dépasse l'écran (réglages des musiques, compte invité).
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var m := P.margins(20, 20, 20, 24)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(m)
	var col := P.vbox(14)
	m.add_child(col)
	match _view:
		View.PROFILE:
			_build_profile(col)
		View.CREATE:
			_build_create(col)
		View.LOGIN:
			_build_login(col)


func _background() -> void:
	var g := Gradient.new()
	g.set_color(0, Color("1b2c6b"))
	g.set_color(1, Color("0b1638"))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dust := GoldDust.new()
	dust.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dust)


func _header(col: VBoxContainer, text: String) -> void:
	var h := P.hbox(12)
	var back := P.button("‹", _back, 26)
	back.flat = true
	back.custom_minimum_size = Vector2(P.px(40), P.px(40))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		back.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		back.add_theme_color_override(state, Glass.SOFT)
	h.add_child(back)
	var t := P.title(text, 28, P.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	col.add_child(h)


# ---------------------------------------------------------------- Profil

func _build_profile(col: VBoxContainer) -> void:
	_header(col, "Mon profil")
	col.add_child(P.spacer(16))
	var shown := Online.username if not Online.username.is_empty() else "Invité"
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(P.px(124), P.px(124))
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var av := Glass.avatar(shown, Glass.ME, 124)
	av.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(av)
	# Point d'état : vert connecté, doré en connexion, gris hors ligne.
	var colors := {Online.State.ONLINE: Color("4cff7a"), Online.State.CONNECTING: Glass.GOLD, Online.State.OFFLINE: Color("8d93a8")}
	var dot := StatusDot.new(colors[Online.state])
	dot.position = Vector2(P.px(92), P.px(92))
	dot.size = Vector2(P.px(26), P.px(26))
	holder.add_child(dot)
	col.add_child(holder)
	col.add_child(Glass.title(shown, 34))

	if Online.is_known():
		col.add_child(_progress())
	col.add_child(_sound_settings())
	if Sound.music_on and not Sound.tracks.is_empty():
		col.add_child(_music_choice())

	if Online.is_online():
		if _renaming:
			col.add_child(_rename_panel())
		else:
			col.add_child(_link("Changer de pseudo", func():
				_renaming = true
				_rebuild()))
	else:
		var retry := Glass.button("Se reconnecter", func(): Online.connect_guest(), 16, 46)
		retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(retry)
		if not Online.last_error.is_empty():
			col.add_child(P.label(Online.last_error, 13, Color("ff8fa3")))

	col.add_child(P.expander())
	if Online.has_account():
		col.add_child(_account_badge())
	else:
		var card := Glass.panel(Color(0.05, 0.1, 0.25, 0.85), 18, Color(1, 1, 1, 0.22), 16, 14)
		var cv := P.vbox(10)
		card.add_child(cv)
		cv.add_child(Glass.title("Garde ta progression", 20, Glass.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
		cv.add_child(P.label("Ton compte invité est lié à ce téléphone. Crée un compte pour retrouver ton pseudo, tes talents et ton niveau sur un autre téléphone.", 14, Glass.PALE, 800, HORIZONTAL_ALIGNMENT_LEFT))
		cv.add_child(_google_button())
		var create := Glass.button("Créer mon compte avec un e-mail", func(): _show(View.CREATE), 17, 50)
		create.disabled = not Online.is_online()
		cv.add_child(create)
		_google_error = P.label("", 13, Color("ff8fa3"), 800)
		_google_error.visible = false
		cv.add_child(_google_error)
		col.add_child(card)
		col.add_child(_link("J'ai déjà un compte sur un autre téléphone", func(): _show(View.LOGIN), 14, Glass.PALE))


## Compte protégé : cadenas doré et ce que le compte garantit.
func _account_badge() -> Control:
	var p := Glass.panel(Color(0.04, 0.08, 0.2, 0.7), 14, Color(1, 1, 1, 0.25), 14, 10)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var h := P.hbox(12)
	p.add_child(h)
	var lock := Shapes.Icon.new("cadenas", Glass.GOLD, 30)
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(lock)
	var how := "Google lié" if Online.has_google() else "E-mail lié"
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(P.px(250), 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_override("normal_font", P.TITLE_FONT)
	text.add_theme_font_size_override("normal_font_size", P.px(15))
	var gold := Glass.GOLD.to_html(false)
	text.text = "Compte protégé [color=#%s]• Progression synchronisée • %s[/color]" % [gold, how]
	h.add_child(text)
	return p


## Lien texte (sans cadre).
func _link(text: String, on_pressed: Callable, size: float = 17, color: Color = P.CREAM) -> Button:
	var b := P.button(text, on_pressed, size)
	b.flat = true
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, color)
	return b

## Bouton « Continuer avec Google » (blanc, logo G, selon les règles de marque de Google).
func _google_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, P.px(54))
	var s := P.box(Color.WHITE, P.px(14))
	s.border_color = Color("dadce0")
	s.set_border_width_all(P.px(1))
	var sp := P.box(Color("f1f3f4"), P.px(14))
	sp.border_color = Color("dadce0")
	sp.set_border_width_all(P.px(1))
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_stylebox_override("hover_pressed", sp)
	b.add_theme_stylebox_override("disabled", sp)
	var row := P.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(row)
	var g := P.title("G", 22, Color("4285f4"))
	g.autowrap_mode = TextServer.AUTOWRAP_OFF
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(g)
	var l := P.label("Continuer avec Google", 17, Color("1f1f1f"), 800)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	b.disabled = not Online.is_online() or not Online.google_available()
	b.pressed.connect(func():
		b.disabled = true
		var err: String = await Online.sign_in_google()
		if not is_inside_tree():
			return
		if err.is_empty():
			_rebuild()
		else:
			b.disabled = false
			_google_error.text = err
			_google_error.visible = true)
	return b


## Niveau, rang et barre d'XP (PRD §7).
func _progress() -> Control:
	var p := Progression.from_xp(Online.xp())
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Glass.panel_style(Color(1, 1, 1, 0.07), 18, Color(1, 1, 1, 0.1), 16, 12))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := P.vbox(6)
	box.add_child(v)
	var row := P.hbox(8)
	var l := P.title("Niveau %d" % p["level"], 24, Glass.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	var r := P.label(Progression.rank(p["level"]), 15, P.CREAM, 900, HORIZONTAL_ALIGNMENT_RIGHT)
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(r)
	v.add_child(row)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = p["to_next"]
	bar.value = p["in_level"]
	bar.custom_minimum_size = Vector2(0, P.px(12))
	bar.add_theme_stylebox_override("background", P.box(Color(1, 1, 1, 0.12), P.px(6)))
	bar.add_theme_stylebox_override("fill", P.box(Color("f6c24a"), P.px(6)))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	v.add_child(P.label("%d / %d XP pour le niveau %d" % [p["in_level"], p["to_next"], p["level"] + 1], 13, Glass.PALE, 800, HORIZONTAL_ALIGNMENT_LEFT))
	return box


## Effets sonores et musique, à couper séparément (PRD §9).
func _sound_settings() -> Control:
	var row := P.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for kind in ["effets", "musique"]:
		var on: bool = Sound.effects_on if kind == "effets" else Sound.music_on
		var b := P.button("", func(): pass, 15, "ChipToggle")
		b.toggle_mode = true
		b.button_pressed = on
		b.custom_minimum_size = Vector2(P.px(156), P.px(46))
		for state in ["normal", "hover"]:
			b.add_theme_stylebox_override(state, Glass.panel_style(Glass.PANEL_DARK, 16, Color(1, 1, 1, 0.25), 8, 6))
		for state in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, Glass.panel_style(Color("f6c24a"), 16, Color("ffe9a8"), 8, 6))
		for state in ["font_color", "font_hover_color"]:
			b.add_theme_color_override(state, Glass.PALE)
		for state in ["font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, Glass.INK)
		var label := func(state: bool) -> String:
			return ("Effets sonores" if kind == "effets" else "Musique") + (" : oui" if state else " : non")
		b.text = label.call(on)
		b.toggled.connect(func(state: bool):
			b.text = label.call(state)
			if kind == "effets":
				Sound.set_effects(state)
				Sound.play("juste")
			else:
				Sound.set_music(state)
				_rebuild())
		row.add_child(b)
	return row


## Musiques préférées : on coche celles qu'on veut entendre (aucune cochée : toutes).
func _music_choice() -> Control:
	var p := Glass.panel(Color(1, 1, 1, 0.06), 16, Color(1, 1, 1, 0.1), 12, 10)
	var v := P.vbox(6)
	p.add_child(v)
	v.add_child(P.title("Mes musiques", 17, Glass.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(P.label("Coche tes préférées : elles s'enchaînent au hasard. Aucune cochée : toutes.", 12, Glass.PALE, 800, HORIZONTAL_ALIGNMENT_LEFT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", P.px(8))
	grid.add_theme_constant_override("v_separation", P.px(8))
	v.add_child(grid)
	for path in Sound.tracks:
		var b := P.button(Sound.track_title(path), func(): pass, 14)
		b.toggle_mode = true
		b.button_pressed = Sound.is_favorite(path)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, P.px(40))
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		for state in ["normal", "hover"]:
			b.add_theme_stylebox_override(state, Glass.panel_style(Glass.PANEL_DARK, 12, Color(1, 1, 1, 0.22), 8, 4))
		for state in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, Glass.panel_style(Color("f6c24a"), 12, Color("ffe9a8"), 8, 4))
		for state in ["font_color", "font_hover_color"]:
			b.add_theme_color_override(state, Glass.PALE)
		for state in ["font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, Glass.INK)
		b.toggled.connect(func(on: bool): Sound.set_favorite(path, on))
		grid.add_child(b)
	return p


func _rename_panel() -> Control:
	var v := P.vbox(8)
	var field := _field("", "Nouveau pseudo")
	field.text = Online.username
	field.max_length = Pseudo.MAX_LENGTH
	v.add_child(field)
	var err := P.label("", 13, Color("ff8fa3"), 900)
	v.add_child(err)
	var h := P.hbox(10)
	var cancel := Glass.button("Annuler", func():
		_renaming = false
		_rebuild(), 16, 50)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(cancel)
	var ok := P.button("Valider", func(): pass, 18)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func():
		ok.disabled = true
		var problem: String = await Online.change_username(field.text)
		if not is_instance_valid(ok):
			return
		ok.disabled = false
		if problem.is_empty():
			_renaming = false
			_rebuild()
		else:
			err.text = problem)
	h.add_child(ok)
	v.add_child(h)
	return v


# ---------------------------------------------------------------- Créer mon compte

func _build_create(col: VBoxContainer) -> void:
	_header(col, "Créer mon compte")
	var summary := PanelContainer.new()
	summary.add_theme_stylebox_override("panel", Glass.panel_style(Color(1, 1, 1, 0.07), 18, Color(1, 1, 1, 0.12), 14, 12))
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := P.hbox(12)
	var av := Glass.avatar(Online.username, Glass.ME, 48)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(av)
	var info := P.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(P.title(Online.username, 18, Glass.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(P.label("Ton pseudo et ta progression sont conservés.", 14, Glass.PALE, 800, HORIZONTAL_ALIGNMENT_LEFT))
	h.add_child(info)
	summary.add_child(h)
	col.add_child(summary)

	var email := _labelled(col, "Adresse e-mail", _field("", "toi@exemple.fr"))
	email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	var pw := _labelled(col, "Mot de passe", _field("", "", true))
	col.add_child(P.label("8 caractères minimum", 13, Glass.PALE, 800, HORIZONTAL_ALIGNMENT_LEFT))
	var pw2 := _labelled(col, "Confirme le mot de passe", _field("", "", true))
	var err := P.label("", 14, Color("ff8fa3"), 900, HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(err)
	col.add_child(P.expander())
	var go := P.button("Créer mon compte", func(): pass, 23)
	go.custom_minimum_size = Vector2(0, P.px(64))
	go.pressed.connect(func():
		if pw.text != pw2.text:
			err.text = "Les deux mots de passe ne sont pas identiques."
			return
		if not "@" in email.text:
			err.text = "Cette adresse e-mail n'est pas valide."
			return
		go.disabled = true
		var problem: String = await Online.link_email(email.text, pw.text)
		if not is_instance_valid(go):
			return
		go.disabled = false
		if problem.is_empty():
			_show(View.PROFILE)
		else:
			err.text = problem)
	col.add_child(go)


# ---------------------------------------------------------------- Retrouver mon compte

func _build_login(col: VBoxContainer) -> void:
	_header(col, "Retrouver mon compte")
	col.add_child(P.label("Connecte-toi avec l'e-mail de ton compte pour retrouver ton pseudo et ta progression sur ce téléphone.", 15, Glass.PALE, 800, HORIZONTAL_ALIGNMENT_LEFT))
	var email := _labelled(col, "Adresse e-mail", _field("", "toi@exemple.fr"))
	email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	var pw := _labelled(col, "Mot de passe", _field("", "", true))
	var err := P.label("", 14, Color("ff8fa3"), 900, HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(err)

	var warn := PanelContainer.new()
	var ws := P.box(Color(Glass.ALERT, 0.18), P.px(16), P.px(14), P.px(12))
	ws.border_color = Color("ff8fa3", 0.6)
	ws.set_border_width_all(P.px(2))
	warn.add_theme_stylebox_override("panel", ws)
	warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wh := P.hbox(10)
	var mark := P.circle(Glass.GOLD, 22)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var ml := P.title("!", 15, Glass.INK)
	ml.set_anchors_preset(Control.PRESET_FULL_RECT)
	ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_child(ml)
	wh.add_child(mark)
	var wl := P.label("Le compte invité de ce téléphone (%s) sera remplacé par ton compte." % Online.username, 14, P.CREAM, 800, HORIZONTAL_ALIGNMENT_LEFT)
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(wl)
	warn.add_child(wh)
	col.add_child(warn)

	col.add_child(P.expander())
	var go := P.button("Me connecter", func(): pass, 23)
	go.custom_minimum_size = Vector2(0, P.px(64))
	go.pressed.connect(func():
		go.disabled = true
		var problem: String = await Online.login_email(email.text, pw.text)
		if not is_instance_valid(go):
			return
		go.disabled = false
		if problem.is_empty():
			_show(View.PROFILE)
		else:
			err.text = problem)
	col.add_child(go)


# ---------------------------------------------------------------- Commun

func _field(text: String, placeholder: String, secret: bool = false) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.secret = secret
	e.add_theme_font_size_override("font_size", P.px(17))
	e.custom_minimum_size = Vector2(0, P.px(52))
	e.add_theme_stylebox_override("normal", Glass.panel_style(Glass.PANEL_DARK, 14, Color(1, 1, 1, 0.25), 14, 6))
	e.add_theme_stylebox_override("focus", Glass.panel_style(Glass.PANEL_DARK, 14, Color(Glass.RING, 0.8), 14, 6))
	if secret:
		e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	return e


func _labelled(col: VBoxContainer, caption: String, field: LineEdit) -> LineEdit:
	col.add_child(P.title(caption, 17, P.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(field)
	return field


func _back() -> void:
	if _view != View.PROFILE:
		_show(View.PROFILE)
	elif _renaming:
		_renaming = false
		_rebuild()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


## Point d'état sur l'avatar, avec un halo.
class StatusDot extends Control:
	var _color: Color

	func _init(color: Color) -> void:
		_color = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		for i in 4:
			draw_circle(c, r * (1.0 + i * 0.18), Color(_color, 0.12))
		draw_circle(c, r * 0.72, _color)
		draw_circle(c - Vector2(r, r) * 0.2, r * 0.25, Color(1, 1, 1, 0.6))


## Poussière d'or : des grains qui dérivent lentement vers le haut et scintillent, et quelques
## lueurs plus grosses qui respirent.
class GoldDust extends Control:
	const GRAINS := 110
	const GLOWS := 9
	var _grains: Array = []  ## [position (fraction), vitesse (fraction/s), taille, phase, cadence]
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in GRAINS + GLOWS:
			var glow := i >= GRAINS
			_grains.append([
				Vector2(randf(), randf()),
				Vector2(randf_range(-0.006, 0.006), randf_range(-0.03, -0.008) * (0.5 if glow else 1.0)),
				randf_range(3.0, 6.0) if glow else randf_range(0.8, 2.2),
				randf() * TAU,
				randf_range(1.5, 4.0),
			])

	func _process(delta: float) -> void:
		_t += delta
		for g in _grains:
			var p: Vector2 = g[0] + g[1] * delta
			p.x = fposmod(p.x + sin(_t * 0.4 + g[3]) * 0.0006, 1.0)
			p.y = fposmod(p.y, 1.0)
			g[0] = p
		queue_redraw()

	func _draw() -> void:
		var k := size.x / 360.0
		for i in _grains.size():
			var g: Array = _grains[i]
			var at: Vector2 = g[0] * size
			var twinkle := 0.5 + 0.5 * sin(_t * g[4] + g[3])
			var r: float = g[2] * k
			if i >= GRAINS:
				for j in 4:
					draw_circle(at, r * (1.0 + j * 0.9), Color(1.0, 0.82, 0.4, 0.07 * twinkle))
				draw_circle(at, r * 0.6, Color(1.0, 0.93, 0.7, 0.85 * twinkle))
			else:
				draw_circle(at, r, Color(1.0, 0.84, 0.45, 0.25 + 0.6 * twinkle))
