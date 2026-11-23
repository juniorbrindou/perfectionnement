# Prépare l'écran Aventure à partir de la maquette peinte : efface les textes et pièces qui
# changent (numéros, étoiles, « Niveau 1 ») et découpe la pièce, la pierre et l'étoile.
param([string]$src)
Add-Type -AssemblyName System.Drawing
$orig = [System.Drawing.Bitmap]::new($src)
$img = [System.Drawing.Bitmap]::new($orig)
$dir = "assets\aventure"

function Lerp([double]$a, [double]$b, [double]$t) { [int][Math]::Round($a + ($b - $a) * $t) }
function Avg([System.Drawing.Bitmap]$bmp, [int]$x, [int]$y, [int]$dx) {
    $r = 0; $g = 0; $b = 0
    for ($i = 0; $i -lt 3; $i++) { $c = $bmp.GetPixel($x + $dx * $i, $y); $r += $c.R; $g += $c.G; $b += $c.B }
    [System.Drawing.Color]::FromArgb(255, [int]($r / 3), [int]($g / 3), [int]($b / 3))
}
# Remplit un rectangle en fondu depuis ses quatre bords (surface de Coons) : lisse, sans traînée.
function Fill([int]$x0, [int]$x1, [int]$y0, [int]$y1) {
    $w = $x1 - $x0 + 2; $h = $y1 - $y0 + 2
    $top = @(); $bot = @(); $left = @(); $right = @()
    for ($x = $x0 - 1; $x -le $x1 + 1; $x++) { $top += ,$img.GetPixel($x, $y0 - 1); $bot += ,$img.GetPixel($x, $y1 + 1) }
    for ($y = $y0 - 1; $y -le $y1 + 1; $y++) { $left += ,$img.GetPixel($x0 - 1, $y); $right += ,$img.GetPixel($x1 + 1, $y) }
    for ($y = $y0; $y -le $y1; $y++) {
        $v = ($y - $y0 + 1) / $h; $j = $y - $y0 + 1
        for ($x = $x0; $x -le $x1; $x++) {
            $u = ($x - $x0 + 1) / $w; $i = $x - $x0 + 1
            $ch = foreach ($k in "R", "G", "B") {
                $val = (1 - $v) * $top[$i].$k + $v * $bot[$i].$k + (1 - $u) * $left[$j].$k + $u * $right[$j].$k
                $val -= (1 - $u) * (1 - $v) * $top[0].$k + $u * (1 - $v) * $top[$w].$k + (1 - $u) * $v * $bot[0].$k + $u * $v * $bot[$w].$k
                [Math]::Max(0, [Math]::Min(255, [int]$val))
            }
            $img.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $ch[0], $ch[1], $ch[2]))
        }
    }
}

# Flou (boîte, deux passes) dans un rectangle, pour lisser un fond de halo rebouché.
function Blur([int]$x0, [int]$x1, [int]$y0, [int]$y1, [int]$rad) {
    $w = $x1 - $x0 + 1; $h = $y1 - $y0 + 1
    $ch = @(0..2 | ForEach-Object { New-Object "double[,]" $w, $h })
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { $c = $img.GetPixel($x0 + $x, $y0 + $y); $ch[0][$x, $y] = $c.R; $ch[1][$x, $y] = $c.G; $ch[2][$x, $y] = $c.B } }
    foreach ($pass in 0, 1) {
        foreach ($k in 0..2) {
            $a = $ch[$k]; $b = New-Object "double[,]" $w, $h
            for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
                $sum = 0.0; $n = 0
                for ($d = -$rad; $d -le $rad; $d++) {
                    if ($pass -eq 0) { $xx = $x + $d; if ($xx -ge 0 -and $xx -lt $w) { $sum += $a[$xx, $y]; $n++ } }
                    else { $yy = $y + $d; if ($yy -ge 0 -and $yy -lt $h) { $sum += $a[$x, $yy]; $n++ } }
                }
                $b[$x, $y] = $sum / $n
            } }
            $ch[$k] = $b
        }
    }
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
        # Fondu vers les bords du rectangle, pour ne pas marquer de cadre.
        $e = [Math]::Min([Math]::Min($x, $w - 1 - $x), [Math]::Min($y, $h - 1 - $y))
        $t = [Math]::Min(1.0, $e / [double]$rad)
        $o = $img.GetPixel($x0 + $x, $y0 + $y)
        $img.SetPixel($x0 + $x, $y0 + $y, [System.Drawing.Color]::FromArgb(255, [int]($o.R + ($ch[0][$x, $y] - $o.R) * $t), [int]($o.G + ($ch[1][$x, $y] - $o.G) * $t), [int]($o.B + ($ch[2][$x, $y] - $o.B) * $t)))
    } }
}

# Numéros : la pièce « 1 » et les quatre cadenas.
Fill 241 287 901 975
Fill 565 608 861 899
Fill 402 437 701 739
Fill 518 557 543 578
Fill 701 739 409 447
# Étoiles au-dessus de la pièce (celle du milieu, puis les côtés).
Fill 172 352 812 891
Blur 172 352 812 891 9
# Ruban « Niveau 1 » et étoiles des difficultés.
Fill 385 560 1140 1185
Fill 150 228 1385 1437
Fill 410 532 1385 1437
Fill 678 840 1385 1437
$img.Save("$dir\aventure.png", [System.Drawing.Imaging.ImageFormat]::Png)

# Découpe avec un masque : $inside(x, y) dit si le pixel (coordonnées de l'image) est gardé.
function Cut($from, $x0, $y0, $w, $h, $inside, $name) {
    $out = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
        $a = & $inside ($x0 + $x) ($y0 + $y)
        if ($a -gt 0) { $c = $from.GetPixel($x0 + $x, $y0 + $y); $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb([int](255 * $a), $c.R, $c.G, $c.B)) }
    } }
    $out.Save("$dir\$name.png", [System.Drawing.Imaging.ImageFormat]::Png)
}
# Bord adouci d'une ellipse : 1 dedans, 0 dehors, fondu sur ~1,5 px.
function InEllipse([double]$x, [double]$y, [double]$cx, [double]$cy, [double]$rx, [double]$ry) {
    $d = [Math]::Sqrt([Math]::Pow(($x - $cx) / $rx, 2) + [Math]::Pow(($y - $cy) / $ry, 2))
    [Math]::Max(0.0, [Math]::Min(1.0, (1 - $d) * $rx / 1.5 + 0.5))
}
# Pièce dorée : deux ellipses (dessus, dessous) reliées.
Cut $img 160 876 210 166 { param($x, $y)
    $a = [Math]::Max((InEllipse $x $y 265 938 96 58), (InEllipse $x $y 265 978 96 57))
    if ($y -ge 938 -and $y -le 978 -and $x -ge 170 -and $x -le 360) { $a = [Math]::Max($a, [Math]::Min(1.0, [Math]::Min($x - 169, 361 - $x) / 1.5)) }
    $a } "piece"
# Pierre au cadenas : dôme et socle.
Cut $img 490 820 190 146 { param($x, $y)
    [Math]::Max((InEllipse $x $y 585 886 72 59), (InEllipse $x $y 585 924 87 39)) } "pierre"

# Étoile : tout ce que son contour sombre entoure (remplissage depuis les bords de la découpe).
$x0 = 224; $y0 = 812; $w = 82; $h = 76
$bg = New-Object 'bool[,]' $w, $h
$q = New-Object System.Collections.Generic.Queue[int]
function Dark($c) { (0.3 * $c.R + 0.59 * $c.G + 0.11 * $c.B) -lt 135 }
for ($x = 0; $x -lt $w; $x++) { $q.Enqueue($x); $q.Enqueue(0); $q.Enqueue($x); $q.Enqueue($h - 1) }
for ($y = 0; $y -lt $h; $y++) { $q.Enqueue(0); $q.Enqueue($y); $q.Enqueue($w - 1); $q.Enqueue($y) }
while ($q.Count -gt 0) {
    $x = $q.Dequeue(); $y = $q.Dequeue()
    if ($x -lt 0 -or $y -lt 0 -or $x -ge $w -or $y -ge $h -or $bg[$x, $y]) { continue }
    if (Dark ($orig.GetPixel($x0 + $x, $y0 + $y))) { continue }
    $bg[$x, $y] = $true
    $q.Enqueue($x + 1); $q.Enqueue($y); $q.Enqueue($x - 1); $q.Enqueue($y); $q.Enqueue($x); $q.Enqueue($y + 1); $q.Enqueue($x); $q.Enqueue($y - 1)
}
# Forme de l étoile (centre, pointes), un peu élargie pour garder son contour.
$pts = @(); for ($i = 0; $i -lt 10; $i++) { $a = -[Math]::PI / 2 + $i * [Math]::PI / 5; $rr = if ($i % 2 -eq 0) { 34.0 } else { 18.0 }; $pts += ,@((38 + $rr * [Math]::Cos($a)), (42 + $rr * [Math]::Sin($a))) }
function SegDist($px, $py, $a, $b) {
    $dx = $b[0] - $a[0]; $dy = $b[1] - $a[1]
    $t = [Math]::Max(0, [Math]::Min(1, (($px - $a[0]) * $dx + ($py - $a[1]) * $dy) / ($dx * $dx + $dy * $dy)))
    [Math]::Sqrt([Math]::Pow($px - $a[0] - $t * $dx, 2) + [Math]::Pow($py - $a[1] - $t * $dy, 2))
}
function InStar($px, $py) {
    $in = $false; $near = 99.0
    for ($i = 0; $i -lt 10; $i++) {
        $a = $pts[$i]; $b = $pts[($i + 1) % 10]
        if ((($a[1] -gt $py) -ne ($b[1] -gt $py)) -and ($px -lt ($b[0] - $a[0]) * ($py - $a[1]) / ($b[1] - $a[1]) + $a[0])) { $in = -not $in }
        $near = [Math]::Min($near, (SegDist $px $py $a $b))
    }
    $in -or $near -lt 3
}
# Ne garder que le morceau qui touche le centre (pas les bouts des étoiles voisines).
$keep = New-Object "bool[,]" $w, $h
$q.Enqueue([int]($w / 2)); $q.Enqueue([int]($h / 2))
while ($q.Count -gt 0) {
    $x = $q.Dequeue(); $y = $q.Dequeue()
    if ($x -lt 0 -or $y -lt 0 -or $x -ge $w -or $y -ge $h -or $bg[$x, $y] -or $keep[$x, $y]) { continue }
    if (-not (InStar $x $y)) { continue }
    $keep[$x, $y] = $true
    $q.Enqueue($x + 1); $q.Enqueue($y); $q.Enqueue($x - 1); $q.Enqueue($y); $q.Enqueue($x); $q.Enqueue($y + 1); $q.Enqueue($x); $q.Enqueue($y - 1)
}
$star = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
    if ($keep[$x, $y]) { $c = $orig.GetPixel($x0 + $x, $y0 + $y); $star.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $c.R, $c.G, $c.B)) }
} }
$star.Save("$dir\etoile.png", [System.Drawing.Imaging.ImageFormat]::Png)
"ok"
