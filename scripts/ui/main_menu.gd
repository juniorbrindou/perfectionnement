extends Control
## Écran d'accueil.


func _ready() -> void:
	theme = UiTheme.get_theme()
	UiTheme.background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	add_child(margin)

	var v := UiTheme.vbox(22)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(v)

	var title := UiTheme.label("Perfectionnement", 64)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	v.add_child(title)
	v.add_child(UiTheme.label("Le duel des connaissances bibliques", 28))
	var verse := UiTheme.label("« … pour le perfectionnement des saints » — Éphésiens 4:12", 22)
	verse.modulate = Color(1, 1, 1, 0.65)
	v.add_child(verse)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	v.add_child(spacer)

	v.add_child(UiTheme.button("Jouer à deux\n(même téléphone)",
		func(): get_tree().change_scene_to_file("res://scenes/local_setup.tscn"), 34))
	for coming in ["Arcade solo — bientôt", "Duel en ligne — bientôt", "Salons — bientôt"]:
		var b := UiTheme.button(coming, func(): pass)
		b.disabled = true
		v.add_child(b)

	var footer := UiTheme.label("v%s · Louis Segond 1910" % ProjectSettings.get_setting("application/config/version"), 20)
	footer.modulate = Color(1, 1, 1, 0.5)
	v.add_child(footer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
