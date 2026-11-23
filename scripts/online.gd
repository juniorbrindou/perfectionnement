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
signal duel_view_received(view: Dictionary)  ## Vue d'un duel en ligne envoyée par le serveur.
signal duel_matched  ## Duel rapide : adversaire trouvé et partie rejointe.
signal duel_link_changed(lost: bool)  ## Connexion temps réel perdue (ou retrouvée) pendant un duel.

enum State { OFFLINE, CONNECTING, ONLINE }

const SERVER_KEY := "09a9f6f81f2ea5533b3c0cdb"
const HOST := "brindoujunior.com"
const PORT := 443
const SCHEME := "https"
const SESSION_PATH := "user://session.cfg"
const CONFLICT := 409
## Identifiant OAuth « Application Web » du projet Google Cloud (public : il est dans
## chaque APK). C'est l'audience des jetons Google que le serveur accepte.
const GOOGLE_WEB_CLIENT_ID := "492954893860-3abik9silaiiea1toaf5nt473dj9bc1d.apps.googleusercontent.com"

var client: NakamaClient
var session: NakamaSession
var state := State.OFFLINE
var username := ""
var email := ""
var google_linked := false
var wallet := {}
var last_error := ""
var bread_today := false  ## Pain quotidien reçu aujourd'hui (maintenant ou plus tôt).
var bread_gain := 0  ## Talents reçus par le pain pendant cette session.

# Duels en ligne (server/src/duel_en_ligne.ts) : socket temps réel.
const OP_DEPART := 1
const OP_JOUER := 2
const OP_REPONDRE := 3
const OP_CONTINUER := 4
const OP_ABANDONNER := 5
const OP_REVANCHE := 6
const OP_VUE := 10
const RECONNECT_TRIES := 14  ## Une tentative toutes les 2 s : le serveur attend 30 s.
var socket: NakamaSocket
var duel_match_id := ""
var duel_view := {}  ## Dernière vue reçue.
var duel_search_difficulty := ""  ## Difficulté de la recherche en cours.
var _ticket := ""
var _reconnecting := false

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


func has_google() -> bool:
	return google_linked


## Compte protégé (e-mail ou Google) : exigé par l'arcade et les salons.
func has_account() -> bool:
	return has_email() or has_google()


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
	google_linked = not acc.user.google_id.is_empty()
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


## Partie entre amis (RPC « duel_ami ») : {action: "creer", difficulte} ou {action: "voir", code}.
## Renvoie la réponse du serveur, ou {"erreur": message}.
func duel_friend(request: Dictionary) -> Dictionary:
	if not await _ensure_session():
		return {"erreur": "Pas de connexion au serveur."}
	var r = await client.rpc_async(session, "duel_ami", JSON.stringify(request))
	if r.is_exception():
		var e: NakamaException = r.get_exception()
		return {"erreur": e.message if e.status_code > 0 and not e.message.is_empty() else _message(e)}
	var data = JSON.parse_string(r.payload)
	return data if data is Dictionary else {"erreur": "Réponse illisible du serveur."}


## Duel rapide : entre dans la file du serveur. Renvoie un message d'erreur, ou "".
func duel_search(difficulty: String) -> String:
	if not await _socket_ready():
		return "Pas de connexion au serveur."
	var t = await socket.add_matchmaker_async("+properties.difficulte:%s" % difficulty, 2, 2, {"difficulte": difficulty})
	if t.is_exception():
		return _message(t.get_exception())
	_ticket = t.ticket
	duel_search_difficulty = difficulty
	return ""


func duel_cancel_search() -> void:
	var ticket := _ticket
	_ticket = ""
	duel_search_difficulty = ""
	if not ticket.is_empty() and socket and socket.is_connected_to_host():
		await socket.remove_matchmaker_async(ticket)


## Rejoint une partie (duel rapide trouvé, ou partie entre amis). Renvoie un message d'erreur, ou "".
func duel_join(match_id: String) -> String:
	if not await _socket_ready():
		return "Pas de connexion au serveur."
	duel_view = {}
	duel_match_id = match_id  # Avant la réponse : les premières vues peuvent arriver avant elle.
	var m = await socket.join_match_async(match_id)
	if m.is_exception():
		duel_match_id = ""
		var e: NakamaException = m.get_exception()
		return e.message if not e.message.is_empty() else "Impossible de rejoindre la partie."
	return ""


func duel_send(op: int, data: Dictionary = {}) -> void:
	if socket and not duel_match_id.is_empty() and socket.is_connected_to_host():
		socket.send_match_state_async(duel_match_id, op, JSON.stringify(data))


## Quitte la partie en cours (le serveur annule une partie pas encore commencée).
func duel_leave() -> void:
	var id := duel_match_id
	duel_match_id = ""
	duel_view = {}
	if not id.is_empty() and socket and socket.is_connected_to_host():
		await socket.leave_match_async(id)


## Fin d'un duel : talents et XP à jour sans relire le compte.
func apply_duel_end(fin: Dictionary) -> void:
	if fin.has("talents"):
		wallet["talents"] = int(fin["talents"])
	if fin.has("xpTotal"):
		wallet["xp"] = int(fin["xpTotal"])
	account_changed.emit()


func _socket_ready() -> bool:
	if socket and socket.is_connected_to_host():
		return true
	if not await _ensure_session():
		return false
	if socket == null:
		socket = Nakama.create_socket_from(client)
		socket.received_matchmaker_matched.connect(_on_matchmaker_matched)
		socket.received_match_state.connect(_on_match_state)
		socket.closed.connect(_on_socket_closed)
	var r = await socket.connect_async(session)
	if r.is_exception():
		push_warning("Socket : %s" % _message(r.get_exception()))
		return false
	return true


func _on_matchmaker_matched(matched) -> void:
	_ticket = ""
	duel_search_difficulty = ""
	var error := await duel_join(matched.match_id)
	if error.is_empty():
		duel_matched.emit()
	else:
		push_warning("Duel rapide : %s" % error)


func _on_match_state(data) -> void:
	if data.match_id != duel_match_id or data.op_code != OP_VUE:
		return
	var v = JSON.parse_string(data.data)
	if v is Dictionary:
		duel_view = v
		duel_view_received.emit(v)


## Le téléphone a perdu le réseau en pleine partie : on se reconnecte et on rejoint la même
## partie (le serveur la met en pause 30 s).
func _on_socket_closed() -> void:
	if duel_match_id.is_empty() or _reconnecting:
		return
	_reconnecting = true
	duel_link_changed.emit(true)
	for attempt in RECONNECT_TRIES:
		await get_tree().create_timer(2.0).timeout
		if duel_match_id.is_empty():
			break
		if await _socket_ready():
			var m = await socket.join_match_async(duel_match_id)
			if not m.is_exception():
				_reconnecting = false
				duel_link_changed.emit(false)
				return
	_reconnecting = false
	duel_match_id = ""
	duel_link_changed.emit(true)


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


## Connexion Google (greffon Android « GoogleSignIn », dossier android_plugin/).
## Le compte invité du téléphone est rattaché à Google : pseudo, talents et XP sont gardés.
## Si ce compte Google appartient déjà à un autre joueur, on bascule sur ce compte-là
## (cas d'un nouveau téléphone). Renvoie un message d'erreur, ou "" si c'est fait.
func google_available() -> bool:
	return Engine.has_singleton("GoogleSignIn") and not GOOGLE_WEB_CLIENT_ID.is_empty()


func sign_in_google() -> String:
	if not google_available():
		return "La connexion Google n'est pas disponible sur cet appareil."
	var plugin := Engine.get_singleton("GoogleSignIn")
	var result: Array = []
	var on_ok := func(token: String, _mail: String, _display: String): result.assign([true, token])
	var on_fail := func(code: String, message: String): result.assign([false, code, message])
	plugin.sign_in_succeeded.connect(on_ok)
	plugin.sign_in_failed.connect(on_fail)
	plugin.signIn(GOOGLE_WEB_CLIENT_ID)
	while result.is_empty():
		await get_tree().process_frame
	plugin.sign_in_succeeded.disconnect(on_ok)
	plugin.sign_in_failed.disconnect(on_fail)
	if not result[0]:
		if result[1] == "annule":
			return "Connexion Google annulée."
		push_warning("Google : %s" % result[2])
		return "Connexion Google impossible : %s" % result[2]
	var token: String = result[1]
	if await _ensure_session():
		var link = await client.link_google_async(session, token)
		if not link.is_exception():
			await refresh_account()
			return ""
		if link.get_exception().status_code != CONFLICT:
			return _message(link.get_exception())
	# Ce compte Google a déjà son propre compte de jeu : on s'y connecte (sans en créer).
	var s: NakamaSession = await client.authenticate_google_async(token, null, false)
	if s.is_exception():
		return _message(s.get_exception())
	session = s
	_save_session()
	await refresh_account()
	_set_state(State.ONLINE)
	claim_bread()
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
