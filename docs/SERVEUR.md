# Serveur Nakama — étape 0.2.1

Mis en service le 2026-11-23 sur le VPS. Ce document dit au client Godot comment s'y connecter, et ce qui
reste côté serveur.

## Se connecter

| Paramètre | Valeur |
|---|---|
| Hôte | `brindoujunior.com` |
| Port | `443` |
| Schéma | `https` (temps réel : `wss://brindoujunior.com/ws`) |
| Clé serveur (`server_key`) | `09a9f6f81f2ea5533b3c0cdb` |
| Version | Nakama 3.42.0 |

La clé serveur n'est pas un secret : elle est embarquée dans chaque APK. Elle sert seulement à ouvrir une
session (authentification), jamais à agir en administrateur.

```gdscript
var client := Nakama.create_client("09a9f6f81f2ea5533b3c0cdb", "brindoujunior.com", 443, "https")
var session := await client.authenticate_device_async(OS.get_unique_id(), pseudo_propose, true)
var socket := Nakama.create_socket_from(client)
await socket.connect_async(session)
```

Client : l'addon officiel `nakama-godot` (branche compatible Godot 4), dans `addons/com.heroiclabs.nakama`.

## Vérifié depuis l'adresse publique

- Authentification par appareil : compte créé (puis supprimé), lecture du compte avec le jeton : OK.
- WebSocket `/ws` : poignée de main 101.
- Mauvaise clé serveur : refusée (401).
- Les ports 7348 à 7351 ne sont pas joignables de l'extérieur ; tout passe par HTTPS sur 443.

## Règles pour le client

- **Identifiant d'appareil** : 10 à 128 caractères. `OS.get_unique_id()` convient sur Android.
- **Pseudo** : sans pseudo fourni, Nakama en tire un au hasard (`bAxftDxwYS`). Le PRD veut un pseudo lisible
  proposé automatiquement : le générer côté client et le passer à l'authentification, ou le changer ensuite
  avec `update_account_async`. Le pseudo est unique : gérer le refus (409) en en proposant un autre.
- **Invité → compte e-mail** : `link_email_async(session, email, mot_de_passe)` sur la session invitée. Ne pas
  appeler `authenticate_email_async` avec `create=true`, qui créerait un second compte et perdrait les talents
  et l'XP (PRD §5). Mot de passe : 8 caractères minimum.
- **Durée des sessions** : jeton 2 h, jeton de rafraîchissement 30 jours. Rafraîchir avec
  `session_refresh_async` avant expiration, et ne revenir à l'authentification par appareil qu'en dernier recours.
- **Talents, XP, mises** : jamais écrits par le client. Le portefeuille (`wallet`) ne se modifie que par du
  code serveur ; le client se contente de le lire (`get_account_async`).

## Code serveur (étapes 0.2.3 et suivantes)

Nakama exécute la logique serveur (pain quotidien, mises, parties d'arcade) en **TypeScript**, pas en GDScript.
Convention proposée :

- le code vit dans `server/` de ce dépôt (`package.json`, `tsconfig.json`, sources dans `server/src/`) et se
  compile en un seul fichier `server/build/index.js` ;
- les règles du duel existent alors deux fois (`scripts/core/duel.gd` et `server/src/`). Des scénarios de partie
  communs en JSON (`tests/scenarios/*.json` : main de départ, coups joués, état attendu) sont rejoués par les
  deux suites de tests, pour que les deux versions ne divergent pas ;
- les cartes restent dans `data/*.json` : le serveur les charge au démarrage, la base ne les stocke pas.

Le déploiement du module se fait sur le serveur (copie de `index.js` dans le dossier des modules et
redémarrage) : à demander à la session Claude du serveur une fois `server/build/index.js` poussé.

## Module serveur (0.2.3) : talents et pain quotidien

Sources dans `server/src/`, compilées par `npm test` (dans `server/`) en `server/build/index.js`. Ce fichier
**n'est pas versionné** (le `.gitignore` racine exclut `build/`) : la session du serveur compile elle-même les
sources de `master`. Tests des règles pures : `server/test/run.js`.

| Élément | Comportement |
|---|---|
| Après authentification (appareil, e-mail, Google) | si le compte vient d'être **créé**, crédite **100 talents** (`raison: capital_depart`) |
| RPC `pain_quotidien` | +10 talents une fois par jour UTC ; réponse `{accorde, gain, talents, prochain}` (`prochain` en ms) |
| Stockage | collection `joueur`, clé `pain`, valeur `{jour: "AAAA-MM-JJ"}` ; lecture par le joueur, écriture serveur seulement |
| Portefeuille | clé `talents` ; écritures avec ledger (`updateLedger`) pour garder l'historique |

Le pain quotidien écrit la date et crédite les talents dans une même transaction (`multiUpdate`), avec une
écriture conditionnelle sur la version : deux appels simultanés ne donnent qu'un seul pain.

**Déployé le 2026-11-23** (commit `634af11` plus le correctif ci-dessous). Vérifié depuis l'adresse publique :
nouveau compte à 100 talents, pain à 110 puis refusé le même jour, aucun second capital à la reconnexion,
six appels simultanés pour un seul pain, RPC refusé sans jeton (401). Les comptes `OutilTest` et
`juniorbrindou`, créés avant le module, ont reçu leurs 100 talents (écriture au journal avec
`raison: capital_depart`).

**Piège du runtime JavaScript** : Nakama retrouve chaque hook et chaque RPC **par son nom dans la portée
globale**. Une fonction anonyme écrite dans l'appel (`registerAfterAuthenticateDevice(function (…) {…})`) fait
refuser le module entier au démarrage (`function key could not be extracted: not found`), et le serveur ne
démarre plus. Toujours passer une variable globale nommée, comme dans `server/src/main.ts`. Les tests Node ne
voient pas cette erreur : seul un démarrage réel de Nakama la révèle.

**Pour un nouveau module** : pousser les sources sur `master`, puis demander le déploiement à la session du serveur.
Elle compile, copie `index.js` dans `/opt/nakama/data/modules`, redémarre et vérifie le journal.

## Module serveur (0.2.4) : arcade contre le Scribe

L'arcade se joue **sur le serveur** : le client envoie ses choix, le serveur distribue, fait jouer l'IA, tient
les délais et règle la mise. Sources : `server/src/duel.ts` (règles, miroir de `scripts/core/duel.gd`),
`ia.ts` (le Scribe, PRD §3.1), `arcade.ts` (RPC). Les cartes, les questions de départ et la carte d'aventure
(`data/aventure.json`) sont **embarquées dans `index.js`** : `npm run build` et `npm test` lancent d'abord
`outils/donnees.js`, qui génère `src/donnees.gen.ts` (non versionné). Il n'y a donc aucun fichier à copier à
côté du module, mais **il faut recompiler et redéployer après chaque changement de `data/`**.

Les scénarios communs `tests/scenarios/*.json` sont rejoués par `server/test/run.js` et par
`tests/test_scenarios.gd` : les deux versions du duel doivent donner le même état final.

RPC **`arcade`**, charge utile `{action, ...}` :

| Action | Effet |
|---|---|
| `etat` | `{talents, etoiles, enCours}` ; `etoiles` : niveau → difficultés gagnées |
| `commencer {niveau, difficulte}` | compte e-mail ou Google exigé, niveau ouvert, talents suffisants ; **prélève la mise** (2, 5 ou 10), distribue, pose la question de départ |
| `depart {choix}` | règle la question de départ (`""` = temps écoulé) ; le Scribe répond en 3 à 9 s, juste 7 fois sur 10 |
| `suite` | coup suivant : le Scribe pose sa carte, ou le joueur a 10 s pour choisir |
| `jouer {index}` | le joueur pose (`-1` ou hors délai : au hasard), le Scribe répond aussitôt |
| `repondre {choix}` | réponse à la carte du Scribe (`""` ou hors délai : temps écoulé) |
| `abandonner` | défaite, la mise reste perdue |

Chaque réponse contient `vue` (ce que le joueur voit : ses cartes, le nombre de cartes du Scribe, la carte à
deviner) et, en fin de partie, `fin {gagne, gain, nouvelleEtoile, talents, etoiles}`. Victoire : le joueur
reçoit **deux fois la mise** (`raison: gain_arcade`). Délais : 10 s pour poser, 15 s pour répondre, plus 3 s
de marge réseau. Une partie laissée en cours est perdue quand le joueur en commence une autre.

| Stockage | Contenu | Lecture |
|---|---|---|
| `arcade` / `partie` | la partie en cours, cartes du Scribe comprises | serveur seulement |
| `arcade` / `recentes` | cartes des 5 dernières parties (évitées au tirage) | serveur seulement |
| `joueur` / `aventure` | `{etoiles: {"1": ["lait", "manne"]}}` | le joueur |

Un niveau est ouvert si c'est le premier ou si le précédent a une étoile. Ses cartes viennent des livres du
chapitre, ou de toute la Bible tant que le chapitre n'en a pas assez (aujourd'hui : toujours toute la Bible).

**À faire par la session du serveur** :
1. `git pull`, puis dans `server/` : `npm install` si besoin, `npm test` (15 tests) ;
2. copier `build/index.js` dans `/opt/nakama/data/modules`, redémarrer, vérifier la ligne
   `Module Perfectionnement chargé (talents, pain quotidien, arcade).` ;
3. vérifier depuis l'adresse publique : `arcade` refusé à un invité ; avec un compte e-mail de test,
   `commencer` niveau 1 en Lait prélève 2 talents, puis une partie jusqu'au bout donne `fin` ; supprimer
   ensuite le compte de test.

## Ce qui est sur le serveur (pour mémoire)

- Service systemd `nakama`, binaire et configuration dans `/opt/nakama`, sans Docker. L'API, la console
  d'administration et le gRPC n'écoutent que sur `127.0.0.1`.
- nginx (site `brindoujunior`) envoie `/v2/` et `/ws` à Nakama ; le reste du site est inchangé.
- Base PostgreSQL `perfectionnement`, rôle du même nom, joignable seulement depuis le serveur. Sauvegardée
  chaque nuit avec les autres bases de l'hôte et copiée hors du serveur.
- Les secrets (mot de passe de la base, clés de session, clé HTTP du runtime, accès à la console) restent sur le
  serveur et n'entrent jamais dans ce dépôt.

## Reste à faire côté serveur

- **0.2.6, connexion Google** : renseigner `google_auth.client_ids` avec l'identifiant OAuth du projet Google
  Cloud. Sans cela, Nakama accepte un jeton Google émis pour n'importe quelle application.
