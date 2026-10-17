param([string]$Video, [string]$Ziel, [double]$Sekunde, [int]$Breite = 1600, [int]$Qualitaet = 84)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Drawing
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Editing.MediaComposition, Windows.Media.Editing, ContentType = WindowsRuntime]
$null = [Windows.Media.Editing.MediaClip, Windows.Media.Editing, ContentType = WindowsRuntime]
$warte = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Warte($op, [Type]$t) { $task = $warte.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait(-1) | Out-Null; $task.Result }
$datei = Warte ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Video)) ([Windows.Storage.StorageFile])
$clip = Warte ([Windows.Media.Editing.MediaClip]::CreateFromFileAsync($datei)) ([Windows.Media.Editing.MediaClip])
$folge = New-Object Windows.Media.Editing.MediaComposition
[System.Collections.Generic.ICollection[Windows.Media.Editing.MediaClip]].GetMethod('Add').Invoke($folge.Clips, @($clip)) | Out-Null
$e = $clip.GetVideoEncodingProperties()
$strom = $null
for ($versuch = 0; $versuch -lt 12 -and -not $strom; $versuch++) {
  $b = $Breite - 2 * $versuch
  $h = [int][Math]::Round($b * $e.Height / $e.Width)
  try { $strom = Warte ($folge.GetThumbnailAsync([TimeSpan]::FromSeconds($Sekunde), $b, $h, [Windows.Media.Editing.VideoFramePrecision]::NearestFrame)) ([Windows.Graphics.Imaging.ImageStream]) } catch { Start-Sleep -Milliseconds 200 }
}
if (-not $strom) { throw "Kein Standbild bei $Sekunde s" }
$net = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($strom)
$bild = [System.Drawing.Image]::FromStream($net)
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$p = New-Object System.Drawing.Imaging.EncoderParameters 1
$p.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$Qualitaet)
$bild.Save($Ziel, $codec, $p)
"{0} {1}x{2} {3:N0} KB, Video {4}x{5}, {6:N1} s" -f [IO.Path]::GetFileName($Ziel), $bild.Width, $bild.Height, ((Get-Item $Ziel).Length / 1KB), $e.Width, $e.Height, $folge.Duration.TotalSeconds
$bild.Dispose(); $net.Close()
