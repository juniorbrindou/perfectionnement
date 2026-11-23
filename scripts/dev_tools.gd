extends CanvasLayer
## Outils de développement, actifs uniquement dans les versions de test.
## Bouton « Recharger » sur le bord droit (ou F5 sur PC) : relance l'écran en cours.
## Avec « Synchroniser les modifications de script » dans l'éditeur, on enregistre
## un fichier puis on recharge pour voir le changement sans réinstaller.


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 100
	var b := Button.new()
	b.text = "Recharger"
	b.theme = UiTheme.get_theme()
	b.theme_type_variation = "GhostButton"
	b.add_theme_font_size_override("font_size", 18)
	b.modulate = Color(1, 1, 1, 0.45)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 0.45
	b.anchor_bottom = 0.45
	b.offset_left = -136
	b.offset_right = -6
	b.offset_top = -24
	b.offset_bottom = 24
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_reload)
	add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		_reload()


func _reload() -> void:
	get_tree().reload_current_scene()
