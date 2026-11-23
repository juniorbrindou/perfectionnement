extends TestCase


func _duel() -> Duel:
	var d := Duel.new(make_hand("a"), make_hand("b"), rng())
	d.start_with(0)
	return d


func _wrong_choice(d: Duel) -> String:
	for o in d.presented:
		if o != "bonne":
			return o
	return ""


func test_correct_answer_destroys_the_posers_card_and_passes_the_turn() -> void:
	var d := _duel()
	d.play(0)
	var r := d.answer("bonne")
	check(r["correct"], "bonne réponse")
	check_eq(d.hands[0].size(), 4)
	check_eq(d.destroyed[0].size(), 1)
	check_eq(d.poser, 1, "le tour passe")
	check_eq(d.phase, Duel.Phase.CHOOSING)


func test_wrong_answer_returns_the_card_weakened_at_same_place() -> void:
	var d := _duel()
	var card: CardInPlay = d.hands[0][2]
	d.play(2)
	d.answer(_wrong_choice(d))
	check_eq(d.hands[0].size(), 5)
	check(d.hands[0][2] == card, "même position dans la main")
	check_eq(card.option_count(), 3)
	check_eq(d.poser, 1, "le tour passe aussi")


func test_player_without_cards_loses() -> void:
	var d := _duel()
	for turn in 9:
		d.play(0)
		d.answer("bonne" if d.poser == 1 else _wrong_choice(d))
	# Joueur 1 a vu ses 5 cartes détruites (tours 1,3,5,7,9 → poser 1 aux tours pairs).
	d.play(0)
	d.answer("bonne")
	check_eq(d.phase, Duel.Phase.FINISHED)
	check_eq(d.hands[1].size(), 0)
	check_eq(d.winner, 0, "le joueur 1 n'a plus de cartes : le joueur 0 gagne")


func test_timeout_counts_as_a_wrong_answer() -> void:
	var d := _duel()
	d.play(0)
	var r := d.answer_timeout()
	check(not r["correct"], "temps écoulé = mauvaise réponse")
	check_eq(d.hands[0].size(), 5)
	check_eq(d.hands[0][0].option_count(), 3)


func test_play_random_picks_a_card_from_the_posers_hand() -> void:
	var d := _duel()
	d.play_random()
	check_eq(d.phase, Duel.Phase.ANSWERING)
	check_eq(d.hands[0].size(), 4)
	check_eq(d.presented.size(), 4)
