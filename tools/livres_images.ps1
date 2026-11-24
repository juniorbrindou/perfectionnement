# Prépare les illustrations des livres. Les originaux de ChatGPT (PNG, ~4 Mo) se déposent dans
# assets\livres, que Godot et git ignorent ; chacun devient un JPG de 1152 × 768 dans
# assets\illustrations, celui que le jeu charge. Les originaux ne sont pas touchés. Les noms
# courts « 1_roi » sont corrigés en « 1_rois ».
# Usage, depuis la racine du dépôt : pwsh -File tools/livres_images.ps1
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$dir = Join-Path $root "assets\livres"
$outDir = Join-Path $root "assets\illustrations"
New-Item -ItemType Directory -Force $outDir | Out-Null
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$params = New-Object System.Drawing.Imaging.EncoderParameters 1
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]88)
$renames = @{ "1_roi" = "1_rois"; "2_roi" = "2_rois"; "cantique" = "cantique_des_cantiques" }

foreach ($f in Get-ChildItem $dir -Filter *.png) {
    $name = $f.BaseName
    if ($renames.ContainsKey($name)) { $name = $renames[$name] }
    $src = [System.Drawing.Image]::FromFile($f.FullName)
    # Recadrage au format 3:2 au centre, puis réduction.
    $w = $src.Width; $h = [int]($w * 2 / 3)
    if ($h -gt $src.Height) { $h = $src.Height; $w = [int]($h * 3 / 2) }
    $crop = New-Object System.Drawing.Rectangle ([int](($src.Width - $w) / 2)), ([int](($src.Height - $h) / 2)), $w, $h
    $dst = New-Object System.Drawing.Bitmap 1152, 768
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.InterpolationMode = "HighQualityBicubic"; $g.PixelOffsetMode = "HighQuality"
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, 1152, 768), $crop, "Pixel")
    $g.Dispose(); $src.Dispose()
    $out = Join-Path $outDir "$name.jpg"
    $dst.Save($out, $codec, $params); $dst.Dispose()
    "{0} → {1}.jpg ({2} Ko)" -f $f.Name, $name, [int]((Get-Item $out).Length / 1KB)
}
