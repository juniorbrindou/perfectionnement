# Fabrique l'icône de l'application d'après le logo (assets\logo\logo.png, fourni le 2026-11-24) :
# le livre ouvert du logo, et devant lui un grand « P » crème cerclé de brun dans le même style
# que « Perfectionnement », sur le bleu nuit semé d'or.
#   assets\icone\icone_512.png          icône complète (magasin, réglages)
#   assets\icone\icone_192.png          icône Android classique
#   assets\icone\avant_plan_432.png     icône adaptative Android : avant-plan (livre et P)
#   assets\icone\arriere_plan_432.png   icône adaptative Android : arrière-plan (fond étoilé)
# Usage, depuis la racine du dépôt : pwsh -File tools/icone.ps1
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root "assets\icone"
New-Item -ItemType Directory -Force $out | Out-Null
$logo = [System.Drawing.Bitmap]::FromFile("$root\assets\logo\logo.png")
$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile("$root\assets\fonts\LilitaOne-Regular.ttf")
$rnd = [System.Random]::new(4)

function Col([string]$hex, [int]$a = 255) { $v = [Convert]::ToInt32($hex, 16); [System.Drawing.Color]::FromArgb($a, ($v -shr 16) -band 255, ($v -shr 8) -band 255, $v -band 255) }
function RR([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90); $p.CloseFigure(); $p
}
function Gfx($bmp) { $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = "AntiAlias"; $g.InterpolationMode = "HighQualityBicubic"; $g.PixelOffsetMode = "HighQuality"; $g.TextRenderingHint = "AntiAlias"; $g }

# Fond bleu nuit, poussière d'or et lueur derrière le livre.
function Background([int]$S, [float]$glowY) {
    $b = New-Object System.Drawing.Bitmap $S, $S; $g = Gfx $b
    $rect = New-Object System.Drawing.Drawing2D.GraphicsPath; $rect.AddRectangle((New-Object System.Drawing.Rectangle 0, 0, $S, $S))
    $bg = New-Object System.Drawing.Drawing2D.PathGradientBrush($rect)
    $bg.CenterPoint = New-Object System.Drawing.PointF ($S / 2), $glowY
    $bg.CenterColor = Col "24479c"; $bg.SurroundColors = @((Col "0a1534"))
    $g.FillRectangle($bg, 0, 0, $S, $S)
    for ($k = 12; $k -ge 1; $k--) { $r = $k * $S / 30; $g.FillEllipse((New-Object System.Drawing.SolidBrush (Col "ffd76a" ([int](40 / $k)))), $S / 2 - $r, $glowY - $r, 2 * $r, 2 * $r) }
    for ($i = 0; $i -lt [int]($S / 3); $i++) {
        $x = $rnd.NextDouble() * $S; $y = $rnd.NextDouble() * $S; $r = 0.4 + $rnd.NextDouble() * $S / 300
        $g.FillEllipse((New-Object System.Drawing.SolidBrush (Col "ffd27a" (60 + $rnd.Next(150)))), $x - $r, $y - $r, 2 * $r, 2 * $r)
    }
    $g.Dispose(); return $b
}

# Livre et « P » sur fond transparent, dans un carré de côté S.
function Emblem([int]$S) {
    $b = New-Object System.Drawing.Bitmap $S, $S; $g = Gfx $b; $g.Clear([System.Drawing.Color]::Transparent)
    # Le livre : la partie visible au-dessus du titre du logo, bas fondu (le P le recouvre).
    $src = New-Object System.Drawing.Rectangle 690, 168, 760, 196
    $w = [int]($S * 0.92); $h = [int]($w * $src.Height / $src.Width)
    $book = New-Object System.Drawing.Bitmap $w, $h; $bg = Gfx $book
    $bg.DrawImage($logo, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), $src, "Pixel"); $bg.Dispose()
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
        $ax = [math]::Min(1.0, [math]::Min($x, $w - 1 - $x) / ($w * 0.08)); $ay = [math]::Min(1.0, ($h - 1 - $y) / ($h * 0.35)); $at = [math]::Min(1.0, $y / ($h * 0.06))
        # Le ciel du logo est sombre, le livre clair : on garde le clair, le fond rejoint le nôtre.
        $c = $book.GetPixel($x, $y); $lum = [math]::Max($c.R, [math]::Max($c.G, $c.B))
        $al = [math]::Min(1.0, [math]::Max(0.0, ($lum - 55) / 70.0))
        $a = $ax * $ay * $at * $al
        if ($a -lt 1.0) { $book.SetPixel($x, $y, [System.Drawing.Color]::FromArgb([int]($c.A * $a), $c.R, $c.G, $c.B)) }
    } }
    $g.DrawImage($book, [int](($S - $w) / 2), [int]($S * 0.14))
    # Le « P » : contour brun épais, ombre, remplissage crème, comme le titre du logo.
    $fs = $S * 0.66
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = "Center"
    $path.AddString("P", $fonts.Families[0], 0, $fs, (New-Object System.Drawing.PointF ($S / 2), ($S * 0.26)), $fmt)
    $shadow = $path.Clone(); $m = New-Object System.Drawing.Drawing2D.Matrix; $m.Translate(0, $S * 0.025); $shadow.Transform($m)
    $round = [System.Drawing.Drawing2D.LineJoin]::Round
    $p1 = New-Object System.Drawing.Pen((Col "1c0d04" 150), ($S * 0.1)); $p1.LineJoin = $round; $g.DrawPath($p1, $shadow)
    $p2 = New-Object System.Drawing.Pen((Col "5a2e10"), ($S * 0.085)); $p2.LineJoin = $round; $g.DrawPath($p2, $path)
    $p3 = New-Object System.Drawing.Pen((Col "7d4419"), ($S * 0.03)); $p3.LineJoin = $round; $g.DrawPath($p3, $path)
    $fill = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.PointF 0, ($S * 0.3)), (New-Object System.Drawing.PointF 0, ($S * 0.9)), (Col "fffaea"), (Col "efd9a6"))
    $g.FillPath($fill, $path)
    $g.Dispose(); return $b
}

# Icône complète 512 : fond, emblème, cadre doré arrondi, coins transparents.
$S = 512
$full = Background $S ($S * 0.32)
$g = Gfx $full
$g.DrawImage((Emblem $S), 0, 0)
$mask = New-Object System.Drawing.Bitmap $S, $S; $mg = Gfx $mask; $mg.Clear([System.Drawing.Color]::Transparent); $mg.FillPath([System.Drawing.Brushes]::White, (RR 0 0 $S $S 112)); $mg.Dispose()
for ($y = 0; $y -lt $S; $y++) { for ($x = 0; $x -lt $S; $x++) { $a = $mask.GetPixel($x, $y).A; if ($a -lt 255) { $c = $full.GetPixel($x, $y); $full.SetPixel($x, $y, [System.Drawing.Color]::FromArgb([int]($c.A * $a / 255), $c.R, $c.G, $c.B)) } } }
$g.DrawPath((New-Object System.Drawing.Pen((Col "f0c05a"), 16)), (RR 8 8 ($S - 16) ($S - 16) 104))
$g.DrawPath((New-Object System.Drawing.Pen((Col "fff0b8" 170), 4)), (RR 20 20 ($S - 40) ($S - 40) 94))
$g.Dispose()
$full.Save("$out\icone_512.png", [System.Drawing.Imaging.ImageFormat]::Png)
$small = New-Object System.Drawing.Bitmap 192, 192; $sg = Gfx $small; $sg.DrawImage($full, 0, 0, 192, 192); $sg.Dispose()
$small.Save("$out\icone_192.png", [System.Drawing.Imaging.ImageFormat]::Png)

# Icône adaptative 432 : Android découpe la forme ; l'emblème tient dans les 66 % du centre.
(Background 432 (432 * 0.36)).Save("$out\arriere_plan_432.png", [System.Drawing.Imaging.ImageFormat]::Png)
$front = New-Object System.Drawing.Bitmap 432, 432; $fg = Gfx $front; $fg.Clear([System.Drawing.Color]::Transparent)
$fg.DrawImage((Emblem 290), 71, 71); $fg.Dispose()
$front.Save("$out\avant_plan_432.png", [System.Drawing.Imaging.ImageFormat]::Png)
"Icônes écrites dans $out"
