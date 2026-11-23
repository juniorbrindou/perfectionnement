extends SceneTree
## Parcourt tous les écrans et toutes les étapes d'une partie pour détecter les
## erreurs d'exécution. godot --headless --path . --script res://tools/shots.gd
## Avec un rendu réel (sans --headless), enregistre aussi une capture par étape
## dans le dossier passé après « -- ».

var _out := "user://shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _shot(step_name: String) -> void:
	await create_timer(0.9).timeout
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("étape ", step_name)
		return
	root.get_viewport().get_texture().get_image().save_png(_out.path_join(step_name + ".png"))
	print("capture ", step_name)


func _wrong(m) -> String:
	for o in m.duel.presented:
		if o != m.duel.played.data.answer:
			return o
	return ""


func _run() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _shot("01_accueil")
	change_scene_to_file("res://scenes/local_setup.tscn")
	await _shot("02_configuration")

	change_scene_to_file("res://scenes/local_match.tscn")
	await _shot("03_depart")
	var m = current_scene
	m.duel.start_with(0)
	m._show_pass(0, "Tu commences : choisis la carte à poser.", m._begin_choose)
	await _shot("04_passe")
	m._begin_choose()
	await _shot("05_main")
	m._select_card(1)
	await _shot("06_carte_choisie")
	m._play_selected()
	await create_timer(1.2).timeout
	m._begin_answer()
	await _shot("07_repondre")
	m._on_answer(_wrong(m))
	await create_timer(1.0).timeout
	await _shot("08_rate")
	m._begin_choose()
	m._select_card(0)
	m._play_selected()
	await create_timer(1.2).timeout
	m._begin_answer()
	await create_timer(0.5).timeout
	m._on_answer(m.duel.played.data.answer)
	await create_timer(1.0).timeout
	await _shot("09_bonne_reponse")

	# Temps écoulés : carte au hasard, puis réponse non donnée.
	m._begin_choose()
	m._on_choose_timeout()
	await create_timer(2.5).timeout
	await _shot("10_hasard")
	m._begin_answer()
	m._time_left = 0.01
	await _shot("11_temps_ecoule")

	while m.duel.phase != Duel.Phase.FINISHED:
		m.duel.play(0)
		m.duel.answer(m.duel.played.data.answer)
	m._show_end()
	await _shot("12_fin")
	m._show_destroyed()
	await _shot("13_cartes_detruites")
	m._ask_quit()
	await _shot("14_quitter")
	quit()
