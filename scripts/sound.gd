extends Node
## Autoload : effets sonores et musique de fond (PRD §9, « Audio »).
##
## Les sons sont dans assets/sons, synthétisés par tools/sons.ps1, son_feu.ps1 et
## son_tonnerre.ps1. Un fichier du même nom peut les remplacer sans toucher au code.
## Effets et musique se coupent séparément ; le choix est gardé sur le téléphone.

const SETTINGS_PATH := "user://reglages.cfg"
const MUSIC := preload("res://assets/sons/musique.wav")
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
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		effects_on = cfg.get_value("son", "effets", true)
		music_on = cfg.get_value("son", "musique", true)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	var loop := MUSIC as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = loop.data.size() / 2  # 16 bits mono : deux octets par échantillon.
	_music = AudioStreamPlayer.new()
	_music.stream = loop
	_music.volume_db = MUSIC_DB
	add_child(_music)
	# Pas de musique pendant les tests et les captures automatiques.
	if music_on and DisplayServer.get_name() != "headless":
		_music.play()


## Joue un effet (nom de fichier dans assets/sons, sans extension).
func play(effect: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not effects_on or not EFFECTS.has(effect):
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = EFFECTS[effect]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func set_effects(on: bool) -> void:
	effects_on = on
	if not on:
		for p in _voices:
			p.stop()
	_save()


func set_music(on: bool) -> void:
	music_on = on
	if on and not _music.playing:
		_music.play()
	elif not on:
		_music.stop()
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("son", "effets", effects_on)
	cfg.set_value("son", "musique", music_on)
	cfg.save(SETTINGS_PATH)
