extends Node
## Autoload : banque de questions et réglages de la partie en cours.

var bank: QuestionBank
var player_names: Array[String] = ["Joueur 1", "Joueur 2"]
var filter: ContentFilter = ContentFilter.bible("lait")


func _ready() -> void:
	# Les brouillons ne sont jouables que dans les versions de développement.
	bank = QuestionBank.load_default(OS.is_debug_build())
