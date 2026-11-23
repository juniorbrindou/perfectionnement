class_name DeckBuilder
extends RefCounted
## Distribution des mains (PRD §2.1) : tirage au hasard, sans doublon,
## en évitant les cartes vues récemment tant que la réserve le permet.


static func min_pool_size(hand_size: int = Duel.HAND_SIZE) -> int:
	return hand_size * 2


## Renvoie [main_a, main_b], deux Array[CardData].
static func deal(pool: Array[CardData], recent_ids: Dictionary, rng: RandomNumberGenerator,
		hand_size: int = Duel.HAND_SIZE) -> Array:
	assert(pool.size() >= min_pool_size(hand_size), "Pas assez de cartes")
	var fresh: Array[CardData] = []
	var seen: Array[CardData] = []
	for c in pool:
		if recent_ids.has(c.id):
			seen.append(c)
		else:
			fresh.append(c)
	Rand.shuffle(fresh, rng)
	Rand.shuffle(seen, rng)
	var ordered: Array[CardData] = fresh
	ordered.append_array(seen)
	var hand_a: Array[CardData] = []
	var hand_b: Array[CardData] = []
	hand_a.assign(ordered.slice(0, hand_size))
	hand_b.assign(ordered.slice(hand_size, hand_size * 2))
	return [hand_a, hand_b]
