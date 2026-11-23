extends SceneTree
## Vérifie la connexion au serveur Nakama depuis le PC, avec un compte de test fixe
## (appareil « outil-test-pc », pseudo « OutilTest »). godot --headless --path . --script res://tools/test_serveur.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var online = root.get_node("Online")
	var client: NakamaClient = online.client
	var s: NakamaSession = await client.authenticate_device_async("outil-test-pc-0001", "OutilTest", true)
	if s.is_exception():
		print("ÉCHEC authentification : ", s.get_exception().status_code, " ", s.get_exception().message)
		quit(1)
		return
	print("session OK, utilisateur ", s.username, " (créé maintenant : ", s.created, ")")
	online.session = s
	var ok: bool = await online.refresh_account()
	print("compte relu : ", ok, ", pseudo ", online.username, ", portefeuille ", online.wallet)
	var err: String = await online.change_username("OutilTest")
	print("changement de pseudo (identique) : ", "OK" if err.is_empty() else err)
	quit(0)
