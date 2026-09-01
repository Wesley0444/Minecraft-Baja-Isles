# =============================================================================
#  build-mod-index.ps1  --  generate a grep-able map of the whole modlist
# -----------------------------------------------------------------------------
#  WHY THIS EXISTS
#    The Discord librarian (/ask) runs with Read/Grep/Glob only. It cannot look
#    inside a .jar, so questions like "which mod owns terra_entity:spiked_slime"
#    or "does anything ban this Sodium version" were unanswerable -- on
#    2026-09-01 that cost three round trips and a wrong diagnosis while a player
#    sat in a crash loop. This bakes the jar metadata out to markdown so plain
#    Grep answers those.
#
#    It also closes the blind spot recorded in planning doc 09 s8 item 8: an
#    EXISTING mod's declared incompatibility against a NEWLY added modid is
#    invisible if you only scan the new jar. The "Declared incompatibilities"
#    section below is every edge in the pack, in one place.
#
#  WHAT IT READS
#    1. pack\mods\*.pw.toml        -- the authoritative list + per-mod side
#    2. the server's mods\         -- jars for everything server-side
#    3. the Prism instance's mods\ -- jars for the client-only mods (Sodium et
#       al are never on the server, so without this half the pack has no
#       metadata). Optional: skipped cleanly if the instance is gone.
#
#  WHAT IT WRITES  (both are committed; both live OUTSIDE pack\ on purpose --
#  `packwiz refresh` globs pack\ and would ship them to every client)
#    pack-tools\MOD-INDEX.md   compact, safe to read end to end
#    pack-tools\MOD-DETAIL.md  per-mod dependency detail, meant for Grep
#
#  RUN IT: after any modlist change. update.bat calls it after the packwiz sync.
# =============================================================================

[CmdletBinding()]
param(
  [string]$ServerDir   = 'C:\Game Servers\Minecraft',
  [string]$InstanceDir = 'C:\Users\wesle\AppData\Roaming\PrismLauncher\instances\BajaIsles-instance-2026-08-30\.minecraft',
  [string]$OutDir      = 'C:\Game Servers\Minecraft\pack-tools'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# --- TOML-ish reader ---------------------------------------------------------
# Not a real TOML parser and does not need to be: neoforge.mods.toml is a flat
# list of [[mods]] / [[dependencies.x]] tables with scalar keys. We only pull
# known keys, so unknown syntax is ignored rather than fatal. The one thing we
# DO track is triple-quoted multi-line strings, because mod descriptions
# routinely contain "modId=" prose that would otherwise pollute the section
# above them.
#
# Section headers MUST tolerate a trailing comment. The NeoForge MDK template
# ships `[[mods]] #mandatory`, and 48 of this pack's 136 jars still carry it
# verbatim -- anchoring the header regex to end-of-line silently drops every
# one of them and you get a plausible-looking index that is 35% short.
function Read-TomlSections([string]$text) {
  $sections = New-Object System.Collections.ArrayList
  $cur = $null
  $inMulti = $false
  foreach ($line in ($text -split "`r?`n")) {
    $t = $line.Trim()
    if ($inMulti) { if ($t -match "('''|`"`"`")\s*$") { $inMulti = $false }; continue }
    if ($t -eq '' -or $t.StartsWith('#')) { continue }
    if ($t -match '^\[\[(.+?)\]\]\s*(#.*)?$') {
      $cur = [ordered]@{ __name = $Matches[1].Trim() }
      [void]$sections.Add($cur); continue
    }
    if ($t -match '^\[(.+?)\]\s*(#.*)?$') {
      $cur = [ordered]@{ __name = $Matches[1].Trim() }
      [void]$sections.Add($cur); continue
    }
    if ($t -match '^([A-Za-z0-9_.\-]+)\s*=\s*(.*)$') {
      $k = $Matches[1]; $v = $Matches[2].Trim()
      if ($v -match "^('''|`"`"`")") {
        $body = $v.Substring(3)
        if (-not ($body -match "('''|`"`"`")\s*$")) { $inMulti = $true }
        continue
      }
      if ($v -match '^"(.*)"\s*(#.*)?$')     { $v = $Matches[1] }
      elseif ($v -match "^'(.*)'\s*(#.*)?$") { $v = $Matches[1] }
      else { $v = (($v -split '#')[0]).Trim() }
      if ($null -ne $cur) { $cur[$k] = $v }
    }
  }
  return $sections
}

# --- zip helpers -------------------------------------------------------------
function Get-ZipText($archive, [string]$entryName) {
  $e = $archive.GetEntry($entryName)
  if ($null -eq $e) { return $null }
  $s = $e.Open()
  try {
    $r = New-Object System.IO.StreamReader($s)
    try { return $r.ReadToEnd() } finally { $r.Dispose() }
  } finally { $s.Dispose() }
}

function Get-ZipStream($archive, [string]$entryName) {
  $e = $archive.GetEntry($entryName)
  if ($null -eq $e) { return $null }
  $s = $e.Open()
  try {
    $ms = New-Object System.IO.MemoryStream
    $s.CopyTo($ms)
    [void]$ms.Seek(0, 'Begin')
    return $ms
  } finally { $s.Dispose() }
}

function Get-ManifestVersion($archive) {
  $mf = Get-ZipText $archive 'META-INF/MANIFEST.MF'
  if ($null -eq $mf) { return $null }
  # MANIFEST.MF wraps at 72 bytes with a leading space on continuation lines
  $flat = $mf -replace "`r?`n ", ''
  if ($flat -match '(?m)^Implementation-Version:\s*(.+?)\s*$') { return $Matches[1] }
  return $null
}

# Pull mod records out of one open jar archive. $parent is the owning jar name
# when this archive is an embedded jar-in-jar, else $null.
function Read-ModsFromArchive($archive, [string]$jarName, [string]$parent) {
  $out = New-Object System.Collections.ArrayList
  $toml = Get-ZipText $archive 'META-INF/neoforge.mods.toml'
  if ($null -eq $toml) { $toml = Get-ZipText $archive 'META-INF/mods.toml' }
  if ($null -eq $toml) { return $out }

  $sections = Read-TomlSections $toml
  $jarVer = $null

  foreach ($sec in $sections) {
    if ($sec.__name -ne 'mods') { continue }
    $id = $sec['modId']
    if ([string]::IsNullOrWhiteSpace($id)) { continue }
    $ver = $sec['version']
    if ($ver -match '\$\{file\.jarVersion\}') {
      if ($null -eq $jarVer) { $jarVer = Get-ManifestVersion $archive }
      if ($jarVer) { $ver = $jarVer } else { $ver = 'unknown' }
    }
    $deps = New-Object System.Collections.ArrayList
    foreach ($d in $sections) {
      if ($d.__name -ne "dependencies.$id") { continue }
      if ([string]::IsNullOrWhiteSpace($d['modId'])) { continue }
      $dtype = if ($d['type']) { $d['type'] }
               elseif ($d['mandatory'] -eq 'true')  { 'required' }
               elseif ($d['mandatory'] -eq 'false') { 'optional' }
               else { 'required' }
      [void]$deps.Add([pscustomobject]@{
        ModId  = $d['modId']
        Type   = $dtype
        Range  = $(if ($d['versionRange']) { $d['versionRange'] } else { '*' })
        Side   = $(if ($d['side']) { $d['side'] } else { 'BOTH' })
        Reason = $d['reason']
      })
    }
    [void]$out.Add([pscustomobject]@{
      ModId       = $id
      DisplayName = $(if ($sec['displayName']) { $sec['displayName'] } else { $id })
      Version     = $(if ($ver) { $ver } else { 'unknown' })
      Jar         = $jarName
      Parent      = $parent
      Deps        = $deps
    })
  }
  return $out
}

# --- scan one jar on disk, plus one level of jar-in-jar -----------------------
function Read-Jar([string]$path) {
  $jarName = Split-Path $path -Leaf
  $result = [pscustomobject]@{
    Mods     = (New-Object System.Collections.ArrayList)
    Embedded = (New-Object System.Collections.ArrayList)
  }
  $zip = $null
  try { $zip = [System.IO.Compression.ZipFile]::OpenRead($path) }
  catch { Write-Warning "unreadable jar: $jarName ($($_.Exception.Message))"; return $result }

  try {
    foreach ($m in (Read-ModsFromArchive $zip $jarName $null)) { [void]$result.Mods.Add($m) }

    # jar-in-jar: this is how terra_entity hides inside ConfluenceOtherworld
    foreach ($e in $zip.Entries) {
      if ($e.FullName -notmatch '^META-INF/jarjar/.+\.jar$') { continue }
      $ms = Get-ZipStream $zip $e.FullName
      if ($null -eq $ms) { continue }
      try {
        $inner = New-Object System.IO.Compression.ZipArchive($ms, [System.IO.Compression.ZipArchiveMode]::Read)
        try {
          $innerName = Split-Path $e.FullName -Leaf
          foreach ($m in (Read-ModsFromArchive $inner $innerName $jarName)) {
            [void]$result.Mods.Add($m)
            [void]$result.Embedded.Add($m)
          }
        } finally { $inner.Dispose() }
      } catch { Write-Warning "unreadable inner jar: $jarName -> $($e.FullName)" }
      finally { $ms.Dispose() }
    }
  } finally { $zip.Dispose() }
  return $result
}

# --- 1. packwiz manifest = the authoritative list ----------------------------
$packSide = @{}   # jar filename (lowercase) -> side
$packDir  = Join-Path $ServerDir 'pack\mods'
$packFiles = @()
if (Test-Path $packDir) { $packFiles = @(Get-ChildItem -Path $packDir -Filter *.pw.toml -File) }
foreach ($f in $packFiles) {
  $raw = Get-Content -Raw -LiteralPath $f.FullName
  $fn = $null; $sd = 'both'
  if ($raw -match '(?m)^\s*filename\s*=\s*"(.*?)"') { $fn = $Matches[1] }
  if ($raw -match '(?m)^\s*side\s*=\s*"(.*?)"')     { $sd = $Matches[1] }
  if ($fn) { $packSide[$fn.ToLower()] = $sd }
}

# --- 2. find jars: server first, then the client instance for client-only mods
$scanDirs = @()
$serverMods = Join-Path $ServerDir 'mods'
if (Test-Path $serverMods) { $scanDirs += ,@{ Path = $serverMods; Source = 'server' } }
$clientMods = Join-Path $InstanceDir 'mods'
if (Test-Path $clientMods) { $scanDirs += ,@{ Path = $clientMods; Source = 'client' } }
else { Write-Warning "client instance not found at $clientMods -- client-only mods will have no metadata" }

$jarsByName = [ordered]@{}
foreach ($d in $scanDirs) {
  foreach ($j in (Get-ChildItem -Path $d.Path -Filter *.jar -File)) {
    $k = $j.Name.ToLower()
    if ($jarsByName.Contains($k)) { continue }   # server copy wins
    $jarsByName[$k] = [pscustomobject]@{ Path = $j.FullName; Name = $j.Name; Source = $d.Source }
  }
}

Write-Host "[mod-index] packwiz entries: $($packFiles.Count)   jars found: $($jarsByName.Count)"

# --- 3. parse every jar ------------------------------------------------------
$mods     = New-Object System.Collections.ArrayList
$embedded = New-Object System.Collections.ArrayList
$scanned  = 0
foreach ($k in $jarsByName.Keys) {
  $j = $jarsByName[$k]
  $r = Read-Jar $j.Path
  foreach ($m in $r.Mods) {
    $srcJar = $(if ($m.Parent) { $m.Parent } else { $m.Jar })
    $side = $packSide[$srcJar.ToLower()]
    if (-not $side) { $side = 'both' }
    [void]$mods.Add([pscustomobject]@{
      ModId = $m.ModId; DisplayName = $m.DisplayName; Version = $m.Version
      Jar = $m.Jar; Parent = $m.Parent; Side = $side; Source = $j.Source; Deps = $m.Deps
    })
  }
  foreach ($e in $r.Embedded) { [void]$embedded.Add($e) }
  $scanned++
  if ($scanned % 40 -eq 0) { Write-Host "[mod-index]   ...$scanned/$($jarsByName.Count) jars" }
}

# Dedupe: the same shaded library is embedded in a dozen jars. Keep the
# top-level copy if one exists, and remember every parent that ships a copy.
$byId = [ordered]@{}
foreach ($m in ($mods | Sort-Object ModId, @{ Expression = { if ($_.Parent) { 1 } else { 0 } } })) {
  if (-not $byId.Contains($m.ModId)) {
    $m | Add-Member -NotePropertyName Parents -NotePropertyValue (New-Object System.Collections.ArrayList) -Force
    $byId[$m.ModId] = $m
  }
  if ($m.Parent) { [void]$byId[$m.ModId].Parents.Add("$($m.Parent) ($($m.Version))") }
}

# packwiz entries whose jar never turned up -- coverage gaps, stated not hidden
$seenJars = @{}
foreach ($m in $byId.Values) { if ($m.Jar) { $seenJars[$m.Jar.ToLower()] = $true } }
$missing = @()
foreach ($fn in $packSide.Keys) { if (-not $seenJars.ContainsKey($fn)) { $missing += $fn } }

# --- 4. emit -----------------------------------------------------------------
$stamp    = Get-Date -Format 'yyyy-MM-dd HH:mm'
$ids      = @($byId.Keys)
$topLevel = @($byId.Values | Where-Object { -not $_.Parent })
$embIds   = @($byId.Values | Where-Object { $_.Parent })

$sb = New-Object System.Text.StringBuilder
function W([string]$s) { [void]$sb.AppendLine($s) }

W "# Baja Isles - Mod Index"
W ""
W "Generated $stamp by ``pack-tools\build-mod-index.ps1``. **Do not hand-edit** - rerun the script."
W ""
W "$($ids.Count) mod ids across $($jarsByName.Count) jars ($($topLevel.Count) top-level, $($embIds.Count) shipped inside other jars)."
W ""
W "## How to use this file"
W ""
W "- ``modid`` is what appears in crash reports, entity ids (``terra_entity:spiked_slime``), and log lines."
W "- A mod listed with ``<- parent.jar`` is **jar-in-jar**: it is not a separate download, it ships inside that parent. Blaming the parent for its behaviour is correct."
W "- ``side: client`` mods are not installed on the server at all. A crash in one of those is never a server fault."
W "- Full dependency detail per mod is in ``pack-tools\MOD-DETAIL.md`` (grep it, do not read it whole)."
W ""
if ($missing.Count -gt 0) {
  $word = $(if ($missing.Count -eq 1) { 'entry' } else { 'entries' })
  W "> **Coverage gap:** $($missing.Count) packwiz $word had no jar on this box, so they contribute no metadata below:"
  W "> $(($missing | Sort-Object) -join ', ')"
  W ""
}

W "## Declared incompatibilities"
W ""
W 'Every `type="incompatible"` / `type="discouraged"` edge in the pack, in one place.'
W "**Check here before adding or bumping any mod** - an existing mod's ban on a new modid is invisible if you only scan the new jar. That is exactly how the Supplementaries/Sodium break shipped."
W ""
$incs = @()
foreach ($m in $byId.Values) {
  foreach ($d in $m.Deps) {
    if ($d.Type -notmatch '^(incompatible|discouraged)$') { continue }
    $incs += [pscustomobject]@{ From = $m.ModId; To = $d.ModId; Type = $d.Type; Range = $d.Range; Side = $d.Side; Reason = $d.Reason }
  }
}
if ($incs.Count -eq 0) { W "_None declared._"; W "" }
else {
  W '```'
  foreach ($i in ($incs | Sort-Object To, From)) {
    $line = "$($i.From) -> $($i.To)  $($i.Type.ToUpper())  range=$($i.Range)  side=$($i.Side)"
    if ($i.Reason) { $line += "  # $($i.Reason)" }
    W $line
  }
  W '```'
  W ""
}

W "## Embedded modules (jar-in-jar)"
W ""
W "``child modid`` <- the jar that actually ships it. This is how you get from a crash-report package name to a downloadable mod."
W ""
if ($embIds.Count -eq 0) { W "_None._"; W "" }
else {
  W '```'
  foreach ($m in ($embIds | Sort-Object ModId)) { W "$($m.ModId) $($m.Version) <- $($m.Parent)" }
  W '```'
  W ""
}

W "## All mods"
W ""
W '```'
W "modid | version | side | jar"
foreach ($m in ($byId.Values | Sort-Object ModId)) {
  $jar = $(if ($m.Parent) { "$($m.Jar) <- $($m.Parent)" } else { $m.Jar })
  W "$($m.ModId) | $($m.Version) | $($m.Side) | $jar"
}
W '```'

$outIndex = Join-Path $OutDir 'MOD-INDEX.md'
[System.IO.File]::WriteAllText($outIndex, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

# --- detail file -------------------------------------------------------------
$sb2 = New-Object System.Text.StringBuilder
function W2([string]$s) { [void]$sb2.AppendLine($s) }
W2 "# Baja Isles - Mod Detail"
W2 ""
W2 "Generated $stamp by ``pack-tools\build-mod-index.ps1``. **Do not hand-edit.**"
W2 ""
W2 "Per-mod dependency detail. This file is a **Grep target** - it is long on purpose."
W2 "For the compact view (incompatibilities, jar-in-jar map, full mod list) read ``pack-tools\MOD-INDEX.md`` instead."
W2 ""
foreach ($m in ($byId.Values | Sort-Object ModId)) {
  W2 "## ``$($m.ModId)`` - $($m.DisplayName)"
  W2 ""
  W2 "- version: ``$($m.Version)``"
  W2 "- side: ``$($m.Side)``"
  W2 "- jar: ``$($m.Jar)``"
  if ($m.Parent) { W2 "- **embedded in:** ``$($m.Parent)`` (jar-in-jar - not a separate download)" }
  $alsoIn = @($m.Parents | Select-Object -Unique)
  if ($alsoIn.Count -gt 1) { W2 "- also shipped inside: $($alsoIn -join ', ')" }
  $req = @($m.Deps | Where-Object { $_.Type -eq 'required' })
  $opt = @($m.Deps | Where-Object { $_.Type -eq 'optional' })
  $bad = @($m.Deps | Where-Object { $_.Type -match '^(incompatible|discouraged)$' })
  if ($req.Count) { W2 "- requires: $(($req | ForEach-Object { "``$($_.ModId)`` $($_.Range)" }) -join ', ')" }
  if ($opt.Count) { W2 "- optional: $(($opt | ForEach-Object { "``$($_.ModId)`` $($_.Range)" }) -join ', ')" }
  foreach ($b in $bad) {
    $line = "- **$($b.Type.ToUpper()) WITH** ``$($b.ModId)`` range=``$($b.Range)`` side=$($b.Side)"
    if ($b.Reason) { $line += " - $($b.Reason)" }
    W2 $line
  }
  W2 ""
}
$outDetail = Join-Path $OutDir 'MOD-DETAIL.md'
[System.IO.File]::WriteAllText($outDetail, $sb2.ToString(), (New-Object System.Text.UTF8Encoding($false)))

Write-Host "[mod-index] wrote $outIndex"
Write-Host "[mod-index] wrote $outDetail"
Write-Host "[mod-index] $($ids.Count) mod ids, $($incs.Count) incompatibility edges, $($embIds.Count) embedded modules"
