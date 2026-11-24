# Animation de démarrage « Le duel s'ouvre »

Validée le 2026-11-24 par le porteur du projet, sur l'aperçu [`maquettes/splash-apercu.mp4`](maquettes/splash-apercu.mp4).
La source de cet aperçu, [`maquettes/splash.html`](maquettes/splash.html), donne le minutage et les courbes exactes :
le reproduire dans Godot, sans réinventer.

## Ce que voit le joueur

| Instant | Ce qui se passe | Son |
|---|---|---|
| 0 – 0,3 s | Fond bleu nuit (`#03102a`, halo bleu au centre), poussière d'or qui scintille et dérive vers le haut | — |
| 0,28 – 0,8 s | Deux cartes (dos `assets/duel/dos_carte.png`) arrivent de gauche et de droite, inclinées, et se rejoignent au centre | `carte` à 0,3 s |
| 0,8 s | Choc : éclair doré qui grossit, 18 étincelles en étoile, secousse de l'écran (260 ms) | `feu` (0,7 s, en fondu) à 0,79 s |
| 0,86 – 1,16 s | Les cartes se retournent (rotation sur l'axe vertical) et disparaissent ; une colonne de lumière dorée monte | — |
| 0,92 – 1,44 s | La Bible du logo s'élève de la lumière, très lumineuse, puis reprend ses couleurs | — |
| 1,28 – 1,76 s | L'enseigne « Perfectionnement » et son ruban apparaissent avec un léger rebond (1,16 → 0,97 → 1) | `juste` à 1,3 s |
| 1,78 – 2,3 s | Un reflet de lumière balaie les lettres de gauche à droite | — |
| 2,28 – 2,84 s | Le logo monte et grandit légèrement jusqu'à la place exacte du titre de l'accueil | — |
| 2,62 – 3,0 s | L'accueil apparaît en fondu dessous ; le logo s'efface quand il est en place | — |

Durée totale : environ 3 s. Le titre de l'accueil et le logo doivent se superposer exactement à la fin : régler la
position cible sur l'écran réel.

## Règles

- **Touchez pour passer** : un toucher n'importe où va directement à l'accueil.
- **Une seule fois par lancement** : seulement au démarrage à froid, jamais en revenant d'une partie.
- **Ne rien retarder** : la connexion invitée (`Online.connect_guest`) et le chargement de l'accueil se font pendant
  l'animation. Si l'accueil n'est pas prêt à 3 s, garder le logo en place jusqu'à ce qu'il le soit.
- **Son** : respecter le réglage des effets sonores de `Sound` ; la musique de l'accueil commence après l'animation.
- **Vérification** : `tools/shots.gd` doit traverser l'écran sans erreur (sans écran, sauter l'animation).

## Images à préparer

1. **Image de démarrage sans logo.** `boot_splash/image` affiche aujourd'hui le logo : il apparaîtrait, disparaîtrait
   puis reviendrait. La remplacer par le fond seul (bleu nuit, poussière d'or), ou garder `bg_color` sans image.
2. **Logo en calques sur fond transparent**, à la taille de `assets/logo/logo.png` et parfaitement superposables :
   - `logo_livre.png` : la Bible ouverte seule, y compris la partie cachée derrière les lettres ;
   - `logo_enseigne.png` : l'enseigne en bois avec « Perfectionnement » et le ruban « Le duel des cartes bibliques ».

   L'aperçu a été fait en détourant `logo.png` à la volée : on y voit un petit raccord autour du livre pendant le
   rebond de l'enseigne. Les vrais calques le suppriment.

   Demande pour ChatGPT, dans la conversation qui a produit le logo :

   ```
   Sépare ce logo en deux images PNG sur fond transparent, au même format et parfaitement superposables :
   1. la Bible ouverte seule, complète (dessine aussi la partie cachée derrière les lettres) ;
   2. l'enseigne en bois avec le titre « Perfectionnement » et le ruban « Le duel des cartes bibliques », sans la Bible.
   Aucun fond, aucune étoile, aucune poussière : seulement l'objet, bords nets.
   ```

## Réalisation (2026-11-24)

- **Code** : `scripts/ui/splash.gd` (une seule horloge, mêmes courbes que la maquette), reflet
  `scripts/ui/splash_reflet.gdshader`. L'accueil (`main_menu.gd`) l'ajoute au démarrage à froid ; la
  musique attend la fin (`Sound.begin_intro` / `end_intro`).
- **Image de démarrage** : `assets/logo/demarrage.png` n'est plus que le fond (halo bleu, poussière d'or).
- **Calques** : les calques peints (fournis le 2026-11-24) sont gardés tels quels dans
  `assets/logo/source_livre.png` et `source_enseigne.png`. `tools/logo_calques.ps1` les pose sur une toile
  de la taille de `logo.png`, chacun à sa place dans ce logo (l'enseigne par une recherche automatique
  d'échelle et de décalage sur les lettres), et écrit `logo_livre.png` et `logo_enseigne.png`, lus par
  l'animation. « Perfectionnement » tombe exactement sur le titre peint de l'accueil ; le sous-titre de la
  nouvelle enseigne est un peu plus bas que celui de l'accueil, ce qui se voit à peine pendant le fondu final.- **Position finale** : le titre peint de l'accueil occupe `Rect2(84, 115, 784, 410)` en pixels de
  `assets/accueil/accueil.png` (`Splash.HOME_TITLE`), vérifié par superposition à 50 %.
- **Vérification** : `tools/shots.gd` capture l'animation (`00a` à `00c`) avant l'accueil ; sans écran,
  elle est sautée.
