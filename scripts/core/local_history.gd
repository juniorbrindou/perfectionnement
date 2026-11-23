class_name LocalHistory
extends RefCounted
## Cartes vues lors des dernières parties sur cet appareil (PRD §2.1).

const PATH := "user://historique.json"
const MAX_GAMES := 5


static func recent_ids(path: String = PATH) -> Dictionary:
	var ids := {}
	for game in _load(path):
		for id in game:
			ids[id] = true
	return ids


static func record(card_ids: Array[String], path: String = PATH) -> void:
	var games: Array = _load(path)
	games.append(card_ids)
	while games.size() > MAX_GAMES:
		games.pop_front()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(games))


static func _load(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []
