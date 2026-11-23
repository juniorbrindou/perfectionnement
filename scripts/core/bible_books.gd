class_name BibleBooks
extends RefCounted
## Livres communs à tous les canons, dans l'ordre canonique (noms Louis Segond 1910).

const OLD_TESTAMENT: Array[String] = [
	"Genèse", "Exode", "Lévitique", "Nombres", "Deutéronome", "Josué", "Juges", "Ruth",
	"1 Samuel", "2 Samuel", "1 Rois", "2 Rois", "1 Chroniques", "2 Chroniques", "Esdras",
	"Néhémie", "Esther", "Job", "Psaumes", "Proverbes", "Ecclésiaste", "Cantique des cantiques",
	"Ésaïe", "Jérémie", "Lamentations", "Ézéchiel", "Daniel", "Osée", "Joël", "Amos", "Abdias",
	"Jonas", "Michée", "Nahum", "Habacuc", "Sophonie", "Aggée", "Zacharie", "Malachie",
]
const NEW_TESTAMENT: Array[String] = [
	"Matthieu", "Marc", "Luc", "Jean", "Actes", "Romains", "1 Corinthiens", "2 Corinthiens",
	"Galates", "Éphésiens", "Philippiens", "Colossiens", "1 Thessaloniciens",
	"2 Thessaloniciens", "1 Timothée", "2 Timothée", "Tite", "Philémon", "Hébreux", "Jacques",
	"1 Pierre", "2 Pierre", "1 Jean", "2 Jean", "3 Jean", "Jude", "Apocalypse",
]


static func all() -> Array[String]:
	var books: Array[String] = OLD_TESTAMENT.duplicate()
	books.append_array(NEW_TESTAMENT)
	return books


static func exists(book: String) -> bool:
	return book in OLD_TESTAMENT or book in NEW_TESTAMENT


static func canonical_index(book: String) -> int:
	return all().find(book)
