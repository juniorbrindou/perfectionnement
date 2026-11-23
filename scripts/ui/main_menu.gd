extends Control
## Écran d'accueil.


func _ready() -> void:
	theme = UiTheme.get_theme()
	UiTheme.background(self)

	var col := UiTheme.vbox(0)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(col)

	var top := MarginContainer.new()
	_margins(top, 48, 150, 48, 36)
	col.add_child(top)
	var head := UiTheme.vbox(14)
	top.add_child(head)
	var title := UiTheme.scripture("Perfectionnement", 74, false, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(title)
	var verse := UiTheme.scripture("« pour le perfectionnement des saints »\nÉphésiens 4:12", 26, false, false, true)
	verse.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	verse.modulate = Color(1, 1, 1, 0.6)
	head.add_child(verse)

	col.add_child(UiTheme.weave_band(30))

	var body := MarginContainer.new()
	_margins(body, 48, 36, 48, 64)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var v := UiTheme.vbox(18)
	body.add_child(v)
	v.add_child(UiTheme.label("Un duel de questions bibliques. Chacun pose ses cartes à l'autre : une bonne réponse détruit la carte posée. Celui qui n'a plus de cartes perd.", 26, "", HORIZONTAL_ALIGNMENT_LEFT))

	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(push)

	v.add_child(UiTheme.button("Jouer à deux sur ce téléphone",
		func(): get_tree().change_scene_to_file("res://scenes/local_setup.tscn"), 30))
	var soon := UiTheme.label("Bientôt : arcade solo, duel en ligne et salons.", 22, "", HORIZONTAL_ALIGNMENT_LEFT)
	soon.modulate = Color(1, 1, 1, 0.55)
	v.add_child(soon)
	var footer := UiTheme.label("Version %s, références Louis Segond 1910" % ProjectSettings.get_setting("application/config/version"), 18, "", HORIZONTAL_ALIGNMENT_LEFT)
	footer.modulate = Color(1, 1, 1, 0.35)
	v.add_child(footer)


func _margins(m: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
