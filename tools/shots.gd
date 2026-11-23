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
	current_scene._on_bread(10)
	await _shot("01a_pain_quotidien")
	change_scene_to_file("res://scenes/profile.tscn")
	await _shot("01b_profil")
	current_scene._show(1)
	await _shot("01c_creer_compte")
	current_scene._show(2)
	await _shot("01d_retrouver_compte")
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
	await _arcade()
	quit()


## Arcade : sans serveur (headless), on remplit les écrans avec des réponses fabriquées.
func _arcade() -> void:
	change_scene_to_file("res://scenes/adventure.tscn")
	await _shot("20_aventure_hors_ligne")
	var a = current_scene
	a._show_guest()
	await _shot("21_aventure_invite")
	a._clear_overlay()
	a._stars = {"1": ["lait", "manne"], "2": ["lait"], "3": ["lait"]}
	a._loaded = true
	a._refresh()
	await _shot("22_aventure_carte")
	a._show_level(4)
	await _shot("23_aventure_niveau")

	var session = root.get_node("Session")
	var cards: Array = session.bank.cards.filter(func(c): return c.difficulty == "manne")
	var main := []
	for c in cards.slice(0, 4):
		main.append({"id": c.id, "fausses": c.wrongs.slice(0, 3), "reserve": 2})
	var foe: CardData = cards[5]
	var starter: StarterQuestion = session.bank.starters[0]
	var vue := {
		"etape": "depart", "niveau": 4, "difficulte": "manne", "mise": 5, "poseur": -1, "gagnant": -1,
		"main": main, "mainIA": 3, "carte": null, "detruites": [[], [cards[6].id, cards[7].id]], "temps": 10,
		"depart": {"id": starter.id, "propositions": [starter.answer] + Array(starter.wrongs)},
	}
	session.arcade_start = {"vue": vue, "talents": 105}
	change_scene_to_file("res://scenes/arcade_match.tscn")
	await _shot("24_arcade_depart")
	var m = current_scene
	m._stop_timer()
	m._begin_choose()
	m._select_card(0)
	await _shot("25_arcade_choisir")
	m._stop_timer()
	var mine: CardData = cards[0]
	var presented: Array[String] = [mine.wrongs[0], mine.answer, mine.wrongs[1]]
	m._show_ai_answering({"carte": mine.id, "presentees": presented, "choix": mine.wrongs[0], "juste": false}, {})
	await create_timer(1.0).timeout
	await _shot("26_arcade_scribe_hesite")
	await create_timer(2.5).timeout
	await _shot("27_arcade_scribe_rate")
	vue["etape"] = "repondre"
	vue["carte"] = {"id": foe.id, "propositions": [foe.wrongs[0], foe.answer, foe.wrongs[1], foe.wrongs[2]]}
	m._apply({"vue": vue})
	m._begin_answer()
	await _shot("28_arcade_repondre")
	m._stop_timer()
	m._show_result({"correct": true, "card": foe, "owner": 1, "choice": foe.answer, "timed_out": false, "options_before": 4})
	await _shot("29_arcade_bonne_reponse")
	vue["etape"] = "finie"
	vue["gagnant"] = 0
	vue["mainIA"] = 0
	m._apply({"vue": vue, "fin": {"gagne": true, "gain": 5, "nouvelleEtoile": true, "talents": 115, "etoiles": ["lait", "manne"]}})
	m._show_end()
	await _shot("30_arcade_victoire")
	vue["gagnant"] = 1
	vue["main"] = []
	vue["mainIA"] = 2
	m._apply({"vue": vue, "fin": {"gagne": false, "gain": -5, "nouvelleEtoile": false, "talents": 105, "etoiles": []}})
	m._show_end()
	await _shot("31_arcade_defaite")
	m._show_destroyed()
	await _shot("32_arcade_cartes_detruites")
