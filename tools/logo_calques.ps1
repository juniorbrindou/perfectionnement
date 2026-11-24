# Calques du logo pour l'animation de démarrage (docs/SPLASH.md), à partir des deux calques peints
# (fond transparent) fournis le 2026-11-24 :
#   assets\logo\source_livre.png      la Bible seule
#   assets\logo\source_enseigne.png   l'enseigne « Perfectionnement » et son ruban
# Ils sont posés sur une toile de la taille de assets\logo\logo.png, chacun à la place qu'il occupe
# dans ce logo (donc aussi sur le titre peint de l'accueil, où l'animation se termine) :
#   assets\logo\logo_livre.png, assets\logo\logo_enseigne.png   (lus par scripts/ui/splash.gd)
# Il écrit aussi assets\logo\demarrage.png, l'image de démarrage d'Android : le fond seul.
# Usage, depuis la racine du dépôt : pwsh -File tools/logo_calques.ps1
Add-Type -AssemblyName System.Drawing
$dir = Join-Path (Split-Path $PSScriptRoot -Parent) "assets\logo"
$ref = [System.Drawing.Image]::FromFile("$dir\logo.png")
$W = $ref.Width; $H = $ref.Height; $ref.Dispose()

## Pose un calque : la partie peinte `content` (pixels de la source) va dans `target` (pixels du logo).
function Place([string]$source, [string]$name, [System.Drawing.RectangleF]$content, [System.Drawing.RectangleF]$target) {
    $src = [System.Drawing.Image]::FromFile("$dir\$source")
    $k = $target.Width / $content.Width
    $bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = "HighQualityBicubic"; $g.PixelOffsetMode = "HighQuality"; $g.Clear([System.Drawing.Color]::Transparent)
    $x = $target.X - $content.X * $k; $y = $target.Y - $content.Y * $k
    $g.DrawImage($src, [single]$x, [single]$y, [single]($src.Width * $k), [single]($src.Height * $k))
    $g.Dispose(); $src.Dispose()
    $bmp.Save("$dir\$name", [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    "$name écrit"
}

# Parties peintes mesurées dans les sources, et leur place dans logo.png (largeur imposée, la hauteur suit).
Place "source_livre.png" "logo_livre.png" (New-Object System.Drawing.RectangleF 93, 29, 1232, 427) (New-Object System.Drawing.RectangleF 686, 178, 782, 271)
# Enseigne : échelle et décalage cherchés automatiquement (lettres crème de la source sur celles du logo).
Place "source_enseigne.png" "logo_enseigne.png" (New-Object System.Drawing.RectangleF 0, 0, 1902, 485) (New-Object System.Drawing.RectangleF 60, 328, 1985.7, 506)

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
