class_name StarterRound
extends RefCounted
## Question de départ posée aux deux joueurs (PRD §2.4).
## Le premier qui répond décide : juste → il commence ; faux → l'autre commence.

var question: StarterQuestion
var options: Array[String] = []


func _init(q: StarterQuestion, rng: RandomNumberGenerator) -> void:
	question = q
	options.append(q.answer)
	options.append_array(q.wrongs)
	Rand.shuffle(options, rng)


## Renvoie le joueur qui commence.
func resolve(player: int, choice: String) -> int:
	return player if choice == question.answer else 1 - player
