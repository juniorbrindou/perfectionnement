# PRD — Perfectionnement

Jeu de cartes biblique en duel, pour mobile Android.

- **Statut** : v0.x en conception. Le passage en **1.0** est décidé par le porteur du projet, et par lui seul.
- **Source** : document de conception initial, puis session de questions-réponses du 2026-11-23. En cas de contradiction, ce PRD fait foi.

---

## 1. Vision

Un jeu de cartes rapide et stratégique pour apprendre la Bible en s'affrontant. Chaque joueur pose des questions dont lui seul connaît la réponse. Bien répondre détruit les cartes de l'adversaire, et **le premier qui n'a plus de cartes a perdu**.

- **Public** : tout le monde, chrétiens ou non.
- **Nature du projet** : gratuit, éducatif et communautaire. Aucune monétisation en v0.x.
- **Rôles** : Claude développe ; le porteur du projet pilote, teste, valide les questions et produit les illustrations.
- Le niveau dans le jeu mesure l'expérience **dans le jeu**, jamais la foi ou la valeur spirituelle d'une personne.

## 2. Règles du duel

### 2.1 Mise en place

- 2 joueurs, **5 cartes chacun**.
- La **difficulté** est choisie avant la partie (selon le mode ou le salon). **Toutes les cartes d'une partie ont la même difficulté**, connue des deux joueurs.
- Les cartes sont tirées au hasard parmi les questions qui correspondent à la difficulté et au contenu choisis :
  - aucun doublon dans une même partie ;
  - le tirage évite les questions vues par le joueur lors de ses **5 dernières parties**, tant que la réserve le permet.

### 2.2 Les trois niveaux de difficulté

| Niveau | Nom | Référence |
|---|---|---|
| Facile | **Lait** | Hébreux 5:12-14, 1 Corinthiens 3:2 |
| Moyen | **Manne** | Exode 16 |
| Difficile | **Nourriture solide** | Hébreux 5:14 |

### 2.3 Composition d'une carte

| Champ | Détail |
|---|---|
| Identifiant | unique |
| Difficulté | Lait, Manne ou Nourriture solide |
| Testament | Ancien ou Nouveau |
| Livre(s) | un ou plusieurs livres bibliques |
| Catégorie | Personnages, Miracles, Paraboles, Lieux et événements |
| Question | texte court et sans ambiguïté |
| Bonne réponse | 1 |
| Fausses réponses | **5** : 3 affichées au départ et 2 en réserve |
| Référence | livre, chapitre et versets (Louis Segond 1910) |
| Explication | une ou deux phrases affichées à la révélation |
| Récit | identifiant du récit biblique, qui détermine l'illustration |

### 2.4 Question de départ : qui commence

- Une question **facile à 5 propositions** est posée **aux deux joueurs en même temps**. Elle provient d'une **réserve séparée** des cartes de jeu.
- Le premier qui répond juste commence.
- Si un joueur répond faux, **l'autre commence directement**.
- Si personne ne répond en 10 secondes, une nouvelle question de départ est posée.

### 2.5 Déroulement d'un tour

1. **Le poseur choisit une carte** de sa main en **10 secondes**. Il voit le contenu et la bonne réponse de ses cartes. Si le temps est écoulé, une carte est jouée **au hasard** (passer la main est exclu, car un joueur pourrait alors ne jamais prendre de risque).
2. **Celui qui répond voit** la question, la catégorie et les propositions restantes de la carte (4, 3 ou 2). Il a **15 secondes** pour choisir.
3. **Bonne réponse** : la carte est **détruite** (avec une animation). Les deux joueurs voient la bonne réponse, la référence, l'explication et l'illustration du récit, puis touchent « Continuer ».
4. **Mauvaise réponse** : la carte **retourne chez son propriétaire** et la bonne réponse **n'est pas révélée**. La carte s'affaiblit :
   - **4 → 3 → 2 propositions** : la proposition choisie (fausse) est retirée ;
   - **à 2 propositions** (minimum) : la fausse proposition choisie est **remplacée** par une fausse réponse de la réserve, que le joueur n'a jamais vue ;
   - **réserve vide** : la dernière fausse proposition ne change plus.
5. **Temps écoulé pour répondre** : c'est compté comme une mauvaise réponse. La fausse proposition retirée (ou remplacée) est tirée au hasard.
6. Le tour passe à l'autre joueur **dans tous les cas** (alternance stricte).

On accepte qu'un joueur qui a bonne mémoire repère la bonne réponse : c'est la seule proposition présente à chaque passage. La mémoire fait partie des compétences du jeu, et le remplacement de la fausse réponse piège ceux qui en manquent.

### 2.6 Fin de partie

- **Le joueur qui n'a plus de cartes perd.** L'autre gagne.
- L'écran de résultats affiche le **récapitulatif des points** (talents, XP, score de salon) et, si on le souhaite, les **cartes détruites** pendant la partie.
- Les réponses des **cartes survivantes restent secrètes**.

### 2.7 Informations visibles

- Chaque joueur voit le contenu de ses propres cartes, réponses comprises.
- De l'adversaire, il ne voit que **ses cartes restantes, face cachée**, sans autre information.

## 3. Modes de jeu

| Mode | Adversaire | Compte requis | Mise | XP | Score de salon |
|---|---|---|---|---|---|
| **Arcade solo** | IA | oui | 2 / 5 / 10 | ✅ | — |
| **Duel rapide** | joueur au hasard, toute la Bible, difficulté au choix | non | 5 / 20 / 50 | ✅ | — |
| **Entre amis** | ami qui rejoint avec un code | non | 5 / 20 / 50 | ✅ | — |
| **Salon** | membre du salon | oui | 5 / 20 / 50 | ✅ | ✅ |
| **2 joueurs sur un téléphone** | personne présente | non | aucune | ❌ | — |

### 3.1 Arcade solo (IA)

- **Pour répondre**, l'IA a une chance de trouver la bonne réponse avec 4 propositions de **65 % en Lait, 55 % en Manne et 45 % en Nourriture solide**. Cette chance augmente quand il reste moins de propositions, et l'IA n'oublie jamais une proposition déjà éliminée.
- **Pour poser**, l'IA joue en priorité les cartes qui ont le plus de propositions restantes.
- Victoire : + la mise. Défaite : − la mise. Pas de gratuité ni de plafond.
- **L'arcade se joue sur la carte d'aventure** (validé le 2026-11-23) : chapitres bibliques découpés en niveaux. Chaque niveau se joue dans la difficulté choisie, et **chaque difficulté gagnée donne une étoile** (3 étoiles par niveau). La première victoire ouvre le niveau suivant. L'IA s'appelle **le Scribe**.

### 3.2 2 joueurs sur un téléphone

- On choisit la difficulté et le contenu (toute la Bible, un Testament ou un ou plusieurs livres) avant la partie.
- **Les cartes sont face cachée.** Il faut toucher une carte pour la **retourner avec une animation**, même pendant son propre tour. Ce geste n'existe que dans ce mode.
- Un écran **« Passe le téléphone à [Joueur X] »** s'affiche entre chaque action, et l'autre joueur doit toucher l'écran pour continuer. Celui qui répond ne voit jamais la bonne réponse.
- La question de départ se joue sur un **écran partagé** : chaque joueur a ses 5 boutons de son côté de l'écran.
- Aucun talent ni aucune XP (pour éviter de jouer contre soi-même).

### 3.3 Duel rapide et entre amis (validé le 2026-11-23)

- **Duel rapide** : le joueur choisit la difficulté (donc la mise) et cherche un adversaire de la même difficulté. Les questions portent sur toute la Bible. La recherche continue tant qu'il ne l'annule pas ; au bout de 30 secondes, on lui propose aussi d'**inviter un ami avec un code** et, s'il a un compte, de **jouer contre le Scribe** (la carte d'aventure).
- **Entre amis** : le créateur choisit **la difficulté seulement** (toute la Bible) et reçoit un code. L'ami voit la difficulté et la mise avant de rejoindre, et peut refuser.
- **Quand l'adversaire répond à ta carte**, tu vois « [Pseudo] réfléchit… » et son minuteur, puis sa réponse.
- **Revanche** : à la fin, un bouton relance une partie contre le même adversaire, même difficulté et même mise, si **les deux** acceptent dans les 15 secondes.

### 3.4 Abandon et déconnexion (modes en ligne)

- **Abandon** : défaite immédiate, et l'adversaire remporte la mise.
- **Déconnexion** : la partie est en pause, et le joueur a **30 secondes** pour revenir. Sinon, il perd et l'adversaire remporte la mise.
- **Les deux joueurs déconnectés** : la partie est annulée et chacun récupère sa mise.

## 4. Économie : les talents

- La **monnaie unique** s'appelle les **talents** (parabole des talents).
- Chaque joueur **démarre avec 100 talents**.
- **Pain quotidien** : +10 talents par jour, à la connexion.
- **Mises par joueur** :

| | Lait | Manne | Nourriture solide |
|---|---|---|---|
| Duel (rapide, entre amis, salon) | 5 | 20 | 50 |
| Arcade solo | 2 | 5 | 10 |

- Les deux joueurs misent le même montant, et **le gagnant remporte toute la mise**.
- Un joueur qui n'a pas assez de talents **ne peut pas jouer à ce niveau**. Il n'y a aucune gratuité de secours : un joueur ruiné attend le pain quotidien du lendemain.
- Créer un salon coûte **30 talents**. Rejoindre un salon est gratuit.
- **Les talents ne s'achètent jamais avec de l'argent réel.**

## 5. Comptes

| | Invité | Connecté |
|---|---|---|
| Pseudo | proposé automatiquement, modifiable | choisi |
| Pain quotidien | ✅ | ✅ |
| Duel rapide | ✅ | ✅ |
| Entre amis | ✅ | ✅ |
| 2 joueurs sur un téléphone | ✅ | ✅ |
| Arcade solo | ❌ | ✅ |
| Rejoindre ou créer un salon | ❌ | ✅ |

- Connexion avec **Google** ou **e-mail et mot de passe**. La connexion Apple viendra avec iOS.
- L'invité est identifié par son appareil. Quand il crée un compte, il **garde son pseudo, ses talents et son XP**.
- Exigences Google Play : une politique de confidentialité et la **suppression du compte depuis l'application**.

## 6. Salons

### 6.1 Principe

Un salon est une **communauté permanente** créée par un joueur, avec ses membres, ses critères et son classement interne.

### 6.2 Création

- Elle est réservée aux comptes connectés et coûte **30 talents**.
- **Un joueur ne peut avoir créé qu'un seul salon** à la fois.
- Critères choisis à la création :
  1. **Difficulté** (obligatoire) : Lait, Manne ou Nourriture solide. Elle fixe la mise.
  2. **Contenu** (un seul choix) : toute la Bible, un Testament, un ou plusieurs livres, ou une catégorie.
  3. **Nom** du salon.
  4. **Accès** : public ou privé.
- Une combinaison de critères n'est possible que si **au moins 40 questions validées** y correspondent. Les combinaisons trop pauvres sont grisées, avec le message « Pas encore assez de questions ».

### 6.3 Accès et membres

- Tous les salons sont **visibles de tous, membres compris**, y compris les salons privés.
- **Public** : on le rejoint d'un clic. **Privé** : il faut le **code d'invitation**.
- **On ne peut être membre que d'un seul salon à la fois.**
- Un salon compte **50 membres au maximum**.

### 6.4 Jouer dans un salon

- **Recherche rapide** : le joueur est associé au hasard à un autre membre du salon qui cherche aussi une partie.
- **Défi direct** : il choisit un membre connecté, qui accepte ou refuse.

### 6.5 Score de salon et rôles

- **Score de salon** : +10 par victoire, −5 par défaite, sans descendre sous 0. Il est perdu quand on quitte le salon.

| Rôle | Attribution | Pouvoirs |
|---|---|---|
| **Berger** | le créateur ; s'il part, le 1er du classement | renommer le salon, passer en public ou privé, changer le code, exclure un membre |
| **Vaillant héros** | 1er du classement du salon | honorifique |
| **Sentinelle** | 2e du classement du salon | honorifique |

Le Berger peut aussi porter un titre honorifique s'il est 1er ou 2e.

### 6.6 Suppression automatique

Un salon est supprimé quand il **n'a plus aucun membre**, ou après **7 jours sans aucune partie jouée**.

## 7. Progression

- **XP** : +30 par victoire et +10 par défaite, dans tous les modes sauf le mode 2 joueurs sur un téléphone. Une partie abandonnée ne rapporte pas d'XP.
- **Niveaux** : 100 XP pour passer au niveau 2, puis 50 XP de plus à chaque niveau (niveau 5 à 700 XP, niveau 36 à 33 250 XP).
- **Rangs** :

| Rang | Condition |
|---|---|
| Débutant | niveaux 1 à 5 |
| Explorateur | niveaux 6 à 10 |
| Connaisseur | niveaux 11 à 20 |
| Expert | niveaux 21 à 35 |
| Maître biblique | niveau 36 et plus |
| **Rang S** | **les 10 premiers du classement général**. Ce rang peut être perdu. |

- Un **classement général** par XP.

## 8. Contenu

### 8.1 Règles éditoriales

- La traduction de référence est la **Louis Segond 1910** (domaine public).
- Les questions portent sur des **faits narratifs vérifiables**, pas sur des citations mot pour mot.
- **Neutralité confessionnelle** : uniquement les livres communs à tous les canons (pas de deutérocanoniques), et aucune question doctrinale ou d'interprétation.
- Chaque question a une seule bonne réponse, des fausses réponses plausibles et une référence précise.
- **Circuit de validation** : Claude rédige les brouillons avec leurs références, puis le porteur du projet valide chaque question avant publication.

### 8.2 Volume

- **Premier lot** : 300 cartes (100 Lait, 100 Manne, 100 Nourriture solide), réparties sur toute la Bible.
- **50 questions de départ** (faciles, 5 propositions).
- **Deux réserves sans carte commune** (validé le 2026-11-23) : la réserve **téléphone**, dans l'APK, pour le mode 2 joueurs hors ligne ; la réserve **en ligne**, gardée sur le serveur, pour l'arcade, les duels et les salons. Une carte présente dans l'APK peut être lue par un tricheur, donc elle n'est jamais tirée en ligne. Cible : environ 1 carte sur 4 pour le téléphone, avec au moins 10 cartes par difficulté de chaque côté.
- Ensuite, on enrichit **livre par livre** pour que les salons thématiques atteignent 40 questions.
- La production du contenu avance **en parallèle** des versions.

### 8.3 Langue

Le jeu sort en **français uniquement**. Les textes de l'interface et les questions sont structurés pour accueillir d'autres langues sans refonte.

## 9. Direction artistique et audio

Direction validée le 2026-11-23 sur maquettes (artifact « Perfectionnement — cartes illustrées ») :

- **La carte porte son contenu** : la question est dans une bulle de dialogue sur la carte, et les réponses (A, B, C, D) se lisent et se touchent directement sur la carte.
- **Cadre de carte de jeu** : liseré jaune à coins coupés ; médaillon de difficulté en haut à gauche, pastille de catégorie en haut à droite, jauge des réponses restantes (4, 3 ou 2) sur le bord gauche.
- **Couleurs vives** : violet profond (fond), jaune tournesol (boutons, cadres), framboise (bande des réponses). Une couleur de carte par difficulté : Lait en sarcelle, Manne en doré, Nourriture solide en framboise.
- **Polices** : Lilita One (titres, réponses), Nunito (texte).
- **Écrans en 2D animés** : les cartes se retournent, la main s'ouvre en éventail, un tampon marque la carte détruite. La table 3D est abandonnée.
- **Style d'illustration** : personnages bibliques en dessin animé coloré, scènes chaleureuses (arche de pierre éclairée sur l'accueil).
- **Carte d'aventure** : elle arrive avec l'arcade (0.2.4), avec un premier chapitre (la Genèse, 8 niveaux). **Plus tard** : les autres chapitres, et un classement clair avec le badge Rang S.
- **Une illustration par récit biblique**, partagée par les cartes de ce récit : environ 60 à 80 pour le premier lot.
- Les illustrations sont **produites par l'équipe**, à partir d'images libres de droits ou dessinées à la main. Claude fournit la liste des récits, les formats attendus et des images provisoires.
- **Règles de représentation** :
  - Dieu le Père n'est jamais représenté sous forme humaine (lumière, nuée, main, buisson ardent) ;
  - Jésus peut être représenté, dans un style classique et sans caricature ;
  - la violence est suggérée, jamais détaillée.
- **Audio** : des effets sonores (carte retournée, carte détruite, tic-tac, bonne et mauvaise réponse, victoire) et une musique de fond calme, libre de droits. Les effets et la musique se coupent séparément.

## 10. Modération

- Un **filtre de mots interdits** à la saisie des pseudos et des noms de salons (insultes, haine, moqueries religieuses).
- Un bouton **« Signaler »** sur un pseudo ou un salon.
- Un **outil d'administration** pour renommer ou supprimer un salon et bannir un joueur.

## 11. Technique

| Élément | Choix |
|---|---|
| Plateforme | **Android uniquement** en v0.x |
| Moteur | **Godot 4** (GDScript) |
| Serveur | **Nakama** (Docker + PostgreSQL) sur le **VPS Contabo** existant |
| Autorité | les parties en ligne sont **gérées par le serveur** : le téléphone de celui qui répond ne reçoit **jamais** la bonne réponse |
| iOS (plus tard) | compilation sur un Mac loué (GitHub Actions ou Codemagic), un compte développeur Apple et un iPhone de test |

Correspondance avec les fonctions de Nakama :

| Besoin | Fonction Nakama |
|---|---|
| Invité | connexion par appareil |
| Google, e-mail | connexion intégrée |
| Talents | portefeuille (*wallet*) |
| Salons et rôles | groupes avec rôles |
| Classements | classements (*leaderboards*) |
| Recherche rapide, défis | matchmaking, notifications |
| Parties | parties gérées par le serveur (*authoritative matches*) |

## 12. Feuille de route

| Version | Contenu | Terminée quand |
|---|---|---|
| **0.1** | Le cœur du jeu **en local** : mode 2 joueurs sur un téléphone avec toutes les règles de la section 2, écrans de carte animés, images provisoires, premier lot de cartes validées | une partie complète se joue de bout en bout sur un téléphone Android |
| **0.2** | **Nakama** sur le VPS : invité, compte Google et e-mail, talents, pain quotidien, **arcade contre l'IA**, XP et niveaux | un joueur crée son compte, gagne et perd des talents en arcade |
| **0.3** | **Duels en ligne** : duel rapide et partie entre amis, mises, abandon et déconnexion | deux téléphones jouent une partie en ligne, et la mise est versée au gagnant |
| **0.4** | **Salons** (toute la section 6) et **modération** | un salon se crée, se rejoint, classe ses membres et se supprime automatiquement |
| **0.5** | **Finitions** : classement général et Rang S, sons et musique, vraies illustrations, animations soignées | — |
| **0.6 – 0.9** | Bêta fermée sur Google Play, corrections, équilibrage | — |
| **1.0** | Déclarée par le porteur du projet | — |

## 13. Valeurs à ajuster après les tests

Ces valeurs sont validées pour démarrer, mais seront rééquilibrées :

- les minuteurs (10 s pour choisir, 15 s pour répondre, 10 s pour la question de départ, 30 s pour une reconnexion) ;
- les 5 cartes par joueur, pour une durée visée de 3 à 5 minutes ;
- les pourcentages de réussite de l'IA ;
- les mises, le pain quotidien, le capital de départ et le coût de création d'un salon ;
- les gains d'XP et les seuils de niveaux ;
- les 40 questions minimum par salon et les 50 membres maximum ;
- l'ordre d'affichage des propositions, mélangé à chaque passage par défaut.

## 14. Hors périmètre v0.x

- Les cartes spéciales (Protection, Échange, Défi).
- iOS et la connexion Apple.
- Tout achat avec de l'argent réel.
- Les autres langues que le français.
- Les collections de cartes, succès et trophées.
- La liste d'amis (les amis jouent ensemble avec un code de partie).
