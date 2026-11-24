extends Node
## Autoload : effets sonores et musique de fond (PRD §9, « Audio »).
##
## Les effets sont dans assets/sons, synthétisés par tools/sons.ps1, son_feu.ps1 et
## son_tonnerre.ps1. Un fichier du même nom peut les remplacer sans toucher au code.
##
## Les musiques sont les fichiers assets/sons/musique/musique_xx.mp3 : il suffit d'en ajouter un
## pour qu'il apparaisse dans les réglages. Le joueur coche ses préférées ; elles s'enchaînent
## au hasard (aucune cochée : toutes). Sans aucun fichier, la boucle synthétisée musique.wav joue.
## Effets et musique se coupent séparément ; les choix sont gardés sur le téléphone.

const SETTINGS_PATH := "user://reglages.cfg"
const MUSIC_DIR := "res://assets/sons/musique/"
const MUSIC_PREFIX := "musique_"
const FALLBACK_MUSIC := preload("res://assets/sons/musique.wav")
const MUSIC_DB := -15.0  ## La musique reste discrète sous les effets.
const EFFECTS := {
	"carte": preload("res://assets/sons/carte.wav"),
	"tic": preload("res://assets/sons/tic.wav"),
	"juste": preload("res://assets/sons/juste.wav"),
	"faux": preload("res://assets/sons/faux.wav"),
	"victoire": preload("res://assets/sons/victoire.wav"),
	"defaite": preload("res://assets/sons/defaite.wav"),
	"feu": preload("res://assets/sons/feu.wav"),
	"tonnerre": preload("res://assets/sons/tonnerre.wav"),
}
const VOICES := 8  ## Effets qui peuvent sonner en même temps.

var effects_on := true
var music_on := true
var tracks: Array[String] = []  ## Chemins des musiques trouvées, triés.
var favorites: Array[String] = []  ## Noms de fichier cochés par le joueur.
var current := ""  ## Musique en cours (chemin), "" pour la boucle de secours.
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _intro := false  ## Animation de démarrage en cours : la musique attend sa fin.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		effects_on = cfg.get_value("son", "effets", true)
		music_on = cfg.get_value("son", "musique", true)
		favorites.assign(cfg.get_value("son", "musiques", []))
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_scan_tracks()
	var loop := FALLBACK_MUSIC as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = loop.data.size() / 2  # 16 bits mono : deux octets par échantillon.
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	_music.finished.connect(_play_next)
	add_child(_music)
	# Pas de musique pendant les tests et les captures automatiques.
	# Différé : l'accueil peut d'abord lancer l'animation de démarrage, qui fait attendre la musique.
	if music_on and DisplayServer.get_name() != "headless":
		_play_next.call_deferred()


## L'animation de démarrage commence : la musique ne joue pas pendant ce temps.
func begin_intro() -> void:
	_intro = true
	_music.stop()


## L'animation est finie : la musique de l'accueil commence.
func end_intro() -> void:
	_intro = false
	if music_on and not _music.playing and DisplayServer.get_name() != "headless":
		_play_next()


## Joue un effet (nom de fichier dans assets/sons, sans extension). Renvoie le lecteur, pour
## un fondu par exemple, ou null si les effets sont coupés.
func play(effect: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	if not effects_on or not EFFECTS.has(effect):
		return null
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = EFFECTS[effect]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	return p


func set_effects(on: bool) -> void:
	effects_on = on
	if not on:
		for p in _voices:
			p.stop()
	_save()


func set_music(on: bool) -> void:
	music_on = on
	if on and not _music.playing:
		_play_next()
	elif not on:
		_music.stop()
	_save()


## « musique_chants_de_paix.mp3 » → « Chants de paix », « musique_1.mp3 » → « Musique 1 ».
func track_title(path: String) -> String:
	var name := path.get_file().get_basename().trim_prefix(MUSIC_PREFIX).replace("_", " ").strip_edges()
	if name.is_valid_int():
		return "Musique %s" % name
	return name.substr(0, 1).to_upper() + name.substr(1)


func is_favorite(path: String) -> bool:
	return path.get_file() in favorites


## Coche ou décoche une musique ; une musique cochée se met à jouer tout de suite.
func set_favorite(path: String, on: bool) -> void:
	var file := path.get_file()
	if on and not file in favorites:
		favorites.append(file)
	elif not on:
		favorites.erase(file)
	_save()
	if not music_on:
		return
	if on:
		_start(path)
	elif current == path:
		_play_next()


## Musiques parmi lesquelles tirer : les cochées, ou toutes si aucune ne l'est.
func playlist() -> Array[String]:
	var chosen: Array[String] = []
	chosen.assign(tracks.filter(func(t): return is_favorite(t)))
	return chosen if not chosen.is_empty() else tracks


func _play_next() -> void:
	if not music_on or _intro:
		return
	var pool := playlist()
	if pool.is_empty():
		current = ""
		_music.stream = FALLBACK_MUSIC
		_music.play()
		return
	var others := pool.filter(func(t): return t != current)
	_start(others.pick_random() if not others.is_empty() else pool[0])


func _start(path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	current = path
	_music.stream = stream
	_music.play()


## Liste les musique_xx.mp3. Dans un APK, les fichiers importés n'apparaissent que sous leur
## nom d'import : on retire ces suffixes.
func _scan_tracks() -> void:
	tracks.clear()
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		var name := file.trim_suffix(".import").trim_suffix(".remap")
		if name.begins_with(MUSIC_PREFIX) and name.get_extension() in ["mp3", "ogg", "wav"]:
			var path := MUSIC_DIR + name
			if not path in tracks:
				tracks.append(path)
	tracks.sort()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("son", "effets", effects_on)
	cfg.set_value("son", "musique", music_on)
	cfg.set_value("son", "musiques", favorites)
	cfg.save(SETTINGS_PATH)
