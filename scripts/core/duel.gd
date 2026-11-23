class_name Duel
extends RefCounted
## Règles d'un duel, sans affichage ni minuteur (PRD §2).
##
## Alternance stricte : le poseur choisit une carte, l'autre répond.
## Bonne réponse → la carte du poseur est détruite. Mauvaise réponse → elle revient,
## affaiblie. Le joueur qui n'a plus de cartes perd.

enum Phase { STARTER, CHOOSING, ANSWERING, FINISHED }

const HAND_SIZE := 5

var phase := Phase.STARTER
var hands: Array = [[], []]  ## Deux Array de CardInPlay.
var destroyed: Array = [[], []]  ## Cartes détruites (CardData), par propriétaire.
var poser := -1
var winner := -1
var played: CardInPlay
var presented: Array[String] = []

var _played_index := -1
var _rng: RandomNumberGenerator


func _init(hand_a: Array[CardData], hand_b: Array[CardData], rng: RandomNumberGenerator) -> void:
	_rng = rng
	for c in hand_a:
		hands[0].append(CardInPlay.new(c, rng))
	for c in hand_b:
		hands[1].append(CardInPlay.new(c, rng))


func answerer() -> int:
	return 1 - poser


func loser() -> int:
	return -1 if winner == -1 else 1 - winner


func start_with(player: int) -> void:
	assert(phase == Phase.STARTER)
	poser = player
	phase = Phase.CHOOSING


func play(index: int) -> void:
	assert(phase == Phase.CHOOSING)
	_played_index = index
	played = hands[poser][index]
	hands[poser].remove_at(index)
	presented = played.options(_rng)
	phase = Phase.ANSWERING


func play_random() -> int:
	var index := _rng.randi_range(0, hands[poser].size() - 1)
	play(index)
	return index


## Applique la réponse et renvoie {correct, card (CardData), owner}.
func answer(choice: String) -> Dictionary:
	assert(phase == Phase.ANSWERING)
	assert(choice in presented, "Réponse hors propositions : %s" % choice)
	var owner := poser
	var correct := played.is_correct(choice)
	if correct:
		destroyed[owner].append(played.data)
		if hands[owner].is_empty():
			winner = answerer()
	else:
		played.weaken(choice)
		hands[owner].insert(_played_index, played)
	var result := {"correct": correct, "card": played.data, "owner": owner, "in_play": played}
	played = null
	presented = []
	_played_index = -1
	if winner != -1:
		phase = Phase.FINISHED
	else:
		poser = 1 - owner
		phase = Phase.CHOOSING
	return result


## Temps écoulé : compté comme une mauvaise réponse prise au hasard.
func answer_timeout() -> Dictionary:
	assert(phase == Phase.ANSWERING)
	return answer(played.random_wrong(_rng))
