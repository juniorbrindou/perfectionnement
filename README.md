# Perfectionnement

Jeu de cartes biblique en duel (Godot 4.7, Android). Spécification : [docs/PRD.md](docs/PRD.md).
Serveur Nakama (connexion, règles pour le client) : [docs/SERVEUR.md](docs/SERVEUR.md).

## Raccourcis (double-clic ou depuis le terminal)

| Fichier | Effet |
|---|---|
| `editeur` | Ouvre le projet dans l'éditeur Godot |
| `deployer` | Exporte l'APK, l'installe sur le téléphone et lance le jeu |
| `logs` | Journal du jeu en direct |
| `capture` | Capture d'écran du téléphone dans `build\captures` |
| `tests` | Tests des règles et du contenu |

L'adresse du téléphone (débogage sans fil) est demandée une fois puis retenue.
Si elle change : `.\deployer 192.168.1.2:41234`.

## Commandes détaillées

```sh
# Tests des règles et du contenu
godot --headless --path . --script res://tests/run_tests.gd

# Parcours complet de l'interface sans écran (détecte les erreurs d'exécution)
godot --headless --path . --script res://tools/shots.gd

# APK de test (Android)
godot --headless --path . --export-debug "Android" build/perfectionnement-debug.apk
```

## Contenu

- `data/cartes.json` : cartes de jeu (1 bonne réponse, 5 fausses, référence Louis Segond 1910).
- `data/questions_depart.json` : questions de départ (5 propositions).
- `data/en_ligne/` : mêmes fichiers pour la réserve **en ligne** (arcade, duels, salons). Elle reste sur le
  serveur et n'entre jamais dans l'APK ; les deux réserves n'ont aucune carte en commun.
- `data/recits.json` : récits bibliques, un par illustration.

Une question n'apparaît dans une version publiée que si son champ `status` vaut `"valide"`.
Les brouillons (`"brouillon"`) ne sont jouables que dans les versions de test.
