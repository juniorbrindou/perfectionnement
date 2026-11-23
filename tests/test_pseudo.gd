extends TestCase


func test_generated_pseudos_are_valid() -> void:
	var r := rng(3)
	for i in 50:
		var p := Pseudo.generate(r)
		check_eq(Pseudo.problem(p), "", "pseudo généré refusé : %s" % p)


func test_rejects_bad_pseudos() -> void:
	check(Pseudo.problem("ab") != "", "trop court")
	check(Pseudo.problem("abcdefghijklmnopq") != "", "trop long")
	check(Pseudo.problem("Élie") != "", "accent")
	check(Pseudo.problem("deux mots") != "", "espace")
	check_eq(Pseudo.problem("Ruth_42"), "")
