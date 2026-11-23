extends Control
## Profil du joueur (maquettes « Profil », « Créer mon compte », « Retrouver mon compte ») :
## pseudo, compte invité ou e-mail, création et récupération de compte.

const P := preload("res://scripts/ui/ui_theme.gd")

enum View { PROFILE, CREATE, LOGIN }

var _view := View.PROFILE
var _body: Control
var _renaming := false


func _ready() -> void:
	theme = P.get_theme()
	P.night_background(self, 0.2)
	_body = Control.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	Online.account_changed.connect(_rebuild)
	Online.state_changed.connect(_on_online_state)
	_show(View.PROFILE)


func _on_online_state(_s) -> void:
	_rebuild()


func _show(v: View) -> void:
	_view = v
	_renaming = false
	_rebuild()


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var m := P.margins(20, 44, 20, 24)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(m)
	var col := P.vbox(14)
	m.add_child(col)
	match _view:
		View.PROFILE:
			_build_profile(col)
		View.CREATE:
			_build_create(col)
		View.LOGIN:
			_build_login(col)


func _header(col: VBoxContainer, text: String) -> void:
	var h := P.hbox(12)
	var back := P.button("‹", _back, 20, "GhostButton")
	back.custom_minimum_size = Vector2(P.px(40), P.px(40))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(back)
	var t := P.title(text, 26, P.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	col.add_child(h)


# ---------------------------------------------------------------- Profil

func _build_profile(col: VBoxContainer) -> void:
	_header(col, "Mon profil")
	col.add_child(P.spacer(20))
	var shown := Online.username if not Online.username.is_empty() else "Invité"
	var av := P.avatar(shown, P.TEAL, 112)
	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(av)
	col.add_child(P.title(shown, 32, P.YELLOW))

	var chips := P.hbox(10)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_child(_chip("Compte e-mail" if Online.has_email() else "Invité"))
	chips.add_child(_status())
	col.add_child(chips)

	if Online.is_online():
		if _renaming:
			col.add_child(_rename_panel())
		else:
			var rename := P.button("Changer de pseudo", func():
				_renaming = true
				_rebuild(), 16, "GhostButton")
			rename.custom_minimum_size = Vector2(0, P.px(42))
			rename.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(rename)
	else:
		var retry := P.button("Se reconnecter", func(): Online.connect_guest(), 16, "GhostButton")
		retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(retry)
		if not Online.last_error.is_empty():
			col.add_child(P.label(Online.last_error, 13, Color("ff8fa3")))

	col.add_child(P.expander())
	var card := _cream_card()
	var cv := P.vbox(12)
	card.add_child(cv)
	if Online.has_email():
		cv.add_child(P.title("Ton compte est protégé", 22, P.FRAMBOISE, HORIZONTAL_ALIGNMENT_LEFT))
		cv.add_child(P.label("Tu peux retrouver ta progression sur un autre téléphone avec %s." % Online.email, 15, P.NIGHT, 800, HORIZONTAL_ALIGNMENT_LEFT))
	else:
		cv.add_child(P.title("Garde ta progression", 22, P.FRAMBOISE, HORIZONTAL_ALIGNMENT_LEFT))
		cv.add_child(P.label("Ton compte invité est lié à ce téléphone. Crée un compte pour retrouver ton pseudo, tes talents et ton niveau sur un autre téléphone.", 15, P.NIGHT, 800, HORIZONTAL_ALIGNMENT_LEFT))
		var create := P.button("Créer mon compte avec un e-mail", func(): _show(View.CREATE), 20)
		create.disabled = not Online.is_online()
		cv.add_child(create)
		var google := P.button("Avec Google : bientôt", func(): pass, 16, "GhostButton")
		google.disabled = true
		google.custom_minimum_size = Vector2(0, P.px(50))
		cv.add_child(google)
	col.add_child(card)

	if not Online.has_email():
		var link := LinkButton.new()
		link.text = "J'ai déjà un compte sur un autre téléphone"
		link.add_theme_font_override("font", P.body_font(900))
		link.add_theme_font_size_override("font_size", P.px(15))
		link.add_theme_color_override("font_color", P.LILAC)
		link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		link.pressed.connect(func(): _show(View.LOGIN))
		col.add_child(P.spacer(4))
		col.add_child(link)


func _chip(text: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", P.box(Color(P.LILAC, 0.18), P.px(999), P.px(12), P.px(4)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := P.label(text, 13, P.LILAC, 900)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	return p


func _status() -> Control:
	var h := P.hbox(6)
	var colors := {Online.State.ONLINE: P.GREEN, Online.State.CONNECTING: P.YELLOW, Online.State.OFFLINE: Color("8d86a3")}
	var texts := {Online.State.ONLINE: "Connecté", Online.State.CONNECTING: "Connexion…", Online.State.OFFLINE: "Hors ligne"}
	var dot := P.circle(colors[Online.state], 9)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	var l := P.label(texts[Online.state], 13, P.LILAC, 800)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	return h


func _rename_panel() -> Control:
	var v := P.vbox(8)
	var field := _field("", "Nouveau pseudo")
	field.text = Online.username
	field.max_length = Pseudo.MAX_LENGTH
	v.add_child(field)
	var err := P.label("", 13, Color("ff8fa3"), 900)
	v.add_child(err)
	var h := P.hbox(10)
	var cancel := P.button("Annuler", func():
		_renaming = false
		_rebuild(), 16, "GhostButton")
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
	summary.add_theme_stylebox_override("panel", P.box(Color(1, 1, 1, 0.07), P.px(18), P.px(14), P.px(12)))
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := P.hbox(12)
	var av := P.avatar(Online.username, P.TEAL, 48)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(av)
	var info := P.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(P.title(Online.username, 18, P.YELLOW, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(P.label("Ton pseudo et ta progression sont conservés.", 14, P.LILAC, 800, HORIZONTAL_ALIGNMENT_LEFT))
	h.add_child(info)
	summary.add_child(h)
	col.add_child(summary)

	var email := _labelled(col, "Adresse e-mail", _field("", "toi@exemple.fr"))
	email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	var pw := _labelled(col, "Mot de passe", _field("", "", true))
	col.add_child(P.label("8 caractères minimum", 13, P.LILAC, 800, HORIZONTAL_ALIGNMENT_LEFT))
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
	col.add_child(P.label("Connecte-toi avec l'e-mail de ton compte pour retrouver ton pseudo et ta progression sur ce téléphone.", 15, P.LILAC, 800, HORIZONTAL_ALIGNMENT_LEFT))
	var email := _labelled(col, "Adresse e-mail", _field("", "toi@exemple.fr"))
	email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	var pw := _labelled(col, "Mot de passe", _field("", "", true))
	var err := P.label("", 14, Color("ff8fa3"), 900, HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(err)

	var warn := PanelContainer.new()
	var ws := P.box(Color(P.FRAMBOISE, 0.25), P.px(16), P.px(14), P.px(12))
	ws.border_color = Color("ff8fa3", 0.6)
	ws.set_border_width_all(P.px(2))
	warn.add_theme_stylebox_override("panel", ws)
	warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wh := P.hbox(10)
	var mark := P.circle(P.YELLOW, 22)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var ml := P.title("!", 15, P.NIGHT)
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
	if secret:
		e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	return e


func _labelled(col: VBoxContainer, caption: String, field: LineEdit) -> LineEdit:
	col.add_child(P.title(caption, 17, P.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(field)
	return field


func _cream_card() -> PanelContainer:
	var card := PanelContainer.new()
	var s := P.box(P.CREAM, P.px(22), P.px(18), P.px(20))
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = P.px(6)
	s.shadow_offset = Vector2(0, P.px(6))
	card.add_theme_stylebox_override("panel", s)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


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
