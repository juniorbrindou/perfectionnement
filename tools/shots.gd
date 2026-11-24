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
	# Animation de démarrage (avec un rendu réel seulement) : une capture toutes les 0,9 s, puis
	# l'accueil une fois qu'elle est finie (3,06 s).
	await _shot("00a_demarrage_choc")
	await _shot("00b_demarrage_logo")
	await _shot("00c_demarrage_vers_accueil")
	await _shot("01_accueil")
	current_scene._on_bread(10)
	await _shot("01a_pain_quotidien")
	change_scene_to_file("res://scenes/profile.tscn")
	await _shot("01b_profil")
	current_scene._show(1)
	await _shot("01c_creer_compte")
	current_scene._show(2)
	await _shot("01d_retrouver_compte")
	change_scene_to_file("res://scenes/leaderboard.tscn")
	await _shot("01e_classement_hors_ligne")
	var names := ["Shalom", "Myriam_7", "Daniel_88", "Ruth", "Elie_03", "Abigaïl", "Jonas_tk", "Priscille", "Barnabé", "Lydie", "Timothée", "Silas"]
	var top := []
	for i in names.size():
		top.append({"place": i + 1, "name": names[i], "xp": 3120 - i * 230, "me": false})
	current_scene.show_data({"top": top, "me": {"place": 57, "name": "Toi", "xp": 340, "me": true}})
	await _shot("01f_classement")
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
	await _duels()
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
	a._select(4)
	await _shot("22_aventure_carte")
	a._select(1)
	a._choice = "solide"
	a._refresh()
	await _shot("23_aventure_niveau")

	var session = root.get_node("Session")
	var cards: Array = session.bank.cards.filter(func(c): return c.difficulty == "manne")
	var main := []
	for c in cards.slice(0, 4):
		main.append({"carte": _card_dict(c), "fausses": c.wrongs.slice(0, 3), "reserve": 2})
	var foe: CardData = cards[5]
	var starter: StarterQuestion = session.bank.starters[0]
	var vue := {
		"etape": "depart", "niveau": 4, "difficulte": "manne", "mise": 5, "poseur": -1, "gagnant": -1,
		"main": main, "mainIA": 3, "carte": null, "detruites": [[], [_card_dict(cards[6]), _card_dict(cards[7])]], "temps": 10,
		"depart": {"question": starter.question, "propositions": [starter.answer] + Array(starter.wrongs)},
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
	m._show_ai_answering({"carte": _card_dict(mine), "presentees": presented, "choix": mine.wrongs[0], "juste": false}, {})
	await create_timer(1.0).timeout
	await _shot("26_arcade_scribe_hesite")
	await create_timer(2.5).timeout
	await _shot("27_arcade_scribe_rate")
	vue["etape"] = "repondre"
	vue["carte"] = {"question": foe.question, "category": foe.category, "difficulty": foe.difficulty, "story": foe.story, "propositions": [foe.wrongs[0], foe.answer, foe.wrongs[1], foe.wrongs[2]]}
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


## Une carte au format envoyé par le serveur (celui de data/cartes.json).
func _card_dict(c: CardData) -> Dictionary:
	return {"id": c.id, "difficulty": c.difficulty, "testament": c.testament, "books": c.books, "category": c.category,
		"question": c.question, "answer": c.answer, "wrongs": c.wrongs, "reference": c.reference,
		"explanation": c.explanation, "story": c.story}


## Duels en ligne : sans serveur, on envoie à l'écran des vues fabriquées.
func _duels() -> void:
	change_scene_to_file("res://scenes/duel_lobby.tscn")
	await _shot("40_duel_choix")
	var lobby = current_scene
	lobby._show_search()
	lobby._elapsed = 31.0
	await _shot("41_duel_recherche")
	lobby._show_join()
	await _shot("42_duel_code")
	lobby.screen = lobby.Screen.CHOICE

	var online = root.get_node("Online")
	var session = root.get_node("Session")
	var cards: Array = session.bank.cards.filter(func(c): return c.difficulty == "manne")
	var main := []
	for c in cards.slice(0, 4):
		main.append({"carte": _card_dict(c), "fausses": c.wrongs.slice(0, 3), "reserve": 2})
	var foe: CardData = cards[5]
	var mine: CardData = cards[0]
	var starter: StarterQuestion = session.bank.starters[0]
	var vue := {
		"etape": "depart", "mode": "rapide", "difficulte": "manne", "mise": 20,
		"adversaire": {"pseudo": "Esdras42", "niveau": 7, "present": true}, "poseur": "",
		"main": main, "mainAdverse": 5, "carte": null, "coup": null, "temps": 10, "pause": null,
		"depart": {"question": starter.question, "propositions": [starter.answer] + Array(starter.wrongs)},
		"detruites": [[], [_card_dict(cards[6])]], "fin": null, "revanche": null, "annulation": "",
	}
	online.duel_match_id = "essai"
	online.duel_view = vue.duplicate(true)
	change_scene_to_file("res://scenes/duel_match.tscn")
	await _shot("43_duel_depart")
	var m = current_scene
	vue["etape"] = "annonce"
	vue["depart"] = null
	vue["coup"] = {"type": "depart", "parMoi": true, "choix": starter.answer, "juste": true, "bonne": starter.answer, "jeCommence": true}
	m._on_view(vue.duplicate(true))
	await _shot("44_duel_annonce")
	vue["etape"] = "choisir"
	vue["poseur"] = "moi"
	vue["coup"] = null
	m._on_view(vue.duplicate(true))
	await _shot("45_duel_poser")
	vue["poseur"] = "adversaire"
	m._on_view(vue.duplicate(true))
	await _shot("46_duel_adversaire_choisit")
	vue["etape"] = "repondre"
	vue["poseur"] = "moi"
	var shown := _card_dict(mine)
	shown["propositions"] = [mine.wrongs[0], mine.answer, mine.wrongs[1], mine.wrongs[2]]
	vue["carte"] = shown
	m._on_view(vue.duplicate(true))
	await _shot("47_duel_adversaire_reflechit")
	vue["pause"] = {"adversaireAbsent": true, "reconnexion": 24}
	m._on_view(vue.duplicate(true))
	await _shot("48_duel_pause")
	vue["pause"] = null
	vue["poseur"] = "adversaire"
	vue["carte"] = {"difficulty": foe.difficulty, "category": foe.category, "question": foe.question, "story": foe.story,
		"propositions": [foe.wrongs[0], foe.answer, foe.wrongs[1], foe.wrongs[2]]}
	m._on_view(vue.duplicate(true))
	await _shot("49_duel_repondre")
	vue["etape"] = "resultat"
	vue["carte"] = null
	vue["coup"] = {"type": "coup", "mienne": false, "carte": _card_dict(foe), "presentees": [foe.answer, foe.wrongs[0]], "choix": foe.answer, "juste": true, "tempsEcoule": false}
	vue["continuer"] = {"moi": false, "adversaire": true}
	m._on_view(vue.duplicate(true))
	await _shot("50_duel_bonne_reponse")
	vue["coup"] = {"type": "coup", "mienne": true, "carte": _card_dict(mine), "presentees": [mine.answer, mine.wrongs[0], mine.wrongs[1]], "choix": mine.wrongs[0], "juste": false, "tempsEcoule": false}
	m._on_view(vue.duplicate(true))
	await _shot("51_duel_rate")
	vue["etape"] = "finie"
	vue["mainAdverse"] = 0
	vue["temps"] = 11
	vue["fin"] = {"gagne": true, "raison": "cartes", "gain": 20, "xp": 30, "talents": 125, "xpTotal": 160, "niveauAvant": 2, "niveau": 3}
	vue["revanche"] = {"moi": false, "adversaire": true, "possible": true}
	m._on_view(vue.duplicate(true))
	await _shot("52_duel_victoire")
	vue["revanche"] = {"moi": true, "adversaire": true, "possible": true}
	m._on_view(vue.duplicate(true))
	m._show_destroyed()
	await _shot("53_duel_cartes_detruites")
	vue["fin"] = {"gagne": false, "raison": "abandon", "gain": -20, "xp": 0}
	vue["revanche"] = {"moi": false, "adversaire": false, "possible": false}
	vue["adversaire"]["present"] = false
	m._on_view(vue.duplicate(true))
	await _shot("54_duel_defaite")
	vue["etape"] = "annulee"
	vue["annulation"] = "deux_deconnectes"
	m._on_view(vue.duplicate(true))
	await _shot("55_duel_annulee")
	m._on_link(true)
	await _shot("56_duel_connexion_perdue")
	online.duel_match_id = ""
	online.duel_view = {}
