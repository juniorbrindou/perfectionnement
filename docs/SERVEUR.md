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

**Déployé le 2026-11-23** (commit `1245525`, 15 tests serveur verts, ligne de chargement présente au
démarrage). Vérifié depuis l'adresse publique avec un compte e-mail de test, supprimé depuis :

- `commencer` refusé à un invité (403) et sur le niveau 2 encore fermé ;
- défaite complète en 31 appels : 100 → 98 talents, pas d'étoile ;
- victoire : mise de 2 puis gain de 4, étoile `lait` au niveau 1, le niveau 2 s'ouvre ;
- `abandonner` : défaite et mise perdue ; tout appel après la fin est refusé (« Cette partie est terminée. ») ;
- journal du portefeuille cohérent (`capital_depart`, `mise_arcade`, `gain_arcade`) avec le solde final.

**Triche possible, à régler avant les duels en ligne (0.3)** : la vue envoie l'`id` de la carte à deviner, et
l'APK embarque `data/cartes.json` avec les bonnes réponses. Un client modifié lit donc la réponse : un script de
test a gagné trois parties sur trois en répondant ainsi. Retirer l'`id` ne suffit pas, puisque la question et ses
propositions suffisent à retrouver la carte dans le fichier. Contre le Scribe, l'enjeu se limite à quelques
talents. Entre deux joueurs, il faudra que le serveur envoie le texte de la question et ses propositions, et que
l'APK n'embarque plus les réponses des cartes de jeu (PRD §11 : le téléphone de celui qui répond ne reçoit
jamais la bonne réponse).

Détail mineur : les refus renvoient au client une `stackTrace` (`index.js:502…`). C'est sans danger, mais le
client ne doit afficher que `message`.

## Module serveur (0.2.5) : XP, niveaux et classement

- **XP** dans le portefeuille, clé `xp` (le client la lit, ne l'écrit jamais). Fin d'une partie d'arcade :
  +30 en victoire (`raison: gain_arcade`, avec les talents), +10 en défaite (`raison: xp_arcade`), rien pour un
  abandon.
- **Niveaux** calculés depuis l'XP totale, sans stockage : il faut 100 XP pour passer au niveau 2, puis 50 de plus
  à chaque niveau (`niveauDepuisXp` dans `regles.ts`, même table que `scripts/core/progression.gd`).
- **Rangs** (PRD §7) : Débutant (1 à 5), Explorateur (6 à 10), Connaisseur (11 à 20), Expert (21 à 35), Maître
  biblique (36 et plus). Le Rang S viendra avec la 0.5.
- **Classement général** : leaderboard `xp` créé au démarrage du module (autoritatif, décroissant, opérateur
  `set`, rangs activés). Le score est l'XP totale, réécrit à chaque partie qui rapporte de l'XP.
- La réponse `fin` de l'arcade contient en plus `xp`, `xpTotal`, `niveauAvant` et `niveau`.

**Déployé le 2026-11-23** (commit `9f44c8c`, 18 tests serveur verts). Nakama a été redémarré deux fois pour
vérifier que `leaderboardCreate` ne casse rien quand le classement existe déjà. Le leaderboard `xp` est
autoritatif, décroissant, en opérateur `set`, avec les rangs activés. Vérifié depuis l'adresse publique avec un
compte de test, supprimé depuis (sa ligne du classement part avec lui) :

- défaite : +10 XP ; victoire : +30 XP (total 40) ; abandon : 0 XP ;
- le portefeuille contient `{"xp": 40, "talents": 98}` ;
- classement `GET /v2/leaderboard/xp` : le joueur y figure au rang 1 avec 40 ; une écriture du client est refusée (403) ;
- de 90 à 120 XP par une victoire : `niveauAvant: 1`, `niveau: 2`.

## Ce qui est sur le serveur (pour mémoire)

- Service systemd `nakama`, binaire et configuration dans `/opt/nakama`, sans Docker. L'API, la console
  d'administration et le gRPC n'écoutent que sur `127.0.0.1`.
- nginx (site `brindoujunior`) envoie `/v2/` et `/ws` à Nakama ; le reste du site est inchangé.
- Base PostgreSQL `perfectionnement`, rôle du même nom, joignable seulement depuis le serveur. Sauvegardée
  chaque nuit avec les autres bases de l'hôte et copiée hors du serveur.
- Les secrets (mot de passe de la base, clés de session, clé HTTP du runtime, accès à la console) restent sur le
  serveur et n'entrent jamais dans ce dépôt.

## Reste à faire côté serveur

- **0.2.6, connexion Google** : le client envoie un jeton d'identité Google (`link_google_async`, ou
  `authenticate_google_async` avec `create=false` quand le compte Google appartient déjà à un joueur).
  Identifiant OAuth « Application Web » du projet Google Cloud (public, il est dans l'APK) :
  `492954893860-3abik9silaiiea1toaf5nt473dj9bc1d.apps.googleusercontent.com`.
  Le serveur doit n'accepter que les jetons dont l'audience (`aud`) est cet identifiant. Si la configuration de
  Nakama le permet, la renseigner. Sinon, ajouter des hooks `before` sur l'authentification et le rattachement
  Google qui refusent tout autre `aud` (Nakama vérifie déjà la signature). Sans cela, un jeton Google émis pour
  n'importe quelle application ouvre un compte.
