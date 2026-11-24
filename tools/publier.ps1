# Publie une version du jeu sur GitHub (docs/RELEASES.md) : met le numéro de version partout,
# construit l'APK release signé, puis crée la release dans le dépôt public des releases avec les
# notes de CHANGELOG.md. Les joueurs la voient au prochain lancement (fenêtre « Nouvelle version »).
#   .\publier 0.6.1
# Il faut une section « ## 0.6.1 » dans CHANGELOG.md, et GitHub CLI connecté (gh auth login).
param([Parameter(Mandatory = $true)][string]$version)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$repo = "juniorbrindou/perfectionnement-releases"
$gh = "C:\Program Files\GitHub CLI\gh.exe"
if (-not ($version -match '^\d+\.\d+\.\d+$')) { throw "Version attendue sous la forme 0.6.1, reçu : $version" }

# 1. Notes de version : la section « ## <version> » du changelog.
$log = Get-Content CHANGELOG.md -Raw -Encoding utf8
$m = [regex]::Match($log, "(?ms)^## $([regex]::Escape($version))[^\n]*\n(.*?)(?=^## |\z)")
if (-not $m.Success -or -not $m.Groups[1].Value.Trim()) { throw "Ajoute d'abord une section « ## $version » à CHANGELOG.md." }
$notes = $m.Groups[1].Value.Trim()

# 2. Numéro de version : nom 0.6.1, code 601 (toujours croissant, Google Play l'exige aussi).
$parts = $version.Split(".") | ForEach-Object { [int]$_ }
$code = $parts[0] * 10000 + $parts[1] * 100 + $parts[2]
$p = Get-Content project.godot -Raw
$p = [regex]::Replace($p, 'config/version="[^"]*"', "config/version=`"$version`"")
Set-Content project.godot $p -NoNewline
$e = Get-Content export_presets.cfg -Raw
$e = [regex]::Replace($e, 'version/name="[^"]*"', "version/name=`"$version`"")
$e = [regex]::Replace($e, 'version/code=\d+', "version/code=$code")
Set-Content export_presets.cfg $e -NoNewline
Write-Host "Version $version (code $code)."

# 3. APK release signé (même clé à chaque fois : la mise à jour s'installe par-dessus).
& pwsh -NoProfile -File tools/release.ps1 apk
if ($LASTEXITCODE -ne 0) { throw "Le build a échoué." }
Copy-Item build\perfectionnement-release.apk build\perfectionnement.apk -Force

# 4. Le dépôt des releases (créé la première fois), puis la release.
& $gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "GitHub CLI n'est pas connecté : lance « gh auth login » une fois." }
& $gh repo view $repo 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    & $gh repo create $repo --public --description "Perfectionnement, le duel des cartes bibliques : téléchargements" --add-readme
}
$notesFile = "build\notes-$version.md"
Set-Content $notesFile $notes -Encoding utf8
& $gh release create "v$version" build\perfectionnement.apk --repo $repo --title "Perfectionnement $version" --notes-file $notesFile
if ($LASTEXITCODE -ne 0) { throw "La release n'a pas pu être créée." }

Write-Host ""
Write-Host "Publié. Lien à partager (toujours la dernière version) :" -ForegroundColor Green
Write-Host "  https://github.com/$repo/releases/latest/download/perfectionnement.apk"
Write-Host "Page des versions : https://github.com/$repo/releases"
Write-Host "Pense à commiter le changement de version (project.godot, export_presets.cfg)."
