# Versions publiées sur GitHub

Avant Google Play, le jeu se distribue par GitHub Releases, dans le dépôt public
**juniorbrindou/perfectionnement-releases** (sans code : les APK et leurs notes). Le dépôt du code peut
rester privé.

## Pour les joueurs

- **Lien à partager** (toujours la dernière version) :
  https://github.com/juniorbrindou/perfectionnement-releases/releases/latest/download/perfectionnement.apk
- **Toutes les versions et leurs nouveautés** :
  https://github.com/juniorbrindou/perfectionnement-releases/releases
- Android demande d'autoriser l'installation depuis le navigateur la première fois.
- **Dans le jeu** : au lancement, l'accueil interroge GitHub (`scripts/ui/update_notice.gd`). Si une
  version plus récente existe, une fenêtre « Nouvelle version » montre ses nouveautés et un bouton
  « Télécharger » ; la mise à jour s'installe par-dessus, progression gardée.

## Publier une version

1. Une fois pour toutes : `gh auth login` (GitHub CLI est installé).
2. Écrire les nouveautés dans `CHANGELOG.md`, sous `## 0.6.1`, pour les joueurs.
3. `.\publier 0.6.1` : met la version partout (nom 0.6.1, code 601), construit l'APK release, crée
   le dépôt des releases s'il n'existe pas, puis la release `v0.6.1` avec l'APK et les notes.
4. Commiter le changement de version (`project.godot`, `export_presets.cfg`).

Les numéros vont toujours croissant : le jeu compare la version de la release à la sienne.

## Signature

Toutes les versions sont signées avec la clé release (`docs/BETA.md`) : chaque mise à jour s'installe
par-dessus la précédente. Deux cas demandent de désinstaller une fois :

- un téléphone qui a la version de développement (installée par `.\deployer`, clé de debug) ;
- le passage à Google Play si Google y signe l'application avec sa propre clé (signature par Google
  Play) : prévenir les testeurs le moment venu.
