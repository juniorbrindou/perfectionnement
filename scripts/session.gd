extends Node
## Autoload : banque de questions et réglages de la partie en cours.

var bank: QuestionBank
var player_names: Array[String] = ["Joueur 1", "Joueur 2"]
var filter: ContentFilter = ContentFilter.bible("lait")

## Écran du profil à ouvrir (0 profil, 1 créer un compte, 2 retrouver un compte).
var profile_view := 0
## Arcade : niveau à ouvrir sur la carte d'aventure (0 : aucun), réponse du serveur
## au lancement de la partie.
var arcade_open_level := 0
var arcade_start := {}


func _ready() -> void:
	# Les brouillons ne sont jouables que dans les versions de développement.
	bank = QuestionBank.load_default(OS.is_debug_build())
