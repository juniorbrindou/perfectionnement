extends TestCase
## Question de départ, distribution, filtres et historique.


func test_starter_first_correct_answer_starts() -> void:
	var q := StarterQuestion.from_dict({"id": "s", "question": "?", "answer": "oui",
		"wrongs": ["a", "b", "c", "d"], "reference": "x"})
	var starter := StarterRound.new(q, rng())
	check_eq(starter.options.size(), 5)
	check_eq(starter.resolve(1, "oui"), 1)
	check_eq(starter.resolve(1, "a"), 0, "une erreur fait commencer l'autre")


func test_deal_has_no_duplicate_and_prefers_unseen_cards() -> void:
	var pool := make_hand("c", 14)
	var recent := {}
	for i in 4:
		recent["c%d" % i] = true
	var hands := DeckBuilder.deal(pool, recent, rng())
	var ids := {}
	for hand in hands:
		check_eq(hand.size(), 5)
		for c in hand:
			check(not ids.has(c.id), "doublon %s" % c.id)
			check(not recent.has(c.id), "carte récente %s distribuée alors que la réserve suffit" % c.id)
			ids[c.id] = true


func test_deal_falls_back_on_recent_cards_when_pool_is_small() -> void:
	var pool := make_hand("c", 10)
	var recent := {"c0": true, "c1": true}
	var hands := DeckBuilder.deal(pool, recent, rng())
	check_eq(hands[0].size() + hands[1].size(), 10)


func test_content_filter_by_scope() -> void:
	var at := make_card("x", "manne")
	at.testament = "AT"
	at.books.assign(["Ruth"])
	check(ContentFilter.bible("manne").matches(at), "toute la Bible")
	check(not ContentFilter.bible("lait").matches(at), "autre difficulté")
	check(ContentFilter.for_testament("manne", "AT").matches(at), "Testament")
	check(not ContentFilter.for_testament("manne", "NT").matches(at), "autre Testament")
	var books: Array[String] = ["Ruth", "Esther"]
	check(ContentFilter.for_books("manne", books).matches(at), "livres")


func test_history_keeps_only_last_five_games() -> void:
	var path := "user://test_historique.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for g in 7:
		var ids: Array[String] = ["g%d" % g]
		LocalHistory.record(ids, path)
	var recent := LocalHistory.recent_ids(path)
	check_eq(recent.size(), 5)
	check(not recent.has("g0") and not recent.has("g1"), "les plus anciennes sont oubliées")
	check(recent.has("g6"), "la dernière est gardée")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
