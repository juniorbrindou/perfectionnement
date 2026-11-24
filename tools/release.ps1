# Build release de l'APK (optimisé, sans outils de débogage), dans build\perfectionnement-release.apk.
# Appelé par release.cmd à la racine du projet.
#
# Signature : avec la clé de debug de Godot, faute de clé release (choix du 2026-11-24). L'APK
# s'installe pour tester mais n'est pas publiable sur le Play Store. Pour une vraie clé, définir
# GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER et _PASSWORD avant de lancer : elles sont respectées.

Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force build | Out-Null

$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
$apk = "build\perfectionnement-release.apk"

if (-not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH) {
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = "$env:APPDATA\Godot\keystores\debug.keystore"
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "androiddebugkey"
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "android"
    Write-Host "Signature avec la clé de debug (APK de test, pas pour le Play Store)."
}

Write-Host "Export release de l'APK (1 à 3 minutes)..."
Remove-Item $apk -ErrorAction SilentlyContinue
$template = if (Test-Path "android/build") { @() } else { @("--install-android-build-template") }
# Comme pour deployer : le démon Gradle garde les sorties ouvertes, on écrit donc dans un fichier
# et on n'attend que Godot.
$log = "build\release.log"
$p = Start-Process $godot -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err" `
    -ArgumentList (@("--headless", "--path", ".") + $template + @("--export-release", "Android", $apk))
$p.WaitForExit()
Get-Content $log, "$log.err" -ErrorAction SilentlyContinue | Select-String "ERROR"

if (Test-Path $apk) {
    Write-Host ("APK release prêt : {0} ({1} Mo)" -f (Resolve-Path $apk), [int]((Get-Item $apk).Length / 1MB)) -ForegroundColor Green
} else {
    Write-Host "Échec de l'export : voir $log et $log.err" -ForegroundColor Red
    exit 1
}
