extends TestCase
## Vérifie l'intégrité des fichiers de contenu de data/.


func _bank() -> QuestionBank:
	return QuestionBank.load_default(true)


func test_every_card_is_well_formed() -> void:
	var bank := _bank()
	check(bank.cards.size() > 0, "aucune carte chargée")
	var ids := {}
	for c in bank.cards:
		for p in c.problems():
			check(false, "%s : %s" % [c.id, p])
		check(not ids.has(c.id), "id en double : %s" % c.id)
		ids[c.id] = true
		check(bank.stories.has(c.story), "%s : récit inconnu %s" % [c.id, c.story])


func test_every_starter_question_is_well_formed() -> void:
	var bank := _bank()
	check(bank.starters.size() > 0, "aucune question de départ")
	for q in bank.starters:
		for p in q.problems():
			check(false, "%s : %s" % [q.id, p])


func test_each_difficulty_can_host_a_local_game() -> void:
	var bank := _bank()
	for diff in CardData.DIFFICULTIES:
		var n := bank.filter(ContentFilter.bible(diff)).size()
		check(n >= DeckBuilder.min_pool_size(), "%s : seulement %d cartes" % [diff, n])
