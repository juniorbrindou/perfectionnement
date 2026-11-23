# Perfectionnement

Jeu de cartes biblique en duel (Godot 4.7, Android). Spécification : [docs/PRD.md](docs/PRD.md).

## Commandes

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
- `data/recits.json` : récits bibliques, un par illustration.

Une question n'apparaît dans une version publiée que si son champ `status` vaut `"valide"`.
Les brouillons (`"brouillon"`) ne sont jouables que dans les versions de test.
