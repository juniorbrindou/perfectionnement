# Calques provisoires du logo pour l'animation de démarrage (docs/SPLASH.md), et image de
# démarrage sans logo. Le logo (assets\logo\logo.png) est peint sur un ciel bleu nuit : on rend ce
# ciel transparent (pixels sombres et bleus, même règle que docs/maquettes/splash.html), puis on
# découpe deux calques de la taille du logo, parfaitement superposables :
#   assets\logo\logo_livre.png      la Bible (derrière)
#   assets\logo\logo_enseigne.png   l'enseigne « Perfectionnement » et son ruban (devant)
#   assets\logo\demarrage.png       l'image de démarrage d'Android : le fond seul
# Quand les vrais calques de ChatGPT arrivent, il suffit de remplacer les deux PNG : ne relance
# alors plus ce script, il les écraserait.
# Usage, depuis la racine du dépôt : pwsh -File tools/logo_calques.ps1
Add-Type -AssemblyName System.Drawing
$dir = Join-Path (Split-Path $PSScriptRoot -Parent) "assets\logo"
$src = [System.Drawing.Bitmap]::FromFile("$dir\logo.png")
$W = $src.Width; $H = $src.Height
$rect = New-Object System.Drawing.Rectangle 0, 0, $W, $H
$fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
$data = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
$pixels = [byte[]]::new($data.Stride * $H)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $pixels, 0, $pixels.Length)
$stride = $data.Stride
$src.UnlockBits($data); $src.Dispose()

# Transparence du ciel, calculée une fois (octets BGRA).
$alpha = [byte[]]::new($W * $H)
for ($y = 0; $y -lt $H; $y++) {
    $row = $y * $stride
    for ($x = 0; $x -lt $W; $x++) {
        $i = $row + $x * 4
        $b = $pixels[$i]; $g = $pixels[$i + 1]; $r = $pixels[$i + 2]
        $lum = 0.3 * $r + 0.59 * $g + 0.11 * $b
        $blue = $b - $r
        $a = 1.0
        if ($blue -gt 0) { $a = [math]::Min(1.0, [math]::Max(0.0, ($lum - 70) / 70)) }
        if ($blue -gt 25 -and $lum -lt 120) { $a = 0.0 }
        $alpha[$y * $W + $x] = [byte][math]::Round($a * $pixels[$i + 3])
    }
}

function Layer([string]$name, [scriptblock]$keep) {
    $out = [byte[]]::new($pixels.Length)
    [Array]::Copy($pixels, $out, $pixels.Length)
    for ($y = 0; $y -lt $H; $y++) {
        $fy = $y / $H; $row = $y * $stride
        for ($x = 0; $x -lt $W; $x++) {
            $i = $row + $x * 4
            $out[$i + 3] = if (& $keep ($x / $W) $fy) { $alpha[$y * $W + $x] } else { 0 }
        }
    }
    $bmp = New-Object System.Drawing.Bitmap $W, $H, $fmt
    $d = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $fmt)
    [System.Runtime.InteropServices.Marshal]::Copy($out, 0, $d.Scan0, $out.Length)
    $bmp.UnlockBits($d)
    $bmp.Save("$dir\$name", [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    "$name écrit"
}

# Découpes de l'aperçu validé : livre = inset(15% 29% 59% 31.5%), arrêté à 33 % de la hauteur au lieu
# de 41 % pour ne pas emporter le haut des lettres (l'enseigne recouvre ce bas du livre) ;
# enseigne = tout sauf l'encoche du livre.
Layer "logo_livre.png" { param($fx, $fy) $fx -ge 0.315 -and $fx -le 0.71 -and $fy -ge 0.15 -and $fy -le 0.33 }
Layer "logo_enseigne.png" { param($fx, $fy) -not ($fx -ge 0.315 -and $fx -le 0.71 -and $fy -lt 0.325) }

# Image de démarrage : le fond de l'animation seul (halo bleu, poussière d'or), sans logo.
$SW = 1080; $SH = 1920
$bmp = New-Object System.Drawing.Bitmap $SW, $SH
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = "AntiAlias"
$g.Clear([System.Drawing.Color]::FromArgb(255, 3, 16, 42))
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddEllipse(-[int]($SW * 0.7), [int]($SH * 0.46 - $SH * 0.6), [int]($SW * 2.4), [int]($SH * 1.2))
$br = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
$br.CenterPoint = New-Object System.Drawing.PointF ($SW / 2), ($SH * 0.46)
$blend = New-Object System.Drawing.Drawing2D.ColorBlend 4
$blend.Colors = @([System.Drawing.Color]::FromArgb(255, 3, 16, 42), [System.Drawing.Color]::FromArgb(255, 3, 16, 42), [System.Drawing.Color]::FromArgb(255, 7, 27, 72), [System.Drawing.Color]::FromArgb(255, 13, 42, 107))
$blend.Positions = @([single]0, [single]0.25, [single]0.6, [single]1)
$br.InterpolationColors = $blend
$g.FillPath($br, $path)
$rnd = [System.Random]::new(7)
for ($k = 0; $k -lt 70; $k++) {
    $s = 2 + $rnd.NextDouble() * 5; $x = $rnd.NextDouble() * $SW; $y = 280 + $rnd.NextDouble() * 1340
    $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70 + $rnd.Next(80), 255, 215, 122))), $x - $s, $y - $s, 2 * $s, 2 * $s)
}
$g.Dispose()
$bmp.Save("$dir\demarrage.png", [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
"demarrage.png écrit"
