class_name QuestionBank
extends RefCounted
## Banque de questions chargée depuis data/. Les brouillons ne sont inclus
## que si include_drafts est vrai (versions de développement).

const CARDS_PATH := "res://data/cartes.json"
const STARTERS_PATH := "res://data/questions_depart.json"
const STORIES_PATH := "res://data/recits.json"

var cards: Array[CardData] = []
var starters: Array[StarterQuestion] = []
var stories: Dictionary = {}  ## id du récit → titre
## Toutes les cartes et questions de départ par identifiant, brouillons compris :
## le serveur (arcade) peut distribuer des cartes que la banque locale écarte.
var cards_by_id: Dictionary = {}
var starters_by_id: Dictionary = {}


static func load_default(include_drafts: bool) -> QuestionBank:
	return load_from(CARDS_PATH, STARTERS_PATH, STORIES_PATH, include_drafts)


static func load_from(cards_path: String, starters_path: String, stories_path: String,
		include_drafts: bool) -> QuestionBank:
	var bank := QuestionBank.new()
	for d in _read_json(cards_path):
		var c := CardData.from_dict(d)
		bank.cards_by_id[c.id] = c
		if include_drafts or c.is_validated():
			bank.cards.append(c)
	for d in _read_json(starters_path):
		var q := StarterQuestion.from_dict(d)
		bank.starters_by_id[q.id] = q
		if include_drafts or q.is_validated():
			bank.starters.append(q)
	var s = _read_json(stories_path)
	if s is Dictionary:
		bank.stories = s
	return bank


func filter(criteria: ContentFilter) -> Array[CardData]:
	var result: Array[CardData] = []
	for c in cards:
		if criteria.matches(c):
			result.append(c)
	return result


## Livres présents pour une difficulté, dans l'ordre canonique.
func books_for(difficulty: String) -> Array[String]:
	var found := {}
	for c in cards:
		if c.difficulty == difficulty:
			for b in c.books:
				found[b] = true
	var result: Array[String] = []
	result.assign(found.keys())
	result.sort_custom(func(a, b): return BibleBooks.canonical_index(a) < BibleBooks.canonical_index(b))
	return result


func story_title(story_id: String) -> String:
	return str(stories.get(story_id, story_id))


static func _read_json(path: String):
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Fichier introuvable ou vide : %s" % path)
		return []
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("JSON invalide : %s" % path)
		return []
	return parsed
