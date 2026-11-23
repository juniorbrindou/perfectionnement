extends TestCase
## Rejoue les scénarios communs tests/scenarios/*.json, que les tests du serveur
## (server/test/run.js) rejouent aussi : les deux versions du duel doivent concorder.

const DIR := "res://tests/scenarios/"


func test_shared_scenarios() -> void:
	var files := DirAccess.get_files_at(DIR)
	check(files.size() > 0, "aucun scénario")
	for file in files:
		if file.ends_with(".json"):
			_replay(file, JSON.parse_string(FileAccess.get_file_as_string(DIR + file)))


func _replay(file: String, s: Dictionary) -> void:
	var r := rng()
	var empty: Array[CardData] = []
	var duel := Duel.new(empty, empty, r)
	for p in 2:
		for c: Dictionary in s["mains"][p]:
			var wrongs: Array = c["montrees"] + c["reserve"]
			var data := CardData.from_dict({"id": c["id"], "answer": c["reponse"], "wrongs": wrongs})
			var card := CardInPlay.new(data, r)
			card.shown_wrongs.assign(c["montrees"])
			card.reserve.assign(c["reserve"])
			duel.hands[p].append(card)
	duel.start_with(int(s["commence"]))
	for coup: Dictionary in s["coups"]:
		duel.play(int(coup["jouer"]))
		duel.answer(str(coup["repondre"]))
	var expected: Dictionary = s["attendu"]
	check_eq(duel.winner, int(expected["gagnant"]), "%s : gagnant" % file)
	for p in 2:
		var got := []
		for c: CardInPlay in duel.hands[p]:
			got.append({"id": c.data.id, "montrees": Array(c.shown_wrongs), "reserve": Array(c.reserve)})
		check_eq(JSON.stringify(got), JSON.stringify(expected["mains"][p]), "%s : main %d" % [file, p])
		var ids := []
		for d: CardData in duel.destroyed[p]:
			ids.append(d.id)
		check_eq(ids, expected["detruites"][p], "%s : cartes détruites %d" % [file, p])
