class_name ContentFilter
extends RefCounted
## Critères de contenu d'une partie : difficulté + portée (toute la Bible,
## un Testament ou une liste de livres).

enum Scope { BIBLE, TESTAMENT, BOOKS }

var difficulty := "lait"
var scope := Scope.BIBLE
var testament := "AT"
var books: Array[String] = []


static func bible(diff: String) -> ContentFilter:
	var f := ContentFilter.new()
	f.difficulty = diff
	return f


static func for_testament(diff: String, t: String) -> ContentFilter:
	var f := bible(diff)
	f.scope = Scope.TESTAMENT
	f.testament = t
	return f


static func for_books(diff: String, list: Array[String]) -> ContentFilter:
	var f := bible(diff)
	f.scope = Scope.BOOKS
	f.books = list.duplicate()
	return f


func matches(card: CardData) -> bool:
	if card.difficulty != difficulty:
		return false
	match scope:
		Scope.TESTAMENT:
			return card.testament == testament
		Scope.BOOKS:
			for b in card.books:
				if b in books:
					return true
			return false
	return true


func describe() -> String:
	var diff: String = CardData.DIFFICULTY_LABELS.get(difficulty, difficulty)
	match scope:
		Scope.TESTAMENT:
			return "%s · %s" % [diff, "Ancien Testament" if testament == "AT" else "Nouveau Testament"]
		Scope.BOOKS:
			return "%s · %s" % [diff, ", ".join(books)]
	return "%s · Toute la Bible" % diff
