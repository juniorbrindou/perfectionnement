class_name CardData
extends RefCounted
## Une carte Question telle qu'elle est stockée dans data/cartes.json.

const DIFFICULTIES: Array[String] = ["lait", "manne", "solide"]
const DIFFICULTY_LABELS := {"lait": "Lait", "manne": "Manne", "solide": "Nourriture solide"}
const CATEGORIES: Array[String] = ["personnages", "miracles", "paraboles", "lieux_evenements", "structure"]
const CATEGORY_LABELS := {
	"personnages": "Personnages",
	"miracles": "Miracles",
	"paraboles": "Paraboles",
	"lieux_evenements": "Lieux et événements",
	"structure": "Structure de la Bible",
}
const TESTAMENTS: Array[String] = ["AT", "NT"]
const WRONG_COUNT := 5

var id := ""
var difficulty := ""
var testament := ""
var books: Array[String] = []
var category := ""
var question := ""
var answer := ""
var wrongs: Array[String] = []
var reference := ""
var explanation := ""
var story := ""
var status := "brouillon"


static func from_dict(d: Dictionary) -> CardData:
	var c := CardData.new()
	c.id = str(d.get("id", ""))
	c.difficulty = str(d.get("difficulty", ""))
	c.testament = str(d.get("testament", ""))
	c.books.assign(d.get("books", []))
	c.category = str(d.get("category", ""))
	c.question = str(d.get("question", ""))
	c.answer = str(d.get("answer", ""))
	c.wrongs.assign(d.get("wrongs", []))
	c.reference = str(d.get("reference", ""))
	c.explanation = str(d.get("explanation", ""))
	c.story = str(d.get("story", ""))
	c.status = str(d.get("status", "brouillon"))
	return c


func is_validated() -> bool:
	return status == "valide"


func difficulty_label() -> String:
	return DIFFICULTY_LABELS.get(difficulty, difficulty)


func category_label() -> String:
	return CATEGORY_LABELS.get(category, category)


## Liste des problèmes de la carte (vide si la carte est correcte).
func problems() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("id manquant")
	if not difficulty in DIFFICULTIES:
		errors.append("difficulté inconnue : %s" % difficulty)
	if not testament in TESTAMENTS and not (category == "structure" and testament == ""):
		errors.append("testament inconnu : %s" % testament)
	if books.is_empty() and category != "structure":
		errors.append("aucun livre")
	for b in books:
		if not BibleBooks.exists(b):
			errors.append("livre inconnu : %s" % b)
	if not category in CATEGORIES:
		errors.append("catégorie inconnue : %s" % category)
	if question.is_empty() or answer.is_empty() or reference.is_empty() or story.is_empty():
		errors.append("champ texte manquant")
	if wrongs.size() != WRONG_COUNT:
		errors.append("%d fausses réponses au lieu de %d" % [wrongs.size(), WRONG_COUNT])
	var seen := {answer: true}
	for w in wrongs:
		if seen.has(w):
			errors.append("proposition en double : %s" % w)
		seen[w] = true
	return errors
