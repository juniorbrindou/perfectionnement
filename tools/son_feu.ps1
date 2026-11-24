# Synthétise le son du feu doré (carte détruite) : assets\sons\feu.wav, 2,4 s, mono 44,1 kHz.
# Un souffle d'embrasement, le grondement des flammes, des crépitements, puis l'extinction.
# Aucun fichier extérieur : tout est calculé ici. Usage : pwsh -File tools/son_feu.ps1 [graine]
param([int]$seed = 7)

$sr = 44100
$dur = 2.4
$n = [int]($sr * $dur)
$rnd = [System.Random]::new($seed)
$out = [double[]]::new($n)

function Envelope([double]$t) {
    $attack = [math]::Min(1.0, $t / 0.18)
    $attack = $attack * $attack * (3 - 2 * $attack)
    $release = if ($t -lt 1.75) { 1.0 } else { [math]::Max(0.0, 1.0 - ($t - 1.75) / 0.65) }
    return $attack * $release * $release
}

# Flammes : bruit filtré, plus clair au plus fort de l'embrasement, et grondement grave.
$lp = 0.0; $rumble = 0.0; $flutter = 0.0
for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $sr
    $env = Envelope $t
    $w = $rnd.NextDouble() * 2 - 1
    $fc = 500 + 1500 * $env
    $a = 1 - [math]::Exp(-2 * [math]::PI * $fc / $sr)
    $lp += $a * ($w - $lp)
    $rumble += 0.012 * ($w - $rumble)
    $flutter += 0.0006 * (($rnd.NextDouble() * 2 - 1) - $flutter)
    $whoosh = [math]::Exp(-[math]::Pow(($t - 0.22) / 0.16, 2))
    $amp = $env * (0.8 + 6.0 * $flutter)
    $out[$i] = $amp * (0.55 * $lp + 3.2 * $rumble) + $whoosh * 0.35 * $lp
}

# Crépitements : petits claquements secs, plus nombreux quand le feu est fort.
$t = 0.05
while ($t -lt $dur - 0.1) {
    $env = Envelope $t
    $t += -[math]::Log(1 - $rnd.NextDouble()) / (8 + 38 * $env)
    $start = [int]($t * $sr)
    $len = [int]($sr * (0.002 + 0.01 * $rnd.NextDouble()))
    $gain = (0.25 + 0.75 * $rnd.NextDouble()) * (0.3 + 0.7 * (Envelope $t))
    $freq = 1200 + 3000 * $rnd.NextDouble()
    $prev = 0.0
    for ($k = 0; $k -lt $len -and $start + $k -lt $n; $k++) {
        $decay = [math]::Exp(-$k / ($len * 0.25))
        $w = $rnd.NextDouble() * 2 - 1
        $hp = $w - $prev; $prev = $w
        $ring = [math]::Sin(2 * [math]::PI * $freq * $k / $sr)
        $out[$start + $k] += $gain * $decay * (0.5 * $hp + 0.5 * $ring)
    }
}

# Niveau : saturation douce, crête à -1,4 dB, fondu de 5 ms aux bords.
$peak = 0.0
foreach ($v in $out) { $peak = [math]::Max($peak, [math]::Abs($v)) }
$k = 0.71 / $peak
$fade = [int]($sr * 0.005)
$root = Split-Path $PSScriptRoot -Parent
$dir = Join-Path $root "assets\sons"
New-Item -ItemType Directory -Force $dir | Out-Null
$path = Join-Path $dir "feu.wav"
$fs = [System.IO.File]::Create($path)
$bw = [System.IO.BinaryWriter]::new($fs)
$bw.Write([Text.Encoding]::ASCII.GetBytes("RIFF")); $bw.Write([int](36 + $n * 2))
$bw.Write([Text.Encoding]::ASCII.GetBytes("WAVEfmt ")); $bw.Write([int]16); $bw.Write([int16]1); $bw.Write([int16]1)
$bw.Write([int]$sr); $bw.Write([int]($sr * 2)); $bw.Write([int16]2); $bw.Write([int16]16)
$bw.Write([Text.Encoding]::ASCII.GetBytes("data")); $bw.Write([int]($n * 2))
for ($i = 0; $i -lt $n; $i++) {
    $v = [math]::Tanh($out[$i] * $k * 1.2) / [math]::Tanh(1.2)
    if ($i -lt $fade) { $v *= $i / $fade } elseif ($i -gt $n - $fade) { $v *= ($n - $i) / $fade }
    $bw.Write([int16][math]::Round($v * 0.85 * 32767))
}
$bw.Close()
"{0} ({1} Ko)" -f $path, [int]((Get-Item $path).Length / 1KB)
