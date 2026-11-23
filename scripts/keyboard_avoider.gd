extends Node
## Autoload : quand le clavier du téléphone s'ouvre sur un champ de saisie, remonte
## l'écran pour que le champ reste visible au-dessus du clavier.

const MARGIN := 24.0

var _shift := 0.0
var _scene: Node


func _ready() -> void:
	set_process(DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD))


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene as Control
	if scene == null:
		return
	if scene != _scene:
		_scene = scene
		_shift = 0.0
	var target := 0.0
	var kb := DisplayServer.virtual_keyboard_get_height()
	var focus := get_viewport().gui_get_focus_owner()
	if kb > 0 and focus is LineEdit and focus.is_visible_in_tree():
		var view := get_viewport().get_visible_rect().size
		var ratio := view.y / float(DisplayServer.window_get_size().y)
		var keyboard_top := view.y - kb * ratio
		var field_bottom := (focus as Control).get_global_rect().end.y - _shift
		if field_bottom + MARGIN > keyboard_top:
			target = keyboard_top - field_bottom - MARGIN
	if not is_equal_approx(target, _shift):
		_shift = target if absf(target - _shift) < 2.0 else lerpf(_shift, target, 0.35)
		scene.position.y = _shift
