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
| `suite` | coup suivant : le Scribe pose sa carte, ou le joueur a 20 s pour choisir |
| `jouer {index}` | le joueur pose (`-1` ou hors délai : au hasard), le Scribe répond aussitôt |
| `repondre {choix}` | réponse à la carte du Scribe (`""` ou hors délai : temps écoulé) |
| `abandonner` | défaite, la mise reste perdue |

Chaque réponse contient `vue` (ce que le joueur voit : ses cartes, le nombre de cartes du Scribe, la carte à
deviner) et, en fin de partie, `fin {gagne, gain, nouvelleEtoile, talents, etoiles}`. Victoire : le joueur
reçoit **deux fois la mise** (`raison: gain_arcade`). Délais : 20 s pour poser, 30 s pour répondre, plus 3 s
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

**Triche possible, réglée en 0.3.1 (voir plus bas)** : la vue envoie l'`id` de la carte à deviner, et
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

## Module serveur (0.3.1) : deux réserves de cartes

Correction de la triche relevée en 0.2.4. Les cartes sont séparées en deux réserves sans carte commune
(vérifié par `tests/test_data.gd`) :

- **réserve « téléphone »** : `data/cartes.json` et `data/questions_depart.json`, dans l'APK, pour le mode
  2 joueurs hors ligne ; jamais tirée en ligne ;
- **réserve « en ligne »** : `data/en_ligne/`, exclue de l'APK (`exclude_filter` et `.gdignore`), embarquée
  dans `index.js` par `outils/donnees.js`. Elle sert à l'arcade, puis aux duels et aux salons.

Le client n'a donc plus les cartes de l'arcade : le serveur envoie leur texte.

| Champ | Contenu |
|---|---|
| `vue.main[]` | `{carte, fausses, reserve}` : `carte` entière (format de `cartes.json`), puisque ce sont les cartes du joueur |
| `vue.carte` | carte à deviner : `{difficulty, category, question, story, propositions}`, **sans identifiant ni réponse** |
| `vue.depart` | `{question, propositions}`, sans identifiant |
| `vue.detruites` | cartes entières (toutes ont été trouvées) |
| `coup.carte` (`jouer`) | la carte du joueur, entière |
| `coup.carte` (`repondre`) | la carte du Scribe entière si elle est trouvée, `null` sinon (la réponse reste secrète) |
| `etat.duChapitre` | niveau → difficulté → vrai si les livres du chapitre suffisent (sinon toute la Bible) |

Avec 60 cartes, chaque réserve en a 10 par difficulté (le minimum pour deux mains). Questions de départ : 5 sur le
téléphone, 10 en ligne. **À redéployer** : le module et l'APK changent ensemble (un ancien APK ne sait plus lire
les cartes de l'arcade).

## Module serveur (0.3.2) : duels en ligne

Partie en direct gérée par le serveur : *match* autoritatif Nakama `duel` (`server/src/duel_en_ligne.ts`),
5 tics par seconde. Les règles sont des fonctions pures testées sans Nakama ; les fonctions `duel*` les
appliquent (portefeuilles, stockage, messages). Le client passe par le **socket temps réel** (`/ws`).

**Duel rapide** : le client entre dans le matchmaker avec `min_count = max_count = 2`, la requête
`+properties.difficulte:lait` et la propriété texte `difficulte` (`lait`, `manne` ou `solide`). Le hook
`apresAppariement` crée la partie pour les deux joueurs trouvés, qui la rejoignent avec l'identifiant reçu.
S'ils ne sont pas là tous les deux en 20 s, la partie est annulée (aucune mise prélevée).

**Entre amis** : RPC `duel_ami`.

| Action | Effet |
|---|---|
| `creer {difficulte}` | crée la partie et renvoie `{matchId, code, difficulte, mise}` ; code de 6 caractères sans 0/O ni 1/I/L |
| `voir {code}` | `{matchId, difficulte, mise, createur}` si une partie attend avec ce code, sinon 404 |

Le créateur rejoint la partie en premier, puis l'ami avec le code. Une partie attend son invité 10 minutes au
plus, et elle est annulée si le créateur part avant.

**Messages** (op code, données JSON) du téléphone vers le serveur : `1` départ `{choix}`, `2` jouer `{index}`,
`3` répondre `{choix}`, `4` continuer, `5` abandonner, `6` revanche `{accepte}`. Le serveur envoie à chaque
joueur **sa** vue (op `10`) après chaque changement : étape, adversaire (pseudo, niveau, présent), qui pose, sa
main en entier, le nombre de cartes adverses, la carte à deviner sans réponse, la question de départ, le dernier
coup, les cartes détruites, le temps restant, la pause, la fin et la revanche.

| Règle | Valeur |
|---|---|
| Mises | prélevées aux deux joueurs quand la partie commence ; le gagnant reçoit les deux (`mise_duel`, `gain_duel`) |
| Question de départ | posée aux deux ; le premier qui répond décide (juste : il commence ; faux : l'autre). Personne en 30 s : nouvelle question |
| Délais | 30 s pour poser, 45 s pour répondre (le triple des délais d'origine), 1 s de marge réseau ; ensuite carte au hasard ou temps écoulé |
| Résultat d'un coup | tour suivant quand les deux touchent « Continuer », ou au bout de 10 s |
| Abandon | défaite, 0 XP ; l'adversaire gagne la mise et 30 XP |
| Déconnexion | la partie se met en pause (délais gelés) ; 30 s pour revenir, sinon défaite sans XP |
| Les deux déconnectés | après 30 s, partie annulée et mises rendues (`remboursement_duel`) |
| Revanche | 15 s après la fin ; si les deux acceptent, nouvelle donne et nouvelles mises |
| Arrêt du serveur en pleine partie | mises rendues |

Les cartes des 5 dernières parties sont désormais rangées dans `parties` / `recentes`, communes à l'arcade et aux
duels (l'ancienne clé `arcade` / `recentes` n'est plus lue).

**0.3.1 et 0.3.2 déployées le 2026-11-24** (commit `5393100`, 29 tests serveur verts). Le module embarque 30 cartes
et 10 questions de départ de la réserve en ligne. Vérifié depuis l'adresse publique avec des comptes de test,
supprimés depuis :

- **arcade** : la question de départ arrive avec son texte, les cartes de la main sont complètes. Sur toute une
  partie, la carte à deviner n'a jamais eu d'`id` ni d'`answer`. Fin de partie avec XP et talents.
- **entre amis** : `creer` (code, mise 5), puis l'ami rejoint et joue la partie par le socket jusqu'à `fin`
  (raison `cartes`). Perdant 98 → 93 talents et +10 XP, gagnant 100 → 105 et +30 XP. Aucune réponse dans les
  vues du joueur qui devine.
- **duel rapide** : deux invités appariés par le matchmaker (`+properties.difficulte:lait`), partie créée par
  le hook. Abandon : 0 XP pour celui qui part, +5 talents et +30 XP pour l'autre.

À savoir pour le client :

- **Appariement** : comme le hook crée la partie, le message `matchmaker_matched` porte un `match_id` et pas de
  `token`. Il faut rejoindre avec ce `match_id` (rejoindre avec le jeton renvoie « No match ID or token found »).
- **`voir {code}`** ne trouve la partie qu'une fois que le créateur l'a rejointe. Avant, la liste des parties ne
  la contient pas encore (404). C'est l'ordre prévu : le créateur rejoint aussitôt après `creer`.

**Délais redéployés le 2026-11-24** (commit `283ead1`). Le module servi porte `DELAI_*` 20/20/30 s pour l'arcade
et `DUEL_*` 30/30/45 s pour les duels en ligne. Vérifié en public : 20 s pour la question de départ de l'arcade,
30 s pour celle d'un duel entre amis, des deux côtés.

## Ce qui est sur le serveur (pour mémoire)

- Service systemd `nakama`, binaire et configuration dans `/opt/nakama`, sans Docker. L'API, la console
  d'administration et le gRPC n'écoutent que sur `127.0.0.1`.
- nginx (site `brindoujunior`) envoie `/v2/` et `/ws` à Nakama ; le reste du site est inchangé.
- Base PostgreSQL `perfectionnement`, rôle du même nom, joignable seulement depuis le serveur. Sauvegardée
  chaque nuit avec les autres bases de l'hôte et copiée hors du serveur.
- Les secrets (mot de passe de la base, clés de session, clé HTTP du runtime, accès à la console) restent sur le
  serveur et n'entrent jamais dans ce dépôt.

## Reste à faire côté serveur

- **0.2.6, connexion Google** : **fait le 2026-11-23.** La configuration de Nakama porte
  `google_auth.client_ids: ["492954893860-3abik9silaiiea1toaf5nt473dj9bc1d.apps.googleusercontent.com"]`, si bien
  que Nakama vérifie lui-même l'audience (`aud`) en plus de la signature, sans hook. L'avertissement de
  démarrage « Google auth config missing client ID » a disparu. Un jeton forgé pour une autre application est
  refusé (401, « Could not authenticate Google profile. »). Aucun vrai jeton Google n'a encore été essayé : le
  premier passera par le téléphone.
- **Correction du 2026-11-24** : les vraies connexions depuis le téléphone échouaient (« google id token invalid »).
  Quand `client_ids` est renseigné, Nakama vérifie l'audience **et** la partie autorisée (`azp`) du jeton. Sur
  Android, `azp` est l'identifiant du client OAuth **Android** (paquet + empreinte SHA-1 de l'APK), pas celui de
  l'application Web. Les deux clients Android, `…-n2b5kq2s3r7vei7b6a9eeo4grkq23nd3` pour l'APK de test et
  `…-6pvrha92lpr8ct0n16o46ld9rsbtnla2` pour l'APK publiée, sont maintenant déclarés avec le client Web. Toute
  nouvelle clé de signature demande un nouveau client Android dans Google Cloud, **et** son ajout ici.

## Salons (RPC `salon`) : déployés le 2026-11-28

Module de la branche `flutter` (commit `881ecc8` + correctif), 35 tests serveur verts. Le changement ne fait
qu'ajouter des fonctions : l'APK Godot de `master` continue de fonctionner. Vérifié depuis l'adresse publique avec des
comptes de test, supprimés depuis : options, nom trop court ou déjà pris refusé, création (Berger), liste, demande,
demande visible du seul Berger, réponse refusée à un non-Berger, acceptation (2 membres), départ du Berger (le membre
restant devient Berger), départ du dernier membre (salon supprimé).

**Correctif déployé** : la demande d'adhésion n'arrivait jamais au Berger. Une valeur lue dans le stockage Nakama
est un objet Go vu depuis JavaScript : `push()` sur ses tableaux modifie une copie jetable. `lireSalon` et
`tousLesSalons` font maintenant une copie profonde (`JSON.parse(JSON.stringify(...))`). Les tests Node ne voient pas
ce piège, car leur faux Nakama renvoie des objets ordinaires. **Règle** : toute valeur lue dans le stockage et
modifiée avant réécriture passe par cette copie.

À corriger :

- **Un invité peut créer un salon** et en demander un. Le PRD (§5, §6.2) les réserve aux comptes e-mail ou Google,
  comme l'arcade : ajouter le même contrôle que `commencer` dans `creer` et `demander`.
- **`repondre` avec `accepte: true`** envoie la notification « Bienvenue au salon » même quand le joueur est déjà
  membre d'un autre salon et n'est donc pas ajouté.
- **Le score de salon** (`scoreApresPartie`, +10/−5) n'est encore appelé nulle part : les duels ne le mettent pas
  à jour.

## Réglages du jeu et back-office : déployés le 2026-11-28

Les valeurs d'équilibrage ne sont plus figées dans le code : `server/src/reglages.ts` liste 29 réglages, chacun
avec sa valeur par défaut (celle d'avant), ses bornes et son libellé. Ils sont regroupés en économie, délais,
progression, Scribe et salons. Seules les valeurs changées sont stockées (collection `config`, clé `reglages`,
propriétaire système, illisible par les joueurs), avec un historique (clé `historique`, 200 entrées). Chaque point
d'entrée du module (RPC, hooks, fonctions de partie) appelle `chargerReglages(nk, logger)`, qui relit au plus toutes
les 30 s : **un changement s'applique en moins d'une minute, sans redéploiement.**

- **Back-office** : `https://brindoujunior.com/perfectionnement-admin/`, protégé par mot de passe nginx
  (`/etc/nginx/perfectionnement-admin.htpasswd`). Source : `backoffice/index.html`. Pour le mettre à jour, la copier dans
  `/var/www/perfectionnement-admin/`. La page appelle `api`, que nginx relaie au RPC `reglages_admin` en ajoutant la
  clé HTTP de Nakama et le nom de l'utilisateur connecté (`auteur`). Aucun secret n'est dans la page.
- **RPC `reglages_admin`** (clé HTTP seulement ; refusé à un joueur, code 7) : `lire`, `enregistrer { valeurs }`
  (refus clair hors bornes ou non entier), `reinitialiser { cles }`. Remettre la valeur par défaut efface l'entrée
  stockée.
- **RPC `reglages`** (joueurs) : toutes les valeurs en vigueur, `{ cle: nombre }`. **À faire côté application** :
  la lire à l'ouverture et l'utiliser pour tout chiffre affiché (mises, coût d'un salon, capital, délais), au lieu
  de constantes en dur.
- **Ajouter un réglage** : une ligne dans `REGLAGES` (`reglages.ts`), la constante concernée passée de `const` à
  `let`, et son affectation dans `appliquerReglages`. Les tests vérifient que chaque défaut égale la constante du code.
- **Pas réglables pour l'instant** : les seuils de niveau (100, puis +50). L'application les calcule elle-même, donc
  les changer côté serveur seulement fausserait l'affichage. Même chose pour les 5 cartes par main, liées à la mise
  en page des écrans.

Vérifié depuis l'adresse publique : page et `api` refusées sans mot de passe ou avec un mauvais (401), `GET api`
refusé (403), clé HTTP absente de la page, refus hors bornes, puis capital 100 → 120 et pain 10 → 15. Un nouveau
compte reçoit alors 120 talents et un pain de +15, et le RPC `reglages` renvoie ces valeurs. Les valeurs ont été
rétablies ensuite, et l'historique garde les deux changements avec l'auteur `admin`. Page contrôlée à 375 px de
large, sans défilement horizontal.


## Gestion des cartes : déployée le 2026-11-28

`server/src/cartes.ts` et l'écran **`https://brindoujunior.com/perfectionnement-admin/cartes.html`** (même mot de
passe que les réglages). Pour les deux réserves (« En ligne » et « Partie à deux ») et les deux types (cartes,
questions de départ) : créer, modifier (formulaire ou JSON), valider en lot, mettre à la corbeille, restaurer,
importer et exporter en JSON au format de `data/*.json`. Rien à redéployer.

**Source de vérité.** Tant qu'une réserve n'a jamais été modifiée, le serveur utilise les fichiers `data/` embarqués
à la compilation. **Après la première modification, le serveur fait foi** (stockage `cartes` / `en_ligne` ou
`telephone`) : une correction dans les fichiers du dépôt n'a d'effet qu'une fois **importée** depuis l'écran. Pour
garder le dépôt à jour, exporter et commiter le fichier.

Règles appliquées par le serveur (refus complet, rien n'est écrit à moitié) :

- mêmes contrôles que `CardData.problems()` : 5 fausses réponses (4 pour une question de départ), pas de doublon,
  livre connu, champs obligatoires ;
- pas de carte commune aux deux réserves, par identifiant ou par question (anti-triche) ;
- au moins 10 cartes jouables par difficulté et 1 question de départ ;
- « supprimer » = statut `retiree` : plus tirée, mais gardée pour les parties en cours, et restaurable.

Réglage ajouté : `cartes_brouillons` (1 par défaut). À 0, seules les cartes `valide` sont jouées. Le serveur
refuse de passer à 0 tant qu'il n'y a pas assez de cartes validées.

RPC `cartes_admin` (clé HTTP) : `lire`, `enregistrer`, `statut`, `importer { mode: fusionner | remplacer, essai }`.
Nakama accepte des requêtes de 2 Mo (`socket.max_request_size_bytes`) pour les imports ; nginx limite l'API publique
`/v2/` à 256 Ko.

**À faire côté application** : la partie à deux lit encore les cartes embarquées dans l'APK. Le RPC joueur
**`cartes_telephone`** renvoie `{ version, cartes, depart }` (cartes jouables de la réserve « Partie à deux »,
`version` vide si jamais modifiée) : l'appeler à l'ouverture, garder la réponse sur le téléphone, et revenir aux
fichiers embarqués hors ligne.

**Correctif du même jour sur les réglages** : Nakama fige les objets globaux après `InitModule`. L'application des
réglages plantait à la première mise (`Cannot assign to read only property`), et tout ce qui suivait restait aux
valeurs du code. **Règle** : remplacer un objet ou un tableau global, ne jamais le modifier. Les tests figent
maintenant les objets comme Nakama.

Vérifié depuis l'adresse publique (données de test supprimées ensuite) : accès refusé sans mot de passe et aux
joueurs, fiches invalides ou communes aux deux réserves refusées, création, modification, corbeille, import de 400
cartes à l'essai, et une partie d'arcade qui sert la question de départ créée dans l'écran. Page contrôlée à 375 px.

## Cartes « Structure de la Bible » : ajoutées le 2026-11-28

135 cartes de catégorie `structure` (12 faits, 66 « combien de chapitres », 50 « quel livre vient après », 7 groupes),
générées par `tools/cartes_structure.py` : 68 en ligne, 67 pour la partie à deux, toutes en `brouillon`.

- Cette catégorie peut n'avoir **ni livre ni testament** (`books: []`, `testament: ""`), quand l'image du livre
  trahirait la réponse. Serveur, application, back-office et `card_data.gd` l'acceptent.
- **Une carte Structure au plus par main** (`composerMains` côté serveur, `DeckBuilder` côté application), sauf si
  la réserve ne contient pas assez d'autres cartes.
- Écartées, car la réponse se discute dans la Louis Segond : le plus long verset (Jérémie 21:7 en nombre de lettres,
  1 Chroniques 29:2 en nombre de mots, Esther 8:9 en hébreu et en anglais) et le livre au plus grand nombre de mots
  (Psaumes en français, Jérémie en hébreu).
- Une fois une réserve modifiée au back-office, relancer le script ne suffit plus : importer le fichier.
- À améliorer côté application : le pictogramme de cette catégorie reprend pour l'instant celui des personnages, et
  les cartes sans livre n'ont pas d'illustration.

## Application Flutter : profil et connexions (2026-11-28)

`app/lib/ui/profile/profile_screen.dart`, porté de `scripts/ui/profile.gd` : changement de pseudo, compte e-mail
rattaché au compte invité, reprise d'un compte (sans jamais en créer) et connexion Google (`google_sign_in` 7,
`serverClientId` = client Web). 4 tests à 360 points de large, compilation Android vérifiée.

- **Google ne marche qu'avec un APK signé par une clé déclarée** : le client Android de publication l'est déjà pour
  `com.juniorbrindou.perfectionnement`. La version β du serveur (`….flutter`, clé de test du serveur, SHA-1
  `E2:1F:67:0E:71:9E:D5:A2:75:C8:A3:BB:31:79:7C:97:C2:AD:B7:DC`) demanderait son propre client Android dans
  Google Cloud, à ajouter ensuite à `google_auth.client_ids`.
- **Publication** : déposer `app/android/key.properties` (non versionné : `storeFile`, `storePassword`, `keyAlias`,
  `keyPassword`). Sans lui, la release est une β qui s'installe à côté. Les brouillons de la partie à deux ne sont
  inclus en release qu'avec `--dart-define=BROUILLONS=true`, et **toutes les cartes sont encore en brouillon**.
- Sur le serveur de build (Linux), `app/data` et `app/assets` sont des liens vers la racine, comme les jonctions
  Windows.

## Salons jouables et application complétée : 2026-11-28

**Serveur (déployé).**
- **Partie de salon** (PRD §6.4, recherche rapide) : le matchmaker reçoit la propriété `salon` (identifiant sans
  tirets) avec la requête `+properties.salon:<marque>`. Le hook exige la même marque chez les deux joueurs et vérifie
  qu'ils sont membres. La partie est en mode `salon`, avec la difficulté et le contenu du salon.
- **Score** : `+10 / −5` appliqués à la fin de la partie (`reglerScoreSalon`), `dernierePartie` mis à jour.
- `creer` et `demander` exigent un compte e-mail ou Google. Un joueur déjà parti dans un autre salon ne reçoit plus
  « Bienvenue ».
- Le duel rapide vérifie aussi que les deux joueurs ont la même difficulté (le matchmaker ne contrôle qu'un côté).

Vérifié depuis l'adresse publique : invité refusé, non-membre écarté, partie de salon entre deux membres, score 10/0
après un abandon.

**Application.** Partie de salon depuis la fiche, écran Classement, sons et musique (`lib/state/sound.dart`, réglages
dans le profil), animation de démarrage (`lib/ui/splash.dart`, une fois par lancement), cartes de la partie à deux
lues via `cartes_telephone` et gardées sur le téléphone, pictogramme « livre » pour la catégorie Structure.

**Pas fait** : le **défi direct** d'un membre (PRD §6.4), les outils du Berger au-delà des demandes (renommer,
exclure : PRD §6.5, à revoir avec les salons sans code), la modération (PRD §10), le choix des musiques (une seule
piste), la suppression du compte depuis l'application (exigée par Google Play).

