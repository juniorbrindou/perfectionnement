# Bêta fermée sur Google Play (0.6)

## Déjà prêt

- **Version** : 0.6.0, code de version 600 (`export_presets.cfg`, `project.godot`). `.\publier` les met à
  jour (nom 0.6.1 → code 601) : le code augmente à chaque version, comme Google Play l'exige.
- **Clé de signature** : `%USERPROFILE%\.android\perfectionnement-release.jks`, alias `perfectionnement`,
  mot de passe dans `perfectionnement-release.txt` à côté (créés le 2026-11-24, hors du dépôt). **À
  sauvegarder hors de ce PC** : sans elle, plus aucune mise à jour possible.
  - SHA-1 : `57:96:85:33:0C:38:2A:E5:91:4F:5A:D5:0F:50:8E:B6:ED:09:DA:60`
  - SHA-256 : `60:B3:4D:44:9D:CC:6B:CB:55:A0:5B:AE:C9:E5:24:0B:32:37:07:63:CA:56:40:1A:16:D9:81:24:F5:44:2D:EA`
- **Build** : `.\release` produit `build\perfectionnement.aab` (format demandé par Google Play), signé
  avec cette clé ; `.\release apk` produit un APK release à installer pour tester.

## À faire par le porteur du projet

1. **Compte Google Play Console** (25 $ une fois) : https://play.google.com/console
2. **Créer l'application** : nom « Perfectionnement », jeu, gratuit.
3. **Signature par Google Play** (proposée à la création) : accepter. Google garde la clé de
   distribution ; `perfectionnement-release.jks` devient la clé d'importation.
4. **Connexion Google dans le jeu** : dans Google Cloud (projet de l'identifiant OAuth), ajouter des
   identifiants OAuth « Android » pour `com.juniorbrindou.perfectionnement` avec le SHA-1 de la clé
   d'importation ci-dessus **et** le SHA-1 de la clé de signature d'application affiché par Play
   Console (Intégrité de l'application). Sans cela, « Continuer avec Google » échoue sur les versions
   installées depuis le Play Store.
5. **Fiche et contenu** : description, captures d'écran (`tools/shots.gd` en produit), icône 512 px
   (`assets/icone/icone_512.png`), bannière 1024 × 500, règles de confidentialité (une page web
   publique : le jeu enregistre pseudo, e-mail éventuel, talents et progression sur le serveur),
   section « Sécurité des données », classification du contenu, public cible.
6. **Test fermé** : créer une piste de test fermé, y ajouter les adresses e-mail des testeurs,
   importer `build\perfectionnement.aab`, envoyer en examen.

## Taille

L'AAB fait environ 69 Mo ; Google Play n'envoie à chaque téléphone que la partie pour son processeur
(environ 30 Mo à télécharger). Le moteur Godot en représente l'essentiel.
