# Build release, signé avec la clé de l'application. Appelé par release.cmd à la racine du projet.
#   .\release        build\perfectionnement.aab          (pour Google Play)
#   .\release apk    build\perfectionnement-release.apk  (à installer sur un téléphone pour tester)
#
# La clé et son mot de passe sont hors du dépôt : %USERPROFILE%\.android\perfectionnement-release.jks
# et perfectionnement-release.txt (créés le 2026-11-24). Sans eux, la signature de debug est utilisée
# et le build n'est pas publiable.
param([ValidateSet("aab", "apk")][string]$format = "aab")

Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force build | Out-Null

$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
$preset = if ($format -eq "aab") { "Android Play" } else { "Android" }
$out = if ($format -eq "aab") { "build\perfectionnement.aab" } else { "build\perfectionnement-release.apk" }

$key = "$env:USERPROFILE\.android\perfectionnement-release.jks"
$notes = "$env:USERPROFILE\.android\perfectionnement-release.txt"
if (-not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -and (Test-Path $key) -and (Test-Path $notes)) {
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $key
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "perfectionnement"
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = ((Get-Content $notes | Select-String "Mot de passe") -split ": ")[-1].Trim()
    Write-Host "Signature avec la clé release de l'application."
} elseif (-not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH) {
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = "$env:APPDATA\Godot\keystores\debug.keystore"
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "androiddebugkey"
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "android"
    Write-Host "Clé release introuvable : signature de debug (pas publiable)." -ForegroundColor Yellow
}

Write-Host "Export release ($format, 1 à 3 minutes)..."
Remove-Item $out -ErrorAction SilentlyContinue
$template = if (Test-Path "android/build") { @() } else { @("--install-android-build-template") }
# Comme pour deployer : le démon Gradle garde les sorties ouvertes, on écrit donc dans un fichier
# et on n'attend que Godot.
$log = "build\release.log"
$p = Start-Process $godot -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err" `
    -ArgumentList (@("--headless", "--path", ".") + $template + @("--export-release", "`"$preset`"", $out))
$p.WaitForExit()
Get-Content $log, "$log.err" -ErrorAction SilentlyContinue | Select-String "ERROR"

if (Test-Path $out) {
    Write-Host ("Prêt : {0} ({1} Mo)" -f (Resolve-Path $out), [int]((Get-Item $out).Length / 1MB)) -ForegroundColor Green
} else {
    Write-Host "Échec de l'export : voir $log et $log.err" -ForegroundColor Red
    exit 1
}
