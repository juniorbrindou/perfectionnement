# Fabrique l'icône de l'application : le logo entier (la Bible et l'enseigne détourées,
# assets\logo\logo_livre.png et logo_enseigne.png) sur fond blanc (demandes du 2026-11-24 : garder le
# logo, fond blanc).
#   assets\icone\icone_512.png          icône complète (magasin, réglages), coins arrondis et cadre doré
#   assets\icone\icone_192.png          icône Android classique
#   assets\icone\avant_plan_432.png     icône adaptative Android : le logo (dans la zone toujours visible)
#   assets\icone\arriere_plan_432.png   icône adaptative Android : le fond
# Usage, depuis la racine du dépôt : pwsh -File tools/icone.ps1
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root "assets\icone"
New-Item -ItemType Directory -Force $out | Out-Null
# Le logo sans son ciel : les deux calques superposés.
$livre = [System.Drawing.Image]::FromFile("$root\assets\logo\logo_livre.png")
$logo = New-Object System.Drawing.Bitmap $livre.Width, $livre.Height
$lg = [System.Drawing.Graphics]::FromImage($logo); $lg.DrawImage($livre, 0, 0, $livre.Width, $livre.Height)
$ens = [System.Drawing.Image]::FromFile("$root\assets\logo\logo_enseigne.png"); $lg.DrawImage($ens, 0, 0, $livre.Width, $livre.Height); $lg.Dispose()
$rnd = [System.Random]::new(4)

function Col([string]$hex, [int]$a = 255) { $v = [Convert]::ToInt32($hex, 16); [System.Drawing.Color]::FromArgb($a, ($v -shr 16) -band 255, ($v -shr 8) -band 255, $v -band 255) }
function RR([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90); $p.CloseFigure(); $p
}
function Gfx($bmp) { $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = "AntiAlias"; $g.InterpolationMode = "HighQualityBicubic"; $g.PixelOffsetMode = "HighQuality"; $g }

# Fond blanc.
function Background([int]$S) {
    $b = New-Object System.Drawing.Bitmap $S, $S; $g = Gfx $b; $g.Clear([System.Drawing.Color]::White); $g.Dispose(); return $b
}

# Le logo (transparent) réduit à la largeur w.
function Logo([int]$w) {
    $h = [int]($w * $logo.Height / $logo.Width)
    $b = New-Object System.Drawing.Bitmap $w, $h; $g = Gfx $b; $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($logo, 0, 0, $w, $h); $g.Dispose()
    return $b
}
# Icône complète 512 : fond, logo sur toute la largeur utile, cadre doré arrondi, coins transparents.
$S = 512
$full = Background $S
$g = Gfx $full
$l = Logo 470
$g.DrawImage($l, [int](($S - $l.Width) / 2), [int](($S - $l.Height) / 2))
$mask = New-Object System.Drawing.Bitmap $S, $S; $mg = Gfx $mask; $mg.Clear([System.Drawing.Color]::Transparent); $mg.FillPath([System.Drawing.Brushes]::White, (RR 0 0 $S $S 112)); $mg.Dispose()
for ($y = 0; $y -lt $S; $y++) { for ($x = 0; $x -lt $S; $x++) { $a = $mask.GetPixel($x, $y).A; if ($a -lt 255) { $c = $full.GetPixel($x, $y); $full.SetPixel($x, $y, [System.Drawing.Color]::FromArgb([int]($c.A * $a / 255), $c.R, $c.G, $c.B)) } } }
$g.DrawPath((New-Object System.Drawing.Pen((Col "f0c05a"), 16)), (RR 8 8 ($S - 16) ($S - 16) 104))
$g.DrawPath((New-Object System.Drawing.Pen((Col "fff0b8" 170), 4)), (RR 20 20 ($S - 40) ($S - 40) 94))
$g.Dispose()
$full.Save("$out\icone_512.png", [System.Drawing.Imaging.ImageFormat]::Png)
$small = New-Object System.Drawing.Bitmap 192, 192; $sg = Gfx $small; $sg.DrawImage($full, 0, 0, 192, 192); $sg.Dispose()
$small.Save("$out\icone_192.png", [System.Drawing.Imaging.ImageFormat]::Png)

# Icône adaptative 432 : Android découpe la forme et ne montre que les 2/3 du centre ; le logo tient
# dans cette zone, même découpée en rond.
(Background 432).Save("$out\arriere_plan_432.png", [System.Drawing.Imaging.ImageFormat]::Png)
$front = New-Object System.Drawing.Bitmap 432, 432; $fg = Gfx $front; $fg.Clear([System.Drawing.Color]::Transparent)
$l2 = Logo 260  # Le rond visible fait 288 px de diamètre : les bouts du titre restent dedans.
$fg.DrawImage($l2, [int]((432 - $l2.Width) / 2), [int]((432 - $l2.Height) / 2)); $fg.Dispose()
$front.Save("$out\avant_plan_432.png", [System.Drawing.Imaging.ImageFormat]::Png)
"Icônes écrites dans $out"
