class_name CardInPlay
extends RefCounted
## Une carte dans une partie : elle s'affaiblit à chaque mauvaise réponse.
##
## Au départ, 3 des 5 fausses réponses sont affichées (4 propositions), les 2 autres
## sont en réserve. Chaque échec retire la fausse proposition choisie (4 → 3 → 2).
## À 2 propositions (minimum), la fausse proposition choisie est remplacée par une
## fausse réponse de la réserve ; réserve vide, elle ne change plus.

const INITIAL_WRONGS := 3

var data: CardData
var shown_wrongs: Array[String] = []
var reserve: Array[String] = []


func _init(card: CardData, rng: RandomNumberGenerator) -> void:
	data = card
	var pool: Array[String] = card.wrongs.duplicate()
	Rand.shuffle(pool, rng)
	shown_wrongs.assign(pool.slice(0, INITIAL_WRONGS))
	reserve.assign(pool.slice(INITIAL_WRONGS))


func option_count() -> int:
	return shown_wrongs.size() + 1


## Propositions à présenter, dans un ordre mélangé à chaque passage.
func options(rng: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = [data.answer]
	result.append_array(shown_wrongs)
	Rand.shuffle(result, rng)
	return result


func is_correct(choice: String) -> bool:
	return choice == data.answer


func weaken(chosen_wrong: String) -> void:
	var i := shown_wrongs.find(chosen_wrong)
	assert(i != -1, "Proposition inconnue : %s" % chosen_wrong)
	if shown_wrongs.size() > 1:
		shown_wrongs.remove_at(i)
	elif not reserve.is_empty():
		shown_wrongs[i] = reserve.pop_front()


func random_wrong(rng: RandomNumberGenerator) -> String:
	return shown_wrongs[rng.randi_range(0, shown_wrongs.size() - 1)]
