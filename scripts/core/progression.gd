class_name Progression
extends RefCounted
## XP, niveaux et rangs (PRD §7). Même table que server/src/regles.ts : le serveur
## attribue l'XP, le client l'affiche. Les tests des deux côtés vérifient les mêmes seuils.

const RANKS := [[1, "Débutant"], [6, "Explorateur"], [11, "Connaisseur"], [21, "Expert"], [36, "Maître biblique"]]
const RANK_S_PLACES := 10  ## Les 10 premiers du classement général portent le Rang S (PRD §7).


## XP à gagner pour passer du niveau n au niveau n + 1 : 100, puis 50 de plus à chaque niveau.
static func xp_to_level_up(n: int) -> int:
	return 100 + 50 * (n - 1)


## {level, in_level, to_next} : niveau atteint, XP gagnée dans ce niveau, XP du niveau.
static func from_xp(xp: int) -> Dictionary:
	var level := 1
	var rest := maxi(xp, 0)
	while rest >= xp_to_level_up(level):
		rest -= xp_to_level_up(level)
		level += 1
	return {"level": level, "in_level": rest, "to_next": xp_to_level_up(level)}


static func rank(level: int) -> String:
	var name: String = RANKS[0][1]
	for r in RANKS:
		if level >= r[0]:
			name = r[1]
	return name


## Rang S : être dans les 10 premiers du classement général (place 0 : pas classé).
static func has_rank_s(place: int) -> bool:
	return place >= 1 and place <= RANK_S_PLACES
