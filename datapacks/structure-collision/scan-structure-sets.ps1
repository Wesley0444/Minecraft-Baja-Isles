<#
  scan-structure-sets.ps1
  -----------------------------------------------------------------------
  WHAT IT DOES
    Reads every .jar in the server's mods\ folder and extracts each
    data\<modid>\worldgen\structure_set\<name>.json it contains. Reports
    spacing / separation / salt per set, computes areal density, and
    flags the two real failure modes:
      1. DUPLICATE SALT + identical spacing/separation across two sets
         -> those two sets place at the SAME chunk every time. 100%
            overlap, everywhere. This is the interpenetration smoking gun.
      2. Aggregate density vs the vanilla baseline.

  WHY NOT JUST /dumpstructuresets
    That command (shipped by Sparse Structures) is the in-game source of
    truth, but it needs a booted server and a loaded world. This runs on
    the jars alone, so you can settle the modlist BEFORE creating the
    world -- which is the only time structure spacing is still free.
    Run both; they should agree.

  USAGE
    powershell -ExecutionPolicy Bypass -File scan-structure-sets.ps1 `
        -ModsPath "C:\Game Servers\Minecraft\mods"
#>
param(
    [string]$ModsPath = "C:\Game Servers\Minecraft\mods",
    [string]$OutCsv   = "C:\Game Servers\Minecraft\planning\structure-collision\structure-sets.csv"
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not (Test-Path $ModsPath)) {
    Write-Host "mods folder not found: $ModsPath" -ForegroundColor Red
    exit 1
}

$rows = New-Object System.Collections.Generic.List[object]

foreach ($jar in Get-ChildItem -Path $ModsPath -Filter *.jar -File) {
    try   { $zip = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName) }
    catch { Write-Host "  ! unreadable jar: $($jar.Name)" -ForegroundColor Yellow; continue }

    foreach ($e in $zip.Entries) {
        if ($e.FullName -notmatch '^data/([^/]+)/worldgen/structure_set/(.+)\.json$') { continue }
        $ns  = $Matches[1]
        $set = $Matches[2]

        $sr   = New-Object System.IO.StreamReader($e.Open())
        $text = $sr.ReadToEnd(); $sr.Close()

        try   { $j = $text | ConvertFrom-Json }
        catch { Write-Host "  ! bad json: $($jar.Name) :: $($e.FullName)" -ForegroundColor Yellow; continue }

        $p = $j.placement
        if ($null -eq $p) { continue }

        $spacing = $null; $separation = $null; $salt = $null; $freq = 1.0
        if ($p.PSObject.Properties.Name -contains 'spacing')    { $spacing    = [int]$p.spacing }
        if ($p.PSObject.Properties.Name -contains 'separation') { $separation = [int]$p.separation }
        if ($p.PSObject.Properties.Name -contains 'salt')       { $salt       = [long]$p.salt }
        if ($p.PSObject.Properties.Name -contains 'frequency')  { $freq       = [double]$p.frequency }

        $density = $null
        if ($spacing -ne $null -and $spacing -gt 0) {
            $density = [math]::Round(($freq / ($spacing * $spacing)) * 10000, 4)
        }

        $excl = ''
        if ($p.PSObject.Properties.Name -contains 'exclusion_zone' -and $null -ne $p.exclusion_zone) {
            $excl = "$($p.exclusion_zone.other_set)/$($p.exclusion_zone.chunk_count)"
        }

        $rows.Add([pscustomobject]@{
            Jar        = $jar.Name
            SetId      = "$ns`:$set"
            Type       = $p.type
            Spacing    = $spacing
            Separation = $separation
            Salt       = $salt
            Frequency  = $freq
            Structures = @($j.structures).Count
            DensityP10k= $density
            Exclusion  = $excl
        })
    }
    $zip.Dispose()
}

if ($rows.Count -eq 0) { Write-Host "No structure sets found." -ForegroundColor Yellow; exit 0 }

Write-Host ""
Write-Host "=== STRUCTURE SETS FOUND: $($rows.Count) ===" -ForegroundColor Cyan
$rows | Sort-Object -Property @{E={$_.DensityP10k}; Descending=$true} |
    Format-Table SetId, Spacing, Separation, Salt, Frequency, DensityP10k, Exclusion -AutoSize

# --- failure mode 1: identical salt AND identical grid => guaranteed co-location
Write-Host ""
Write-Host "=== HARD COLLISIONS (same salt + same spacing + same separation) ===" -ForegroundColor Cyan
$hard = $rows | Where-Object { $_.Salt -ne $null -and $_.Spacing -ne $null } |
        Group-Object Salt, Spacing, Separation | Where-Object { $_.Count -gt 1 }
if ($hard) {
    foreach ($g in $hard) {
        Write-Host ("  COLLISION salt/spacing/sep = {0}" -f $g.Name) -ForegroundColor Red
        $g.Group | ForEach-Object { Write-Host "     - $($_.SetId)   [$($_.Jar)]" -ForegroundColor Red }
    }
    Write-Host "  -> These generate at the SAME chunk every time. Fix by overriding" -ForegroundColor Red
    Write-Host "     one set's salt in the datapack, or by giving them different" -ForegroundColor Red
    Write-Host "     customSpreadFactors (different spacing breaks the lockstep)." -ForegroundColor Red
} else {
    Write-Host "  none - no two sets share a salt AND a grid. Good." -ForegroundColor Green
}

# --- failure mode 2: aggregate density vs vanilla
# Verified vanilla anchors (misode/mcmeta): villages 34/8, pillager_outposts 32/8,
# nether_complexes 27/4. Vanilla overworld aggregate is ~1 structure per ~85 chunks.
$modded = $rows | Where-Object { $_.SetId -notlike 'minecraft:*' -and $_.DensityP10k -ne $null }
$vanillaRef = (1.0 / (34*34)) * 10000   # one villages-equivalent set
$sumMod = ($modded | Measure-Object -Property DensityP10k -Sum).Sum
Write-Host ""
Write-Host "=== DENSITY ===" -ForegroundColor Cyan
Write-Host ("  modded sets: {0}   aggregate density: {1} (villages-equivalents: {2})" -f `
    $modded.Count, [math]::Round($sumMod,3), [math]::Round($sumMod / $vanillaRef, 2))
Write-Host "  A 'villages-equivalent' of ~13 is roughly all of vanilla overworld."
Write-Host "  Divide by spreadFactor^2 to get the post-SparseStructures value."
foreach ($f in @(2.0, 2.5, 3.0)) {
    Write-Host ("    spreadFactor {0} -> {1} villages-equivalents" -f `
        $f, [math]::Round(($sumMod / $vanillaRef) / ($f*$f), 2))
}

$rows | Sort-Object SetId | Export-Csv -NoTypeInformation -Encoding utf8 -Path $OutCsv
Write-Host ""
Write-Host "CSV written: $OutCsv" -ForegroundColor Green
