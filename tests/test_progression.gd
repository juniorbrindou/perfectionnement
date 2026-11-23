extends TestCase
## Même table que server/test/run.js (« niveaux selon l'XP totale », « rangs du PRD »).


func test_levels_from_total_xp() -> void:
	check_eq(Progression.from_xp(0), {"level": 1, "in_level": 0, "to_next": 100})
	check_eq(Progression.from_xp(99), {"level": 1, "in_level": 99, "to_next": 100})
	check_eq(Progression.from_xp(100), {"level": 2, "in_level": 0, "to_next": 150})
	check_eq(Progression.from_xp(700), {"level": 5, "in_level": 0, "to_next": 300})
	check_eq(Progression.from_xp(33250)["level"], 36)


func test_ranks() -> void:
	check_eq(Progression.rank(1), "Débutant")
	check_eq(Progression.rank(5), "Débutant")
	check_eq(Progression.rank(6), "Explorateur")
	check_eq(Progression.rank(11), "Connaisseur")
	check_eq(Progression.rank(21), "Expert")
	check_eq(Progression.rank(36), "Maître biblique")
