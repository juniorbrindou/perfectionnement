class_name TestCase
extends RefCounted
## Base minimale des tests : chaque méthode test_* est exécutée par run_tests.gd.

var failures: Array[String] = []
var _current := ""


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s : %s" % [_current, message])


func check_eq(actual, expected, message: String = "") -> void:
	if actual != expected:
		failures.append("%s : %s (obtenu %s, attendu %s)" % [_current, message, str(actual), str(expected)])


func rng(seed_value: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func make_card(id: String, difficulty: String = "lait") -> CardData:
	return CardData.from_dict({
		"id": id, "difficulty": difficulty, "testament": "NT", "books": ["Matthieu"],
		"category": "personnages", "question": "Q " + id, "answer": "bonne",
		"wrongs": ["f1", "f2", "f3", "f4", "f5"], "reference": "Matthieu 1:1",
		"explanation": "", "story": "test", "status": "valide",
	})


func make_hand(prefix: String, count: int = 5) -> Array[CardData]:
	var hand: Array[CardData] = []
	for i in count:
		hand.append(make_card("%s%d" % [prefix, i]))
	return hand
