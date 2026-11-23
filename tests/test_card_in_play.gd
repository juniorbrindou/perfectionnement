extends TestCase


func test_starts_with_four_options_and_two_in_reserve() -> void:
	var c := CardInPlay.new(make_card("a"), rng())
	check_eq(c.option_count(), 4)
	check_eq(c.reserve.size(), 2)
	check(c.options(rng()).has("bonne"), "la bonne réponse est proposée")


func test_each_failure_removes_the_chosen_wrong_down_to_two() -> void:
	var c := CardInPlay.new(make_card("a"), rng())
	var first := c.shown_wrongs[0]
	c.weaken(first)
	check_eq(c.option_count(), 3)
	check(not c.shown_wrongs.has(first), "la proposition choisie est retirée")
	c.weaken(c.shown_wrongs[0])
	check_eq(c.option_count(), 2)


func test_at_two_options_the_chosen_wrong_is_replaced_from_reserve() -> void:
	var c := CardInPlay.new(make_card("a"), rng())
	c.weaken(c.shown_wrongs[0])
	c.weaken(c.shown_wrongs[0])
	var reserve_before := c.reserve.duplicate()
	var chosen := c.shown_wrongs[0]
	c.weaken(chosen)
	check_eq(c.option_count(), 2, "toujours 2 propositions")
	check(c.shown_wrongs[0] != chosen, "la fausse proposition change")
	check_eq(c.shown_wrongs[0], reserve_before[0], "remplacée par la réserve")


func test_empty_reserve_keeps_the_last_wrong() -> void:
	var c := CardInPlay.new(make_card("a"), rng())
	for i in 4:
		c.weaken(c.shown_wrongs[0])
	check(c.reserve.is_empty(), "réserve vide")
	var last := c.shown_wrongs[0]
	c.weaken(last)
	check_eq(c.shown_wrongs[0], last, "plus de remplacement possible")
	check_eq(c.option_count(), 2)


func test_never_shows_a_wrong_already_eliminated() -> void:
	var c := CardInPlay.new(make_card("a"), rng(7))
	var eliminated := {}
	for i in 4:
		var w := c.shown_wrongs[0]
		eliminated[w] = true
		c.weaken(w)
		for o in c.options(rng(i)):
			check(not eliminated.has(o), "%s déjà éliminée réapparaît" % o)
