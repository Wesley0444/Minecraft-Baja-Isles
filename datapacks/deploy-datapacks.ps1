# =============================================================================
#  deploy-datapacks.ps1  --  sync the repo's balance datapacks into Paxi
#
#  WHAT: copies the ACTIVE datapack folders from  <repo>\datapacks\  into
#        <repo>\config\paxi\datapacks\  and rewrites Paxi's load-order file.
#        Paxi (server-side mod) then injects them into EVERY world, so a world
#        reset (step 6 pregen, throwaway worlds) never silently drops the
#        balance work.  config\ is gitignored -- the repo copy under datapacks\
#        is the source of truth; THIS script is the deployment step.
#
#  WHEN: after any edit to a datapack under datapacks\, before the next boot.
#        Safe to run with the server up (Paxi reads at world load; /reload or
#        restart to apply).
#
#  WHAT IT DOES NOT TOUCH: datapacks\_retired\ (kept out on purpose),
#        datapacks\structure-collision\ (tooling + template only -- its real
#        payload was the sparsestructures.json5 CONFIG, deployed separately
#        to config\sparsestructures.json5), and any loose files here.
#
#  NOTE: /MIR is safe here (unlike live saves) -- the target dirs are fully
#        owned by this script and contain no hand-edited state.
# =============================================================================

$ErrorActionPreference = 'Stop'
$repo   = Split-Path $PSScriptRoot -Parent
$src    = Join-Path $repo 'datapacks'
$dst    = Join-Path $repo 'config\paxi\datapacks'
$order  = Join-Path $repo 'config\paxi\datapack_load_order.json'

# Load order: later packs override earlier ones. pack-balance stays last so
# cross-mod fixes win any future collision with a per-mod parity pack.
# pack-buffs (doc 09 §3 under-reward buff pass) sits just before it: its files
# are per-mod recipe/loot buffs that nothing else overrides today, and if a
# collision ever appears, pack-balance winning is the correct outcome.
$active = @(
    'confluence-gate-life-crystal',
    'deeperdarker-parity',
    'apotheosis-parity',
    'apotheosis-modded-loot',
    'simplybows-parity',
    'pack-buffs',
    'pack-balance'
)

New-Item -ItemType Directory -Force $dst | Out-Null

foreach ($p in $active) {
    $from = Join-Path $src $p
    if (-not (Test-Path $from)) { throw "missing datapack: $from" }
    robocopy $from (Join-Path $dst $p) /MIR /NJH /NJS /NDL /NFL | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE) on $p" }
    Write-Host "  synced  $p"
}

# Remove anything in the target that is no longer on the active list.
Get-ChildItem $dst -Directory | Where-Object { $active -notcontains $_.Name } | ForEach-Object {
    Write-Host "  removed stale  $($_.Name)"
    Remove-Item $_.FullName -Recurse -Force
}

# Paxi 5.x load-order format: { "loadOrder": [ "name", ... ] }
# BOM-less on purpose: PS 5.1's `-Encoding utf8` emits a UTF-8 BOM. Paxi/Gson tolerate
# one today, but NeoForge's TOML parser does not, and shipping BOMs is how the
# 2026-09-01 confluence-common.toml edit got silently reverted. Don't write them.
[System.IO.File]::WriteAllText($order, (@{ loadOrder = $active } | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
Write-Host "  wrote load order -> $order"
Write-Host "OK: $($active.Count) datapacks deployed to Paxi."
