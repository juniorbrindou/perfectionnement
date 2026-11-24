extends Node
## Outils de développement, actifs uniquement dans les versions de test.
## F5 sur PC relance l'écran en cours. Avec « Synchroniser les modifications de script »
## dans l'éditeur, on enregistre un fichier puis on recharge pour voir le changement sans
## réinstaller. (Le bouton « Recharger » à l'écran a été retiré le 2026-11-24.)


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		get_tree().reload_current_scene()
