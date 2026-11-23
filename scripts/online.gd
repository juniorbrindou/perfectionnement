extends Node
## Autoload : connexion au serveur Nakama (docs/SERVEUR.md).
##
## Au lancement, le joueur est connecté en invité, sans rien saisir : identifiant de
## l'appareil et pseudo lisible proposé automatiquement. La session est gardée sur
## l'appareil et rafraîchie avant expiration. Hors ligne, le mode à deux sur un
## téléphone reste jouable.

signal state_changed(state: State)
signal account_changed
signal bread_received(gain: int)  ## Pain quotidien accordé à la connexion.

enum State { OFFLINE, CONNECTING, ONLINE }

const SERVER_KEY := "09a9f6f81f2ea5533b3c0cdb"
const HOST := "brindoujunior.com"
const PORT := 443
const SCHEME := "https"
const SESSION_PATH := "user://session.cfg"
const CONFLICT := 409

var client: NakamaClient
var session: NakamaSession
var state := State.OFFLINE
var username := ""
var email := ""
var wallet := {}
var last_error := ""
var bread_today := false  ## Pain quotidien reçu aujourd'hui (maintenant ou plus tôt).
var bread_gain := 0  ## Talents reçus par le pain pendant cette session.

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	client = Nakama.create_client(SERVER_KEY, HOST, PORT, SCHEME, 10, NakamaLogger.LOG_LEVEL.ERROR)
	# Pas de réseau pendant les tests et les vérifications automatiques.
	if DisplayServer.get_name() != "headless":
		connect_guest()


func is_online() -> bool:
	return state == State.ONLINE


func has_email() -> bool:
	return not email.is_empty()


func talents() -> int:
	return int(wallet.get("talents", 0))


## XP totale, attribuée par le serveur (PRD §7).
func xp() -> int:
	return int(wallet.get("xp", 0))


## Connexion en invité : session gardée si possible, sinon authentification par appareil.
func connect_guest() -> bool:
	_set_state(State.CONNECTING)
	session = await _restore_session()
	if session == null:
		for attempt in 5:
			var s: NakamaSession = await client.authenticate_device_async(Nakama.get_device_id(), Pseudo.generate(_rng), true)
			if not s.is_exception():
				session = s
				break
			if s.get_exception().status_code != CONFLICT:  # Sinon le pseudo est pris : on en tire un autre.
				return _fail(s.get_exception())
	if session == null:
		return _fail(null)
	_save_session()
	if not await refresh_account():
		return false
	_set_state(State.ONLINE)
	claim_bread()
	return true


## Relit le compte (pseudo, e-mail, portefeuille).
func refresh_account() -> bool:
	if not await _ensure_session():
		return false
	var acc = await client.get_account_async(session)
	if acc.is_exception():
		return _fail(acc.get_exception())
	username = acc.user.username
	email = acc.email if acc.email != null else ""
	var parsed = JSON.parse_string(acc.wallet) if acc.wallet else null
	wallet = parsed if parsed is Dictionary else {}
	account_changed.emit()
	return true


## Demande le pain quotidien (+10 talents une fois par jour, décidé par le serveur).
func claim_bread() -> void:
	if not await _ensure_session():
		return
	var r = await client.rpc_async(session, "pain_quotidien")
	if r.is_exception():
		push_warning("Pain quotidien : %s" % _message(r.get_exception()))
		return
	var data = JSON.parse_string(r.payload)
	if not data is Dictionary:
		return
	bread_today = true
	if data.get("accorde", false):
		wallet["talents"] = int(data.get("talents", talents()))
		bread_gain = int(data.get("gain", 0))
		account_changed.emit()
		bread_received.emit(bread_gain)
	else:
		account_changed.emit()


## Arcade jouée sur le serveur (RPC « arcade », voir server/src/arcade.ts). Renvoie la
## réponse du serveur, ou {"erreur": message}. Met à jour les talents affichés.
func arcade(request: Dictionary) -> Dictionary:
	if not await _ensure_session():
		return {"erreur": "Pas de connexion au serveur."}
	var r = await client.rpc_async(session, "arcade", JSON.stringify(request))
	if r.is_exception():
		var e: NakamaException = r.get_exception()
		return {"erreur": e.message if e.status_code > 0 and not e.message.is_empty() else _message(e)}
	var data = JSON.parse_string(r.payload)
	if not data is Dictionary:
		return {"erreur": "Réponse illisible du serveur."}
	var t = data.get("talents", data.get("fin", {}).get("talents", null))
	var x = data.get("fin", {}).get("xpTotal", null)
	if x != null:
		wallet["xp"] = int(x)
	if t != null:
		wallet["talents"] = int(t)
	if t != null or x != null:
		account_changed.emit()
	return data


## Change le pseudo. Renvoie un message d'erreur, ou "" si c'est fait.
func change_username(new_name: String) -> String:
	var problem := Pseudo.problem(new_name)
	if not problem.is_empty():
		return problem
	if not await _ensure_session():
		return "Pas de connexion au serveur."
	var r = await client.update_account_async(session, new_name.strip_edges())
	if r.is_exception():
		return "Ce pseudo est déjà pris." if r.get_exception().status_code == CONFLICT else _message(r.get_exception())
	await refresh_account()
	return ""


## Rattache une adresse e-mail au compte invité : talents et XP sont conservés.
func link_email(address: String, password: String) -> String:
	if password.length() < 8:
		return "Le mot de passe doit faire au moins 8 caractères."
	if not await _ensure_session():
		return "Pas de connexion au serveur."
	var r = await client.link_email_async(session, address.strip_edges(), password)
	if r.is_exception():
		return "Cette adresse est déjà utilisée par un autre compte." if r.get_exception().status_code == CONFLICT else _message(r.get_exception())
	await refresh_account()
	return ""


## Retrouve un compte e-mail existant (nouveau téléphone). Ne crée jamais de compte.
func login_email(address: String, password: String) -> String:
	var s: NakamaSession = await client.authenticate_email_async(address.strip_edges(), password, null, false)
	if s.is_exception():
		return "Adresse ou mot de passe incorrect." if s.get_exception().status_code in [401, 404] else _message(s.get_exception())
	session = s
	_save_session()
	await refresh_account()
	_set_state(State.ONLINE)
	claim_bread()
	return ""


# ---------------------------------------------------------------- Session

func _ensure_session() -> bool:
	if session == null:
		return false
	if session.would_expire_in(300):
		if session.is_refresh_expired():
			return await connect_guest()
		var s: NakamaSession = await client.session_refresh_async(session)
		if s.is_exception():
			return await connect_guest()
		session = s
		_save_session()
	return true


func _restore_session() -> NakamaSession:
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_PATH) != OK:
		return null
	var s := NakamaSession.new(cfg.get_value("session", "token", ""), false, cfg.get_value("session", "refresh_token", ""))
	if not s.is_valid() or s.is_refresh_expired():
		return null
	if s.would_expire_in(300):
		var r: NakamaSession = await client.session_refresh_async(s)
		return null if r.is_exception() else r
	return s


func _save_session() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("session", "token", session.token)
	cfg.set_value("session", "refresh_token", session.refresh_token)
	cfg.save(SESSION_PATH)


func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)


func _fail(e: NakamaException) -> bool:
	last_error = _message(e) if e else "Connexion impossible."
	push_warning("Nakama : %s" % last_error)
	_set_state(State.OFFLINE)
	return false


func _message(e: NakamaException) -> String:
	if e.status_code <= 0:
		return "Pas de connexion au serveur."
	return "Erreur du serveur (%d) : %s" % [e.status_code, e.message]
