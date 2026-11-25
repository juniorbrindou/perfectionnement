# Étude : Flutter ou React Native pour Perfectionnement ?

2026-11-25. Question posée : le jeu serait-il mieux en Flutter ou en React (React Native), plutôt qu'en Godot ?
Le serveur (Nakama, module TypeScript) n'est pas en cause : il reste le même dans tous les cas.

## 1. Ce qu'il faudrait réécrire

Mesuré sur `master` :

| Partie | Taille | Remarque |
|---|---|---|
| Écrans (`scripts/ui`) | 20 fichiers, **8 100 lignes** | le gros du travail : duel en ligne (1 350), arcade (816), mode à deux, aventure, profil, salon, splash |
| Règles (`scripts/core`) | 13 fichiers, 590 lignes | duel, tirage, IA du Scribe : à réécrire, avec les scénarios communs `tests/scenarios` |
| Autoloads (connexion, son, session…) | 5 fichiers, 790 lignes | |
| Tests et outils | 680 lignes | `tests/`, `tools/shots.gd` |
| Effets | 2 shaders, des particules, des tweens | carte qui brûle (`feu_dore`), reflet du splash, étincelles |
| Natif | greffon Android Google (117 lignes Java) | disparaît avec Flutter ou React Native |
| Images et sons | 25 Mo | réutilisés tels quels |

Le jeu n'utilise **aucune 3D** : c'est une application 2D, faite d'écrans, de cartes animées et d'effets. Une
réécriture représente environ **10 000 lignes**, soit, à l'estimation, 4 à 6 semaines de travail de l'IA locale
avec vos validations. Pendant ce temps, rien de nouveau n'avance.

## 2. Comparaison

| Critère | Flutter | React Native (Expo) | Godot (actuel) |
|---|---|---|---|
| Adéquation au jeu (écrans + cartes animées) | très bonne : tout est dessiné par Flutter, comme un moteur de jeu | bonne, mais les effets passent par des bibliothèques ajoutées (Skia, Reanimated) | très bonne pour les effets, plus lourde pour les écrans |
| Effets (shaders, particules, animations) | shaders GLSL natifs (`FragmentProgram`), proches de ceux de Godot ; Impeller activé par défaut sur Android 10+ | shaders SkSL via `@shopify/react-native-skia`, animés avec Reanimated 4 (nouvelle architecture obligatoire) | natifs, les plus complets |
| Client Nakama | officiel : paquet `nakama` (Dart) de Heroic Labs | officiel : `@heroiclabs/nakama-js` | officiel (déjà en place) |
| Connexion Google | `google_sign_in` 7, gratuit, Credential Manager sur Android | le paquet de référence réserve Credential Manager à sa version **payante** (environ 79 à 249 $/an) ; alternatives gratuites moins établies | greffon Java maison à maintenir |
| Champs texte, clavier, listes, formulaires | natifs et soignés | natifs | faibles (module maison pour éviter le clavier) |
| Votre expérience | **ayFloat** : deux applications Flutter publiées, chaîne de build en place sur le serveur | **Rubix** : trois pannes propres à l'APK (three.js en CommonJS, R8 qui retirait expo-gl, pas de journaux) | le projet actuel |
| Build sur ce serveur | Flutter et le SDK Android déjà installés | possible (fait pour Rubix), plus fragile | Godot absent du serveur ; build sur votre PC |
| iOS et web plus tard | oui, un seul code | oui, un seul code | iOS oui ; web possible mais lourd |
| Taille de l'APK | comparable : les 25 Mo d'images dominent dans les trois cas | comparable | comparable |

## 3. Flutter contre React Native

**Flutter l'emporte pour ce projet**, pour quatre raisons :

1. **Il dessine tout lui-même**, comme un moteur de jeu. Les cartes, les cadres dorés, la lampe du minuteur, le
   feu qui brûle une carte s'écrivent directement (`CustomPainter`, shaders GLSL), sans pile de bibliothèques.
2. **La connexion Google est gratuite et à jour** (Credential Manager), alors qu'en React Native la voie
   recommandée est payante.
3. **Vous le connaissez et il tourne déjà sur ce serveur** (ayFloat), alors que l'expérience React Native de Rubix
   a coûté trois pannes invisibles en développement.
4. **Le client Nakama Dart est officiel**, comme celui de JavaScript : pas d'écart sur ce point.

React Native ne gagnerait que si l'équipe était surtout faite de développeurs web (React).

## 4. Bilan

- **Entre Flutter et React Native : Flutter.**
- **Mais pas maintenant.** Le jeu fonctionne en Godot, et la réécriture coûterait 4 à 6 semaines sans rien ajouter
  au joueur. Ce qui déplaisait jusqu'ici (des écrans pas assez beaux) tient aux images peintes, pas au moteur :
  Flutter ne les rendrait pas plus belles.
- **Les signaux qui justifieraient de passer à Flutter :**
  - les salons (0.4) et la modération multiplient les formulaires, les listes et la saisie, là où Godot est le plus
    faible ;
  - une version **web** devient nécessaire, ou iOS doit sortir vite ;
  - le greffon Google ou la saisie au clavier causent de nouvelles pannes.
- **Si l'un de ces signaux arrive**, migrer en une fois, écran par écran, sur une branche, avec le même serveur
  et les mêmes images, et rejouer les scénarios `tests/scenarios` côté Dart pour garder les mêmes règles.

## Sources

- [Bibliothèques clientes Nakama](https://heroiclabs.com/docs/nakama/client-libraries/), [client Dart](https://heroiclabs.com/docs/nakama/client-libraries/dart/), [paquet `nakama` sur pub.dev](https://pub.dev/packages/nakama), [nakama-js](https://github.com/heroiclabs/nakama-js)
- [Flutter : shaders de fragment](https://docs.flutter.dev/ui/design/graphics/fragment-shaders), [Impeller](https://docs.flutter.dev/perf/impeller)
- [React Native Skia : shaders](https://shopify.github.io/react-native-skia/docs/shaders/overview), [Skia dans Expo](https://docs.expo.dev/versions/latest/sdk/skia), [Reanimated 4](https://unpkg.com/react-native-reanimated@4.3.0/README.md)
- [google_sign_in (Android)](https://pub.dev/documentation/google_sign_in_android/latest/), [Credential Manager](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation)
- [react-native-google-signin : installation](https://react-native-google-signin.github.io/docs/install), [Universal Sign In](https://react-native-google-signin.github.io/docs/one-tap), [authentification Google dans Expo](https://docs.expo.dev/guides/google-authentication/)
- [Taille d'une application Flutter](https://docs.flutter.dev/perf/app-size), [taille d'une application Expo](https://docs.expo.dev/distribution/app-size/)
