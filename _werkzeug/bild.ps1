param([string]$Quelle, [string]$Ziel, [int]$Breite = 1600, [int]$Qualitaet = 86)
Add-Type -AssemblyName System.Drawing
$bild = [System.Drawing.Image]::FromFile($Quelle)
$b = [Math]::Min($Breite, $bild.Width)
$h = [int][Math]::Round($bild.Height * $b / $bild.Width)
$neu = New-Object System.Drawing.Bitmap $b, $h
$g = [System.Drawing.Graphics]::FromImage($neu)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$g.Clear([System.Drawing.Color]::White)
$attr = New-Object System.Drawing.Imaging.ImageAttributes
$attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
$g.DrawImage($bild, (New-Object System.Drawing.Rectangle 0, 0, $b, $h), 0, 0, $bild.Width, $bild.Height, [System.Drawing.GraphicsUnit]::Pixel, $attr)
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$p = New-Object System.Drawing.Imaging.EncoderParameters 1
$p.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$Qualitaet)
$neu.Save($Ziel, $codec, $p)
$g.Dispose(); $neu.Dispose(); $bild.Dispose()
"{0} {1}x{2} {3:N0} KB" -f [IO.Path]::GetFileName($Ziel), $b, $h, ((Get-Item $Ziel).Length / 1KB)
