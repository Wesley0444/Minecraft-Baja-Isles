# =============================================================================
#  balance-bounce.ps1  --  ONE-SHOT maintenance bounce for the doc 09 balance
#                          completion pass (2026-08-31). Safe to re-run.
#
#  WHAT IT DOES (in order):
#    1. Preflight: server must be UP (port 25565 listening).
#    2. Drops maintenance.lock (backup logs [SKIP], Discord bot says "planned").
#    3. RCON announce 60s warning -> graceful stop -> waits for port close + grace.
#    4. Applies the three config edits (idempotent -- skips if already applied):
#         awakened-common.toml   damageMultiplier   1.0 -> 0.5   (doc 09 s1.1)
#         eternal_starlight.json enableBossRespawn  true -> false (doc 09 s1.2)
#         simplyswords\loot.toml standard/rare weights -> 0.0     (doc 09 s1.5)
#    5. Deploys datapacks (deploy-datapacks.ps1: now 6 packs incl. pack-buffs).
#    6. git add/commit/push (skip with -SkipPush) -> waits for GitHub Pages to
#       serve the new pack manifest -> packwiz-installer server sync (FallingTree).
#       If Pages lags >6 min the sync is SKIPPED (rerun update.bat later).
#    7. Restarts via the SYSTEM boot task, waits for port, greps boot log for
#       the doc 09 verification lines, removes maintenance.lock.
#
#  RUN AS: Wesley-user, non-elevated, from anywhere. NOT while a pregen rig runs.
#  Liveness checks are PORT-based on purpose -- SYSTEM process command lines are
#  invisible non-elevated (CLAUDE.md gotcha).
# =============================================================================
param(
    [switch]$SkipPush
)
$ErrorActionPreference = 'Stop'
$SRV   = 'C:\Game Servers\Minecraft'
$LOCK  = Join-Path $SRV 'maintenance.lock'
$JAVA  = 'C:\Program Files\Microsoft\jdk-21.0.4.7-hotspot\bin\java.exe'
$PACK_URL = 'https://wesley0444.github.io/Minecraft-Baja-Isles/pack/pack.toml'
$TASK  = 'Minecraft Dedicated Server'

function Test-Port { (netstat -an | Select-String ':25565.*LISTENING') -ne $null }
function Step { param([string]$m) Write-Host "`n=== $m" -ForegroundColor Cyan }

# --- 4a helper: idempotent single-occurrence text edit -----------------------
function Edit-Config {
    param([string]$Path, [string]$Find, [string]$Replace, [string]$AlreadyPattern)
    $raw = Get-Content $Path -Raw
    if ($raw -match [regex]::Escape($Replace) -or ($AlreadyPattern -and $raw -match $AlreadyPattern)) {
        Write-Host "  already applied: $(Split-Path $Path -Leaf)"; return
    }
    $count = ([regex]::Matches($raw, [regex]::Escape($Find))).Count
    if ($count -ne 1) { throw "expected exactly 1 match of '$Find' in $Path, found $count -- aborting before damage" }
    [IO.File]::WriteAllText($Path, $raw.Replace($Find, $Replace))
    Write-Host "  edited: $(Split-Path $Path -Leaf)  ($Find -> $Replace)"
}

Step 'Preflight'
if (-not (Test-Port)) { throw 'port 25565 not listening -- server is not up; nothing to bounce (start it first or investigate)' }

Step 'Maintenance lock + 60s warning'
"$(Get-Date)" | Out-File $LOCK -Encoding ascii
& powershell -NoProfile -File (Join-Path $SRV 'backup.ps1') -Mode Announce -Message 'Server restarting for a balance update in 60 seconds.'
Start-Sleep -Seconds 60
& powershell -NoProfile -File (Join-Path $SRV 'backup.ps1') -Mode Announce -Message 'Restarting now - back in ~3 minutes.'

Step 'Graceful stop'
& powershell -NoProfile -File (Join-Path $SRV 'backup.ps1') -Mode Stop
$deadline = (Get-Date).AddSeconds(120)
while ((Test-Port) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 3 }
if (Test-Port) { throw 'port 25565 still listening 120s after stop -- investigate before continuing' }
Write-Host '  port closed; 45s save-flush grace...'
Start-Sleep -Seconds 45

Step 'Config edits'
Edit-Config -Path (Join-Path $SRV 'config\awakened-common.toml') `
    -Find 'damageMultiplier = 1.0' -Replace 'damageMultiplier = 0.5'
Edit-Config -Path (Join-Path $SRV 'config\eternal_starlight.json') `
    -Find '"enableBossRespawn": true' -Replace '"enableBossRespawn": false'
Edit-Config -Path (Join-Path $SRV 'config\simplyswords\loot.toml') `
    -Find 'standardLootTableWeight = 0.1' -Replace 'standardLootTableWeight = 0.0'
Edit-Config -Path (Join-Path $SRV 'config\simplyswords\loot.toml') `
    -Find 'rareLootTableWeight = 0.4' -Replace 'rareLootTableWeight = 0.0'
# Chain-shortening (Wesley 2026-08-31): the 8-tablet awakening count is hardcoded
# (Runic Forge has 8 level slots), so halve the GRIND instead -- double tablet
# drop chance + halve the hard pity. 8 tablets now cost what 4 used to.
Edit-Config -Path (Join-Path $SRV 'config\simplyswords\loot.toml') `
    -Find 'runicLootTableWeight = 0.7' -Replace 'runicLootTableWeight = 1.4'
Edit-Config -Path (Join-Path $SRV 'config\simplyswords\loot.toml') `
    -Find 'tabletHardPity = 60' -Replace 'tabletHardPity = 30'

Step 'Deploy datapacks'
& powershell -NoProfile -File (Join-Path $SRV 'datapacks\deploy-datapacks.ps1')

if (-not $SkipPush) {
    Step 'Git commit + push'
    git -C $SRV add -A
    git -C $SRV commit -m 'Balance completion pass (doc 09): nerfs, buffs, BC weapon_attributes, Azazel loot trim, FallingTree/Sodium/LDL stubs'
    git -C $SRV push
    Step 'Wait for GitHub Pages to serve the new pack manifest'
    $localIndexHash = (Select-String -Path (Join-Path $SRV 'pack\pack.toml') -Pattern '^hash = "(.+)"').Matches[0].Groups[1].Value
    $ok = $false; $deadline = (Get-Date).AddMinutes(6)
    while ((Get-Date) -lt $deadline) {
        try {
            # .Content is byte[] for non-text content types (TOML!) -- decode explicitly,
            # or the regex silently never matches (cost us a false "Pages stale" 2026-08-31).
            $resp = Invoke-WebRequest -UseBasicParsing -Uri $PACK_URL -TimeoutSec 15
            $remote = if ($resp.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($resp.Content) } else { [string]$resp.Content }
            if ($remote -match [regex]::Escape($localIndexHash)) { $ok = $true; break }
        } catch { }
        Start-Sleep -Seconds 20
    }
    if ($ok) {
        Step 'Packwiz server sync (FallingTree lands here)'
        Push-Location $SRV
        & $JAVA -jar (Join-Path $SRV 'packwiz-installer-bootstrap.jar') -g -s server $PACK_URL
        Pop-Location
    } else {
        Write-Warning 'Pages did not serve the new manifest within 6 min -- SKIPPING pack sync. Run update.bat later to deliver FallingTree.'
    }
} else {
    Write-Warning '-SkipPush: pack changes NOT pushed, server pack sync SKIPPED (FallingTree not delivered this bounce).'
}

Step 'Restart via boot task'
schtasks /Run /TN $TASK | Out-Null
$deadline = (Get-Date).AddMinutes(6)
while (-not (Test-Port) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 5 }
if (-not (Test-Port)) { throw "port 25565 not listening 6 min after task start -- check logs\latest.log" }
Write-Host '  port is up.'

Step 'Boot log verification (waits 45s for mod load lines to flush)'
Start-Sleep -Seconds 45
$log = Get-Content (Join-Path $SRV 'logs\latest.log') -Raw
foreach ($check in @(
    @{ n='Awakening config parsed (ability override keys line)'; rx='Ability balance-override keys' },
    @{ n='pack-buffs datapack loaded';                           rx='pack-buffs' },
    @{ n='FallingTree mod present (only after pack sync)';       rx='(?i)fallingtree' }
)) {
    if ($log -match $check.rx) { Write-Host ("  [OK]   " + $check.n) } else { Write-Host ("  [MISS] " + $check.n) -ForegroundColor Yellow }
}

Remove-Item $LOCK -Force -ErrorAction SilentlyContinue
& powershell -NoProfile -File (Join-Path $SRV 'backup.ps1') -Mode Announce -Message 'Server is back - balance update live.'
Step 'DONE. Manual verification list = doc 09 (JEI recipe checks, damage spot-checks).'
