extends TestCase
## Vérifie l'intégrité des fichiers de contenu de data/ : la réserve « téléphone » (dans
## l'APK) et la réserve « en ligne » (data/en_ligne/, sur le serveur seulement).


func _banks() -> Array[QuestionBank]:
	return [QuestionBank.load_default(true), QuestionBank.load_online()]


func test_every_card_is_well_formed() -> void:
	for bank in _banks():
		check(bank.cards.size() > 0, "aucune carte chargée")
		for c in bank.cards:
			for p in c.problems():
				check(false, "%s : %s" % [c.id, p])
			check(bank.stories.has(c.story), "%s : récit inconnu %s" % [c.id, c.story])


func test_every_starter_question_is_well_formed() -> void:
	for bank in _banks():
		check(bank.starters.size() > 0, "aucune question de départ")
		for q in bank.starters:
			for p in q.problems():
				check(false, "%s : %s" % [q.id, p])


## Une carte présente dans l'APK peut être lue par un tricheur : elle ne doit jamais sortir en ligne.
func test_pools_share_no_card() -> void:
	var ids := {}
	for bank in _banks():
		for c in bank.cards:
			check(not ids.has(c.id), "carte dans les deux réserves, ou en double : %s" % c.id)
			ids[c.id] = true
		for q in bank.starters:
			check(not ids.has(q.id), "question de départ dans les deux réserves, ou en double : %s" % q.id)
			ids[q.id] = true


## Chaque réserve doit pouvoir distribuer deux mains dans chaque difficulté.
func test_each_difficulty_can_host_a_game() -> void:
	for bank in _banks():
		for diff in CardData.DIFFICULTIES:
			var n := bank.filter(ContentFilter.bible(diff)).size()
			check(n >= DeckBuilder.min_pool_size(), "%s : seulement %d cartes" % [diff, n])
