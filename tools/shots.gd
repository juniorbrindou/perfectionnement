extends SceneTree
## Parcourt les écrans principaux et enregistre une capture de chacun.
## godot --path . --script res://tools/shots.gd -- <dossier_de_sortie>
## (sans --headless : il faut un rendu réel).

var _out := "user://shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _shot(name: String) -> void:
	await create_timer(0.9).timeout
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("étape ", name)
		return
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("capture ", name)


func _run() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _shot("01_menu")
	change_scene_to_file("res://scenes/local_setup.tscn")
	await _shot("02_setup")

	change_scene_to_file("res://scenes/local_match.tscn")
	await _shot("03_depart")
	var m = current_scene
	# Le joueur 1 répond juste à la question de départ.
	m.duel.start_with(0)
	m._show_pass(0, "Tu commences : choisis une carte à poser.", m._begin_choose)
	await _shot("04_passe")
	m._clear_overlay()
	m._begin_choose()
	await _shot("05_main")
	var card = m._table.card_for(m.duel.hands[0][1])
	m._on_card_tapped(card)
	await _shot("06_detail")
	m._play_selected()
	await create_timer(1.8).timeout
	m._clear_overlay()
	m._begin_answer()
	await _shot("07_reponse")
	var wrong := ""
	for o in m.duel.presented:
		if o != m.duel.played.data.answer:
			wrong = o
	m._show_result(m.duel.answer(wrong), wrong, false)
	await _shot("08_rate")
	m._begin_choose()
	m.duel.play(0)
	m._show_result(m.duel.answer(m.duel.played.data.answer), "", false)
	await _shot("09_bonne")
	# Temps écoulés : carte au hasard, puis réponse non donnée.
	m._begin_choose()
	m._on_choose_timeout()
	await create_timer(2.6).timeout
	await _shot("09b_hasard")
	m._clear_overlay()
	m._begin_answer()
	m._time_left = 0.01
	await _shot("09c_temps_ecoule")
	# Fin de partie forcée.
	while m.duel.phase != Duel.Phase.FINISHED:
		m.duel.play(0)
		m.duel.answer(m.duel.played.data.answer)
	m._show_end()
	await _shot("10_fin")
	quit()
