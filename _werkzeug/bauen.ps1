param([switch]$Vorschau)

$ErrorActionPreference = 'Stop'
$Wurzel = Split-Path -Parent $PSScriptRoot
$Quelle = Join-Path $Wurzel '_src'
$Seiten = Join-Path $Quelle 'pages'
$Adresse = 'https://noteic.github.io/'
$Utf8 = New-Object System.Text.UTF8Encoding $false

function Lies([string]$pfad) { [IO.File]::ReadAllText($pfad, $Utf8) }
function Schreib([string]$pfad, [string]$text) {
  $ordner = Split-Path -Parent $pfad
  if (-not (Test-Path $ordner)) { New-Item -ItemType Directory -Force $ordner | Out-Null }
  [IO.File]::WriteAllText($pfad, $text, $Utf8)
}
function Kodiere([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }
function Kennung([string]$s) {
  $s = [System.Net.WebUtility]::HtmlDecode(($s -replace '<[^>]+>', '')).ToLowerInvariant()
  $s = $s -replace "['’]", '' -replace '[^a-z0-9]+', '-'
  $s.Trim('-')
}

$eintraege = New-Object System.Collections.ArrayList
$gruppe = $null
foreach ($zeile in (Lies (Join-Path $Quelle 'nav.txt')) -split "`r?`n") {
  $z = $zeile.Trim()
  if ($z -eq '') { continue }
  if ($z.StartsWith('#')) { $gruppe = $z.TrimStart('#').Trim(); if ($gruppe -eq '') { $gruppe = $null }; continue }
  $teile = $z -split '\|', 2
  [void]$eintraege.Add([pscustomobject]@{ Titel = $teile[0].Trim(); Pfad = $teile[1].Trim(); Gruppe = $gruppe })
}

function Ziel([string]$pfad) { if ($pfad -eq '') { 'index.html' } else { "$pfad/index.html" } }
function Tiefe([string]$pfad) { if ($pfad -eq '') { 0 } else { ($pfad -split '/').Count } }
function Verweis([string]$von, [string]$nach) {
  $anker = ''
  if ($nach.Contains('#')) { $anker = '#' + ($nach -split '#', 2)[1]; $nach = ($nach -split '#', 2)[0] }
  $vor = if ($script:Absolut) { '/' } else { '../' * (Tiefe $von) }
  $rel = if ($nach -eq '') { $vor } else { "$vor$nach/" }
  if ($Vorschau) { $rel += 'index.html' }
  if ($rel -eq '') { $rel = './' }
  "$rel$anker"
}

$css = Lies (Join-Path $Wurzel 'assets/site.css')
$js = Lies (Join-Path $Wurzel 'assets/site.js')
$sha = [System.Security.Cryptography.SHA1]::Create()
$Fassung = (($sha.ComputeHash($Utf8.GetBytes($css + $js)) | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 8)
function Rahmen([string]$name) {
  $text = Lies (Join-Path $Quelle "$name.html")
  [regex]::Replace($text, '\{\{include:([a-z]+)\}\}', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) (Lies (Join-Path $Quelle ($m.Groups[1].Value + '.html'))).TrimEnd() })
}
$Rahmen = @{ docs = (Rahmen 'layout'); landing = (Rahmen 'landing') }

$Oben = @(
  @{ Titel = 'Features'; Pfad = '#features'; Bereich = '' },
  @{ Titel = 'Guide'; Pfad = 'guide'; Bereich = 'guide' },
  @{ Titel = "What's new"; Pfad = 'whats-new'; Bereich = 'whats-new' },
  @{ Titel = 'Support'; Pfad = 'support'; Bereich = 'support' }
)
function Obenlinks([string]$basis, [string]$aktuell) {
  $bereich = ($aktuell -split '/')[0]
  ($Oben | ForEach-Object {
    $an = if ($_.Bereich -and $_.Bereich -eq $bereich) { ' aria-current="page"' } else { '' }
    "      <a href=`"$(Verweis $basis $_.Pfad)`"$an>$(Kodiere $_.Titel)</a>"
  }) -join "`n"
}

function Navigation([string]$basis, [string]$aktuell) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('    <ul>')
  $offen = $null
  foreach ($e in $eintraege) {
    if ($e.Gruppe -ne $offen) {
      if ($offen) { [void]$sb.AppendLine('      </ul></li>') }
      if ($e.Gruppe) { [void]$sb.AppendLine("      <li class=`"group`"><span class=`"group-title`">$(Kodiere $e.Gruppe)</span><ul>") }
      $offen = $e.Gruppe
    }
    $an = if ($e.Pfad -eq $aktuell) { ' aria-current="page"' } else { '' }
    [void]$sb.AppendLine("        <li><a href=`"$(Verweis $basis $e.Pfad)`"$an>$(Kodiere $e.Titel)</a></li>")
  }
  if ($offen) { [void]$sb.AppendLine('      </ul></li>') }
  [void]$sb.Append('    </ul>')
  $sb.ToString()
}

$index = New-Object System.Collections.ArrayList
$karte = New-Object System.Collections.ArrayList
$erzeugt = New-Object System.Collections.ArrayList
$fehlt = @()

$alle = @($eintraege) + @([pscustomobject]@{ Titel = 'Page not found'; Pfad = '404'; Gruppe = $null })
for ($i = 0; $i -lt $alle.Count; $i++) {
  $e = $alle[$i]
  $ist404 = $e.Pfad -eq '404'
  $datei = if ($e.Pfad -eq '') { Join-Path $Seiten 'index.html' } else { Join-Path $Seiten ($e.Pfad + '.html') }
  if (-not (Test-Path $datei)) { $fehlt += $e.Pfad; continue }
  $roh = Lies $datei

  $kopf = @{}
  $treffer = [regex]::Match($roh, '^\s*<!--([\s\S]*?)-->')
  if ($treffer.Success) {
    foreach ($z in $treffer.Groups[1].Value -split "`r?`n") { if ($z -match '^\s*([a-z]+)\s*:\s*(.*)$') { $kopf[$Matches[1]] = $Matches[2].Trim() } }
    $roh = $roh.Substring($treffer.Length).TrimStart()
  }
  $titel = if ($kopf.title) { $kopf.title } else { $e.Titel }
  $beschreibung = $kopf.description
  if (-not $beschreibung) { throw "description fehlt in $datei" }

  $pfadFuerLinks = if ($ist404) { '' } else { $e.Pfad }
  $script:Absolut = $ist404 -and -not $Vorschau
  $root = if ($script:Absolut) { '/' } else { '../' * (Tiefe $pfadFuerLinks) }
  $inhalt = [regex]::Replace($roh, '\{\{link:([^}]*)\}\}', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) Verweis $pfadFuerLinks $m.Groups[1].Value })
  $inhalt = $inhalt.Replace('{{root}}', $root)

  $gesehen = @{}
  $inhalt = [regex]::Replace($inhalt, '<(h[23])(?: id="([^"]*)")?>([\s\S]*?)</\1>', [System.Text.RegularExpressions.MatchEvaluator]{
    param($m)
    $tag = $m.Groups[1].Value; $text = $m.Groups[3].Value
    $id = if ($m.Groups[2].Success) { $m.Groups[2].Value } else { Kennung $text }
    if ($gesehen.ContainsKey($id)) { throw "Doppelte Kennung $id in $datei" }
    $gesehen[$id] = $true
    if ($kopf.layout -eq 'landing') { "<$tag id=`"$id`">$text</$tag>" } else { "<$tag id=`"$id`">$text<a class=`"headerlink`" href=`"#$id`" aria-label=`"Link to this section`">#</a></$tag>" }
  })

  $ueber = [regex]::Matches($inhalt, '<h2 id="([^"]*)">([\s\S]*?)<a class="headerlink"')
  $toc = ''
  if ($ueber.Count -gt 1 -and $kopf.toc -ne 'no' -and $kopf.layout -ne 'wide') {
    $li = ($ueber | ForEach-Object { "      <li><a href=`"#$($_.Groups[1].Value)`">$(($_.Groups[2].Value -replace '<span class="badge">[\s\S]*?</span>', '').Trim())</a></li>" }) -join "`n"
    $toc = "  <aside class=`"toc`" aria-label=`"On this page`">`n    <p class=`"toc-title`">On this page</p>`n    <ul>`n$li`n    </ul>`n  </aside>"
  }

  $pager = ''
  if (-not $ist404 -and $kopf.pager -ne 'no') {
    $teile = @()
    if ($i -gt 0) { $v = $eintraege[$i - 1]; $teile += "      <a class=`"prev`" href=`"$(Verweis $e.Pfad $v.Pfad)`"><span class=`"dir`">Previous</span><span class=`"name`">$(Kodiere $v.Titel)</span></a>" }
    else { $teile += '      <span style="flex:1"></span>' }
    if ($i -lt $eintraege.Count - 1) { $n = $eintraege[$i + 1]; $teile += "      <a class=`"next`" href=`"$(Verweis $e.Pfad $n.Pfad)`"><span class=`"dir`">Next</span><span class=`"name`">$(Kodiere $n.Titel)</span></a>" }
    $pager = "    <nav class=`"pager`" aria-label=`"Previous and next page`">`n$($teile -join "`n")`n    </nav>"
  }

  $seitentitel = if ($kopf.pagetitle) { $kopf.pagetitle } elseif ($e.Pfad -eq '') { 'Noteic' } else { "$titel · Noteic" }
  $kanon = if ($ist404) { $Adresse } elseif ($e.Pfad -eq '') { $Adresse } else { "$Adresse$($e.Pfad)/" }
  $klasse = if ($kopf.layout -eq 'wide' -or $toc -eq '') { ' wide' } else { '' }

  $seite = if ($kopf.layout -eq 'landing') { $Rahmen.landing } else { $Rahmen.docs }
  $seite = [regex]::Replace($seite, '\{\{link:([^}]*)\}\}', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) Verweis $pfadFuerLinks $m.Groups[1].Value })
  $ersetze = [ordered]@{
    '{{pagetitle}}' = (Kodiere $seitentitel); '{{description}}' = (Kodiere $beschreibung); '{{canonical}}' = $kanon
    '{{version}}' = $Fassung; '{{indexfile}}' = $(if ($Vorschau) { 'index.html' } else { '' })
    '{{home}}' = (Verweis $pfadFuerLinks ''); '{{layoutclass}}' = $klasse; '{{nav}}' = (Navigation $pfadFuerLinks $e.Pfad); '{{toplinks}}' = (Obenlinks $pfadFuerLinks $e.Pfad)
    '{{toc}}' = $toc; '{{pager}}' = $pager
  }
  foreach ($k in $ersetze.Keys) { $seite = $seite.Replace($k, [string]$ersetze[$k]) }
  $seite = $seite.Replace('{{root}}', $root).Replace('{{content}}', $inhalt.TrimEnd())
  $script:Absolut = $false

  $ausgabe = if ($ist404) { '404.html' } else { Ziel $e.Pfad }
  Schreib (Join-Path $Wurzel $ausgabe) $seite
  [void]$erzeugt.Add($ausgabe)

  if (-not $ist404) {
    [void]$karte.Add($kanon)
    $stuecke = [regex]::Split($inhalt, '(?=<h2 id=")')
    foreach ($st in $stuecke) {
      $anker = ''; $kopfzeile = ''
      if ($st -match '^<h2 id="([^"]*)">([\s\S]*?)<a class="headerlink"') { $anker = $Matches[1]; $kopfzeile = [System.Net.WebUtility]::HtmlDecode(($Matches[2] -replace '<[^>]+>', '')).Trim() }
      $text = $st -replace '<a class="headerlink"[^>]*>#</a>', '' -replace '<(script|style)[\s\S]*?</\1>', ' ' -replace '<[^>]+>', ' '
      $text = ([System.Net.WebUtility]::HtmlDecode($text) -replace '\s+', ' ').Trim()
      if ($text.Length -gt 900) { $text = $text.Substring(0, 900) }
      if ($text -eq '' -and $kopfzeile -eq '') { continue }
      [void]$index.Add([pscustomobject]@{ t = $titel; h = $kopfzeile; u = $e.Pfad; a = $anker; x = $text })
    }
  }
}

if ($fehlt.Count -gt 0) { throw ('Seiten fehlen: ' + ($fehlt -join ', ')) }

$json = ConvertTo-Json -InputObject @($index) -Compress -Depth 3
Schreib (Join-Path $Wurzel 'assets/search-index.js') ("window.NOTEIC_INDEX=$json;`n")

$xml = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`">`n" + (($karte | ForEach-Object { "  <url><loc>$_</loc></url>" }) -join "`n") + "`n</urlset>`n"
Schreib (Join-Path $Wurzel 'sitemap.xml') $xml

$liste = Join-Path $PSScriptRoot 'erzeugt.txt'
if (Test-Path $liste) {
  foreach ($alt in (Lies $liste) -split "`r?`n") {
    if ($alt -and -not $erzeugt.Contains($alt)) {
      $p = Join-Path $Wurzel $alt
      if (Test-Path $p) { Remove-Item $p -Confirm:$false; Write-Output "entfernt: $alt" }
    }
  }
}
Schreib $liste (($erzeugt | Sort-Object) -join "`n")
Write-Output ("{0} Seiten gebaut{1}, Fassung {2}, Suchindex {3} Abschnitte" -f $erzeugt.Count, $(if ($Vorschau) { ' (Vorschau)' } else { '' }), $Fassung, $index.Count)
