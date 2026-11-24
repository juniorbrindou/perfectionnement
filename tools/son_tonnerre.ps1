# Synthétise le coup de tonnerre de l'écran « Adversaire trouvé ! » (le VS qui s'écrase) :
# assets\sons\tonnerre.wav, 2,8 s, mono 44,1 kHz. Un claquement sec, un choc grave, puis le
# grondement qui roule et s'éteint. Aucun fichier extérieur. Usage : pwsh -File tools/son_tonnerre.ps1 [graine]
param([int]$seed = 3)

$sr = 44100
$dur = 2.8
$n = [int]($sr * $dur)
$rnd = [System.Random]::new($seed)
$out = [double[]]::new($n)

$prev = 0.0; $brown = 0.0; $lp = 0.0; $roll = 0.0; $rollTarget = 1.0
for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $sr
    $w = $rnd.NextDouble() * 2 - 1
    # Claquement : bruit clair, montée instantanée, chute en quelques centièmes.
    $hp = $w - $prev; $prev = $w
    $crack = $hp * [math]::Exp(-$t / 0.045) * 1.1
    # Choc grave : une sinusoïde qui glisse de 70 à 38 Hz.
    $f = 38 + 32 * [math]::Exp(-$t / 0.15)
    $boom = [math]::Sin(2 * [math]::PI * $f * $t) * [math]::Exp(-$t / 0.45) * 0.9
    # Grondement : bruit brun filtré, qui roule (amplitude qui ondule au hasard) et s'éteint.
    $brown = 0.995 * $brown + 0.05 * $w
    $lp += 0.02 * ($brown - $lp)
    if ($i % 2205 -eq 0) { $rollTarget = 0.55 + 0.9 * $rnd.NextDouble() }
    $roll += 0.0004 * ($rollTarget - $roll)
    $rise = [math]::Min(1.0, $t / 0.12)
    $rumble = $lp * 9.0 * $rise * $roll * [math]::Exp(-$t / 0.95)
    $out[$i] = $crack + $boom + $rumble
}

# Niveau : saturation douce, crête à -1,4 dB, fondu de 5 ms aux bords.
$peak = 0.0
foreach ($v in $out) { $peak = [math]::Max($peak, [math]::Abs($v)) }
$k = 0.85 / $peak
$fade = [int]($sr * 0.005)
$dir = Join-Path (Split-Path $PSScriptRoot -Parent) "assets\sons"
New-Item -ItemType Directory -Force $dir | Out-Null
$path = Join-Path $dir "tonnerre.wav"
$fs = [System.IO.File]::Create($path)
$bw = [System.IO.BinaryWriter]::new($fs)
$bw.Write([Text.Encoding]::ASCII.GetBytes("RIFF")); $bw.Write([int](36 + $n * 2))
$bw.Write([Text.Encoding]::ASCII.GetBytes("WAVEfmt ")); $bw.Write([int]16); $bw.Write([int16]1); $bw.Write([int16]1)
$bw.Write([int]$sr); $bw.Write([int]($sr * 2)); $bw.Write([int16]2); $bw.Write([int16]16)
$bw.Write([Text.Encoding]::ASCII.GetBytes("data")); $bw.Write([int]($n * 2))
for ($i = 0; $i -lt $n; $i++) {
    $v = [math]::Tanh($out[$i] * $k * 1.3) / [math]::Tanh(1.3)
    if ($i -lt $fade) { $v *= $i / $fade } elseif ($i -gt $n - $fade) { $v *= ($n - $i) / $fade }
    $bw.Write([int16][math]::Round($v * 0.85 * 32767))
}
$bw.Close()
"{0} ({1} Ko)" -f $path, [int]((Get-Item $path).Length / 1KB)
