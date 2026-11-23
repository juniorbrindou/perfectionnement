# Greffon Android « GoogleSignIn »

Connexion Google par le Credential Manager d'Android. Le jeu appelle
`Engine.get_singleton("GoogleSignIn").signIn(id_client_web)` et reçoit le signal
`sign_in_succeeded(jeton, email, nom)` ou `sign_in_failed(code, message)` (code `annule` ou `erreur`).
Le jeton part ensuite à Nakama (`scripts/online.gd`, `sign_in_google`).

## Recompiler (seulement si `GoogleSignInPlugin.java` change)

```powershell
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21.0.10"
cd android_plugin
gradle assembleRelease      # Gradle 9.1 ; local.properties pointe vers le SDK Android
Copy-Item build/outputs/aar/GoogleSignIn-release.aar ../addons/google_sign_in/bin/GoogleSignIn.aar
```

`addons/google_sign_in/plugin.gd` ajoute l'AAR et ses dépendances à l'APK. L'export Android utilise donc le
build Gradle (`gradle_build/use_gradle_build=true`) ; `tools/telephone.ps1` installe le modèle Android
(`android/`, non versionné) au premier export.
