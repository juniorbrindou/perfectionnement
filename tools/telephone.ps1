# Test sur un téléphone Android (débogage sans fil). Appelé par les fichiers .cmd
# à la racine du projet : deployer, logs, capture.
# L'adresse du téléphone (ex. 192.168.1.2:45917) est demandée une fois puis retenue
# dans build\telephone.txt. Pour la changer : deployer 192.168.1.2:41234
param(
    [Parameter(Mandatory = $true)][ValidateSet("deploy", "logs", "capture")][string]$action,
    [string]$device
)

Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force build | Out-Null

$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\godot_console.exe"
$godotExe = Join-Path (Split-Path $godot) "Godot_v4.7.2-stable_win64.exe"
$adb = "D:\flutter-android-sdk\Sdk\platform-tools\adb.exe"
$package = "com.juniorbrindou.perfectionnement"
$apk = "build\perfectionnement-debug.apk"
$saved = "build\telephone.txt"

function Connect-Phone {
    # Un téléphone déjà vu par adb (reconnexion automatique du débogage sans fil) sert tel quel :
    # se connecter à une adresse périmée peut bloquer de longues minutes.
    for ($i = 0; $i -lt 20; $i++) {  # Après l'export, adb redémarre et retrouve le téléphone en quelques secondes.
        $listed = @(& $adb devices | Select-String "\tdevice$" | ForEach-Object { ("$_" -split "\t")[0] })
        if ($listed.Count -gt 0) { break }
        Start-Sleep 1
    }
    if ($listed.Count -gt 0) {
        if (-not ($script:device -and $listed -contains $script:device)) { $script:device = $listed[0] }
        return
    }
    if (-not $script:device -and (Test-Path $saved)) { $script:device = (Get-Content $saved -Raw).Trim() }
    if (-not $script:device) {
        $script:device = Read-Host "Adresse du téléphone (Paramètres > Options de développement > Débogage sans fil, ex. 192.168.1.2:45917)"
    }
    $job = Start-Job { param($a, $d) & $a connect $d 2>&1 } -ArgumentList $adb, $script:device
    $out = if (Wait-Job $job -Timeout 15) { Receive-Job $job } else { Stop-Job $job; "pas de réponse en 15 s" }
    if ("$out" -notmatch "connected") {
        Write-Host "Connexion impossible à $script:device : $out" -ForegroundColor Red
        Write-Host "L'adresse change à chaque activation du débogage sans fil. Relance avec la nouvelle, ex. : deployer 192.168.1.2:41234"
        Remove-Item $saved -ErrorAction SilentlyContinue
        exit 1
    }
    Set-Content $saved $script:device
}

switch ($action) {
    "deploy" {
        Write-Host "1/3 Export de l'APK (1 à 3 minutes)..."
        # Build Gradle (greffon Google) : le modèle Android est installé au premier export.
        $template = if (Test-Path "android/build") { @() } else { @("--install-android-build-template") }
        # Le démon Gradle hérite des sorties de Godot et reste en vie après l'export : si on lisait
        # ces sorties par un tuyau, on attendrait sans fin. On les écrit dans un fichier et on
        # n'attend que Godot lui-même.
        $log = "build\export.log"
        $p = Start-Process $godotExe -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err" `
            -ArgumentList (@("--headless", "--path", ".") + $template + @("--export-debug", "Android", $apk))
        $p.WaitForExit()
        Get-Content $log, "$log.err" -ErrorAction SilentlyContinue | Select-String "ERROR"
        # L'export redémarre adb : on se connecte ensuite.
        Write-Host "2/3 Installation sur le téléphone..."
        Connect-Phone
        & $adb -s $device install -r $apk | Select-Object -Last 1
        Write-Host "3/3 Lancement du jeu."
        & $adb -s $device shell am force-stop $package
        & $adb -s $device shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
    }
    "logs" {
        Connect-Phone
        Write-Host "Journal du jeu (Ctrl+C pour arrêter)..."
        & $adb -s $device logcat -c
        & $adb -s $device logcat -s godot:*
    }
    "capture" {
        Connect-Phone
        New-Item -ItemType Directory -Force build\captures | Out-Null
        $file = "build\captures\capture-$(Get-Date -Format 'yyyyMMdd-HHmmss').png"
        & $adb -s $device shell screencap -p /sdcard/perf_capture.png
        & $adb -s $device pull /sdcard/perf_capture.png $file | Out-Null
        & $adb -s $device shell rm /sdcard/perf_capture.png
        Write-Host "Capture enregistrée : $file"
    }
}
