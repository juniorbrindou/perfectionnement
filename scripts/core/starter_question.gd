class_name StarterQuestion
extends RefCounted
## Question de départ (data/questions_depart.json) : facile, 5 propositions.

const WRONG_COUNT := 4

var id := ""
var question := ""
var answer := ""
var wrongs: Array[String] = []
var reference := ""
var status := "brouillon"


static func from_dict(d: Dictionary) -> StarterQuestion:
	var q := StarterQuestion.new()
	q.id = str(d.get("id", ""))
	q.question = str(d.get("question", ""))
	q.answer = str(d.get("answer", ""))
	q.wrongs.assign(d.get("wrongs", []))
	q.reference = str(d.get("reference", ""))
	q.status = str(d.get("status", "brouillon"))
	return q


func is_validated() -> bool:
	return status == "valide"


func problems() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty() or question.is_empty() or answer.is_empty() or reference.is_empty():
		errors.append("champ manquant")
	if wrongs.size() != WRONG_COUNT:
		errors.append("%d fausses réponses au lieu de %d" % [wrongs.size(), WRONG_COUNT])
	var seen := {answer: true}
	for w in wrongs:
		if seen.has(w):
			errors.append("proposition en double : %s" % w)
		seen[w] = true
	return errors
