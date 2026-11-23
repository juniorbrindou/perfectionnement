class_name Pseudo
extends RefCounted
## Pseudos lisibles proposés aux invités (PRD §5), et règles de saisie.

const WORDS: Array[String] = [
	"Colombe", "Olivier", "Cedre", "Berger", "Semeur", "Lampe", "Sentinelle", "Pelerin",
	"Psalmiste", "Vigneron", "Pecheur", "Scribe", "Etoile", "Rocher", "Source", "Moisson",
	"Grenade", "Figuier", "Agneau", "Lion", "Harpe", "Trompette", "Manne", "Sel",
]
const MIN_LENGTH := 3
const MAX_LENGTH := 16


static func generate(rng: RandomNumberGenerator) -> String:
	return "%s%d" % [Rand.pick(WORDS, rng), rng.randi_range(10, 999)]


## Message d'erreur, ou chaîne vide si le pseudo est acceptable.
static func problem(name: String) -> String:
	var n := name.strip_edges()
	if n.length() < MIN_LENGTH:
		return "Le pseudo doit faire au moins %d caractères." % MIN_LENGTH
	if n.length() > MAX_LENGTH:
		return "Le pseudo doit faire au plus %d caractères." % MAX_LENGTH
	var re := RegEx.create_from_string("^[A-Za-z0-9_.-]+$")
	if re.search(n) == null:
		return "Lettres sans accents, chiffres, point, tiret ou soulignement seulement."
	return ""
