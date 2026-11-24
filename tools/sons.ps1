# Synthétise les effets sonores et la musique de fond du jeu dans assets\sons (PRD §9, « Audio »).
# Aucun fichier extérieur : tout est calculé ici. Le feu et le tonnerre ont leurs propres scripts
# (son_feu.ps1, son_tonnerre.ps1). Usage : pwsh -File tools/sons.ps1 [nom ...]  (sans nom : tout)
param([string[]]$only = @())

$dir = Join-Path (Split-Path $PSScriptRoot -Parent) "assets\sons"
New-Item -ItemType Directory -Force $dir | Out-Null
$rnd = [System.Random]::new(11)
$TAU = 2 * [math]::PI

function Save([string]$name, [double[]]$s, [int]$sr, [double]$peakTarget = 0.8, [switch]$loop) {
    $peak = 1e-9
    foreach ($v in $s) { $peak = [math]::Max($peak, [math]::Abs($v)) }
    $k = $peakTarget / $peak
    $n = $s.Length
    $fade = if ($loop) { 0 } else { [int]($sr * 0.004) }
    $path = Join-Path $dir "$name.wav"
    $bw = [System.IO.BinaryWriter]::new([System.IO.File]::Create($path))
    $bw.Write([Text.Encoding]::ASCII.GetBytes("RIFF")); $bw.Write([int](36 + $n * 2))
    $bw.Write([Text.Encoding]::ASCII.GetBytes("WAVEfmt ")); $bw.Write([int]16); $bw.Write([int16]1); $bw.Write([int16]1)
    $bw.Write([int]$sr); $bw.Write([int]($sr * 2)); $bw.Write([int16]2); $bw.Write([int16]16)
    $bw.Write([Text.Encoding]::ASCII.GetBytes("data")); $bw.Write([int]($n * 2))
    for ($i = 0; $i -lt $n; $i++) {
        $v = $s[$i] * $k
        if ($fade -gt 0) { if ($i -lt $fade) { $v *= $i / $fade } elseif ($i -gt $n - $fade) { $v *= ($n - $i) / $fade } }
        $bw.Write([int16][math]::Round([math]::Max(-1, [math]::Min(1, $v)) * 32767))
    }
    $bw.Close()
    "{0}.wav ({1} Ko)" -f $name, [int]((Get-Item $path).Length / 1KB)
}
function Want([string]$name) { return $only.Count -eq 0 -or $only -contains $name }
function Note([double]$midi) { return 440 * [math]::Pow(2, ($midi - 69) / 12) }

# Cloche douce : partiels d'une cloche, chacun s'éteignant plus vite que le fondamental.
function Bell([double[]]$s, [int]$sr, [double]$at, [double]$f, [double]$gain, [double]$decay) {
    $start = [int]($at * $sr); $len = [int]($decay * 5 * $sr)
    $parts = @(@(1.0, 1.0), @(2.0, 0.45), @(3.01, 0.22), @(4.2, 0.12))
    for ($k = 0; $k -lt $len -and $start + $k -lt $s.Length; $k++) {
        $t = $k / $sr; $v = 0.0
        foreach ($p in $parts) { $v += $p[1] * [math]::Sin($TAU * $f * $p[0] * $t) * [math]::Exp(-$t * $p[0] / $decay) }
        $attack = [math]::Min(1.0, $t / 0.004)
        $s[$start + $k] += $gain * $attack * $v
    }
}
# Note pincée (harpe) : sinus et deuxième harmonique, décroissance exponentielle.
function Pluck([double[]]$s, [int]$sr, [double]$at, [double]$f, [double]$gain, [double]$decay, [switch]$wrap) {
    $start = [int]($at * $sr); $len = [int]($decay * 4 * $sr); $n = $s.Length
    for ($k = 0; $k -lt $len; $k++) {
        $idx = $start + $k
        if ($idx -ge $n) { if ($wrap) { $idx -= $n } else { break } }
        $t = $k / $sr
        $v = [math]::Sin($TAU * $f * $t) + 0.25 * [math]::Sin($TAU * 2 * $f * $t) * [math]::Exp(-$t * 3)
        $s[$idx] += $gain * [math]::Min(1.0, $t / 0.006) * [math]::Exp(-$t / $decay) * $v
    }
}
# Note tenue un peu cuivrée : dents de scie adoucies par un filtre, enveloppe attaque/maintien/relâche.
function Brass([double[]]$s, [int]$sr, [double]$at, [double]$f, [double]$dur, [double]$gain) {
    $start = [int]($at * $sr); $len = [int](($dur + 0.35) * $sr); $lp = 0.0; $phase = 0.0
    for ($k = 0; $k -lt $len -and $start + $k -lt $s.Length; $k++) {
        $t = $k / $sr
        $phase += $f / $sr; if ($phase -ge 1) { $phase -= 1 }
        $saw = 2 * $phase - 1
        $env = [math]::Min(1.0, $t / 0.03); if ($t -gt $dur) { $env *= [math]::Exp(-($t - $dur) / 0.1) }
        $a = 1 - [math]::Exp(-$TAU * (900 + 1600 * [math]::Min(1, $t / 0.08)) / $sr)
        $lp += $a * ($saw - $lp)
        $s[$start + $k] += $gain * $env * $lp
    }
}

# ---------------------------------------------------------------- Carte retournée
if (Want "carte") {
    $sr = 44100; $s = [double[]]::new([int](0.32 * $sr))
    foreach ($hit in @(@(0.0, 1.0, 0.07), @(0.11, 0.55, 0.05))) {
        $start = [int]($hit[0] * $sr); $lp = 0.0; $len = [int](0.2 * $sr)
        for ($k = 0; $k -lt $len -and $start + $k -lt $s.Length; $k++) {
            $t = $k / $sr
            $fc = 6500 * [math]::Exp(-$t / 0.05) + 1200
            $lp += (1 - [math]::Exp(-$TAU * $fc / $sr)) * (($rnd.NextDouble() * 2 - 1) - $lp)
            $s[$start + $k] += $hit[1] * [math]::Min(1, $t / 0.003) * [math]::Exp(-$t / $hit[2]) * $lp
        }
    }
    Save "carte" $s $sr 0.6
}

# ---------------------------------------------------------------- Tic-tac (dernières secondes)
if (Want "tic") {
    $sr = 44100; $s = [double[]]::new([int](0.09 * $sr))
    for ($k = 0; $k -lt $s.Length; $k++) {
        $t = $k / $sr
        $s[$k] = [math]::Sin($TAU * 1900 * $t) * [math]::Exp(-$t / 0.012) + 0.6 * ($rnd.NextDouble() * 2 - 1) * [math]::Exp(-$t / 0.0015) + 0.5 * [math]::Sin($TAU * 950 * $t) * [math]::Exp(-$t / 0.02)
    }
    Save "tic" $s $sr 0.55
}

# ---------------------------------------------------------------- Bonne réponse : arpège de cloches qui monte
if (Want "juste") {
    $sr = 44100; $s = [double[]]::new([int](1.2 * $sr))
    $notes = @(84, 88, 91, 96)  # do, mi, sol, do
    for ($i = 0; $i -lt $notes.Count; $i++) { Bell $s $sr ($i * 0.075) (Note $notes[$i]) (0.6 + 0.15 * $i) 0.35 }
    Save "juste" $s $sr 0.7
}

# ---------------------------------------------------------------- Mauvaise réponse : deux notes graves qui descendent
if (Want "faux") {
    $sr = 44100; $s = [double[]]::new([int](0.75 * $sr))
    foreach ($nt in @(@(0.0, 58, 0.16), @(0.17, 54, 0.4))) {
        $start = [int]($nt[0] * $sr); $f = Note $nt[1]; $len = [int](($nt[2] + 0.25) * $sr); $lp = 0.0
        for ($k = 0; $k -lt $len -and $start + $k -lt $s.Length; $k++) {
            $t = $k / $sr
            $tri = 2 * [math]::Abs(2 * (($f * $t) % 1) - 1) - 1
            $tri2 = 2 * [math]::Abs(2 * (($f * 1.006 * $t) % 1) - 1) - 1
            $lp += 0.18 * (($tri + $tri2) / 2 - $lp)
            $env = [math]::Min(1, $t / 0.01); if ($t -gt $nt[2]) { $env *= [math]::Exp(-($t - $nt[2]) / 0.07) }
            $s[$start + $k] += $env * $lp
        }
    }
    Save "faux" $s $sr 0.6
}

# ---------------------------------------------------------------- Victoire : fanfare et pluie de cloches
if (Want "victoire") {
    $sr = 44100; $s = [double[]]::new([int](2.6 * $sr))
    $fan = @(@(0.0, 72, 0.12), @(0.13, 76, 0.12), @(0.26, 79, 0.12), @(0.4, 84, 1.3))
    foreach ($nt in $fan) { Brass $s $sr $nt[0] (Note $nt[1]) $nt[2] 0.5 }
    foreach ($m in @(72, 76, 79)) { Brass $s $sr 0.4 (Note $m) 1.3 0.28 }
    $sparkle = @(96, 100, 103, 108, 103, 108)
    for ($i = 0; $i -lt $sparkle.Count; $i++) { Bell $s $sr (0.45 + $i * 0.09) (Note $sparkle[$i]) 0.25 0.4 }
    Save "victoire" $s $sr 0.75
}

# ---------------------------------------------------------------- Défaite : trois notes douces qui descendent
if (Want "defaite") {
    $sr = 44100; $s = [double[]]::new([int](1.8 * $sr))
    $notes = @(@(0.0, 67), @(0.22, 63), @(0.44, 60))
    foreach ($nt in $notes) { Pluck $s $sr $nt[0] (Note $nt[1]) 0.8 0.45 }
    foreach ($m in @(48, 55, 60, 63)) { Pluck $s $sr 0.44 (Note $m) 0.35 0.9 }
    Save "defaite" $s $sr 0.6
}

# ---------------------------------------------------------------- Musique de fond : nappe calme et harpe, en boucle
if (Want "musique") {
    $sr = 22050; $bar = 4.0
    # Ré majeur : I – vi – IV – V, deux fois, la seconde avec une harpe plus présente.
    $chords = [int[][]]@(@(50, 57, 62, 66), @(47, 54, 59, 62), @(43, 50, 55, 59), @(45, 52, 57, 61))
    $total = $bar * 8; $n = [int]($total * $sr)
    $s = [double[]]::new($n)
    for ($c = 0; $c -lt 8; $c++) {
        [int[]]$ch = $chords[$c % 4]; $at = $c * $bar
        # Nappe : chaque note monte doucement et déborde sur l'accord suivant (fondu enchaîné, en boucle).
        foreach ($m in $ch) {
            $f = Note ($m + 12)
            $start = [int]($at * $sr); $len = [int](($bar + 1.5) * $sr)
            for ($k = 0; $k -lt $len; $k++) {
                $t = $k / $sr
                $env = [math]::Min(1.0, $t / 1.2) * [math]::Min(1.0, [math]::Max(0.0, ($bar + 1.5 - $t) / 1.5))
                $v = [math]::Sin($TAU * $f * $t) + 0.3 * [math]::Sin($TAU * $f * 2.003 * $t) + 0.12 * [math]::Sin($TAU * $f * 0.5 * $t)
                $idx = ($start + $k) % $n
                $s[$idx] += 0.09 * $env * $v * (1 + 0.15 * [math]::Sin($TAU * 0.25 * $t))
            }
        }
        # Harpe : arpège montant puis descendant, une note par demi-temps.
        $arp = @(($ch[0] + 12), ($ch[1] + 12), ($ch[2] + 12), ($ch[3] + 12), ($ch[2] + 24), ($ch[3] + 12), ($ch[2] + 12), ($ch[1] + 12))
        for ($i = 0; $i -lt 8; $i++) {
            $g = if ($c -ge 4) { 0.22 } else { 0.14 }
            Pluck $s $sr ($at + $i * 0.5) (Note $arp[$i]) $g 0.9 -wrap
        }
    }
    Save "musique" $s $sr 0.5 -loop
}
