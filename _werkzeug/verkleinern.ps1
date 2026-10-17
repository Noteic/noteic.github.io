param([string]$Quelle, [string]$Ziel, [int]$Breite = 1600, [int]$Bitrate = 2500000)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Storage.StorageFolder, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Transcoding.MediaTranscoder, Windows.Media.Transcoding, ContentType = WindowsRuntime]
$null = [Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media.MediaProperties, ContentType = WindowsRuntime]
$methoden = [System.WindowsRuntimeSystemExtensions].GetMethods()
$op = ($methoden | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$akt = ($methoden | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncActionWithProgress`1' })[0]
function Warte($o, [Type]$t) { $task = $op.MakeGenericMethod($t).Invoke($null, @($o)); $task.Wait(-1) | Out-Null; $task.Result }
$q = Warte ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Quelle)) ([Windows.Storage.StorageFile])
$ordner = Warte ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync((Split-Path -Parent $Ziel))) ([Windows.Storage.StorageFolder])
$z = Warte ($ordner.CreateFileAsync((Split-Path -Leaf $Ziel), [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])
$profil = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateMp4([Windows.Media.MediaProperties.VideoEncodingQuality]::HD1080p)
$quelleProfil = Warte ([Windows.Media.MediaProperties.MediaEncodingProfile]::CreateFromFileAsync($q)) ([Windows.Media.MediaProperties.MediaEncodingProfile])
$w = $quelleProfil.Video.Width; $h = $quelleProfil.Video.Height
$b = [Math]::Min($Breite, $w); $hh = [int]([Math]::Round($h * $b / $w / 2) * 2)
$profil.Video.Width = $b; $profil.Video.Height = $hh
$profil.Video.Bitrate = $Bitrate
$profil.Video.FrameRate.Numerator = $quelleProfil.Video.FrameRate.Numerator
$profil.Video.FrameRate.Denominator = $quelleProfil.Video.FrameRate.Denominator
$profil.Audio = $null
$t = New-Object Windows.Media.Transcoding.MediaTranscoder
$t.HardwareAccelerationEnabled = $true
$vorb = Warte ($t.PrepareFileTranscodeAsync($q, $z, $profil)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
if (-not $vorb.CanTranscode) { throw "Kann nicht umwandeln: $($vorb.FailureReason)" }
$task = $akt.MakeGenericMethod([double]).Invoke($null, @($vorb.TranscodeAsync())); $task.Wait(-1) | Out-Null
"{0}: {1}x{2} -> {3}x{4}, {5:N1} MB -> {6:N1} MB" -f (Split-Path -Leaf $Ziel), $w, $h, $b, $hh, ((Get-Item $Quelle).Length / 1MB), ((Get-Item $Ziel).Length / 1MB)
