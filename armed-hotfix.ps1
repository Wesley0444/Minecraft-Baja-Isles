# =============================================================================
#  armed-hotfix.ps1  --  wait for an empty server, then deliver the pending
#                        hotfix in one maintenance window.
# -----------------------------------------------------------------------------
#  WHAT IT DELIVERS
#    1. git push          -- ships the already-committed pack changes
#                            (JEI side=both, Block Pack removed).
#    2. Pages wait        -- blocks until GitHub Pages actually serves the new
#                            manifest. Syncing against a stale manifest reports
#                            SUCCESS and ships nothing; that is the failure that
#                            bit the balance bounce.
#    3. Graceful stop     -- RCON announce -> save-all flush -> stop.
#    4. Archive backup    -- of the quiesced world, before mods/ is touched.
#    5. Config edits      -- ONLY while the server is stopped, so NeoForge
#                            cannot rewrite them from memory on shutdown:
#                              confluence  bloodMoonEventInvertChance 14 -> 65
#                              gateway_of_doom min/maxIntervalSeconds x3
#    6. packwiz sync      -- installs JEI server-side, removes Block Pack.
#    7. Restart           -- via the SYSTEM boot task, which also hands the
#                            server back to SYSTEM and restores max-tick-time.
#
#  WHY ARMED INSTEAD OF RUN-NOW
#    The bounce must not fight another maintenance job. On 2026-09-01 a manual
#    update.bat lost a 21-second race to bake-dims.ps1 and sat spinning with a
#    dead RCON. This script refuses to start if anyone else holds
#    maintenance.lock, and only fires on a confirmed-empty server.
#
#  ORDER MATTERS: push and Pages BOTH happen while the server is still UP, so
#  a failure there leaves a running server and changes nothing.
#
#  RUN ELEVATED. Starting the SYSTEM boot task at the end requires it.
#
#  Watch:  H:\Game Server Backups\Minecraft\armed-hotfix.log
#  Abort:  create H:\Game Server Backups\Minecraft\HOTFIX-ABORT.txt
#  Done:   H:\Game Server Backups\Minecraft\HOTFIX-DONE.txt
# =============================================================================

$ErrorActionPreference = 'Stop'

$SRV        = 'C:\Game Servers\Minecraft'
$LOGDIR     = 'H:\Game Server Backups\Minecraft'
$LOG        = Join-Path $LOGDIR 'armed-hotfix.log'
$ABORT      = Join-Path $LOGDIR 'HOTFIX-ABORT.txt'
$DONE       = Join-Path $LOGDIR 'HOTFIX-DONE.txt'
$LOCK       = Join-Path $SRV 'maintenance.lock'
$PRESENCE   = Join-Path $LOGDIR 'presence.csv'
$BACKUP     = Join-Path $SRV 'backup.ps1'
$JAVA       = 'C:\Program Files\Microsoft\jdk-21.0.4.7-hotspot\bin\java.exe'
$PACK_URL   = 'https://wesley0444.github.io/Minecraft-Baja-Isles/pack/pack.toml'
$TASK       = 'Minecraft Dedicated Server'
$PS         = 'powershell -NoProfile -ExecutionPolicy Bypass'

# how many consecutive empty polls (60s apart) before we fire
$EMPTY_POLLS_REQUIRED = 2
$POLL_SECONDS         = 60
$MAX_WAIT_HOURS       = 48

function Write-Log([string]$level, [string]$msg) {
    $line = '{0}  [{1}]  {2}' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'), $level, $msg
    Add-Content -Path $LOG -Value $line -Encoding utf8
    Write-Host $line
}

# Native exes must NOT be called with a bare `2>&1` under $ErrorActionPreference
# = 'Stop': PS 5.1 wraps every stderr line in a NativeCommandError ErrorRecord and
# THROWS, even when the exe exited 0. git push writes progress to stderr, so the
# 2026-09-01 14:04 run died *after* a successful push, with no log line and a
# maintenance lock left behind. Always go through this helper.
function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out  = & $Exe @Arguments 2>&1 | Out-String
        $code = $LASTEXITCODE
        return [pscustomobject]@{ Code = $code; Out = $out.Trim() }
    } finally { $ErrorActionPreference = $old }
}

function Fail-Out([string]$msg) {
    Write-Log 'FAIL' $msg
    if (Test-Path $LOCK) {
        $owner = (Get-Content $LOCK -Raw -ErrorAction SilentlyContinue)
        if ($owner -match 'armed hotfix') { Remove-Item $LOCK -Force -ErrorAction SilentlyContinue }
    }
    Set-Content -Path $DONE -Encoding utf8 -Value @(
        "armed hotfix FAILED $(Get-Date -f 'yyyy-MM-dd HH:mm:ss')"
        $msg
        "See $LOG"
    )
    exit 1
}

# Any terminating error anywhere below lands here instead of killing the script
# silently. The 14:04 run died mid-window and left maintenance.lock behind with
# no log line explaining why; Fail-Out logs the cause AND releases our lock.
trap {
    Fail-Out ("unhandled error at line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
}

# ---------------------------------------------------------------- 0. preflight
New-Item -ItemType Directory -Force $LOGDIR | Out-Null
Remove-Item $DONE -Force -ErrorAction SilentlyContinue
Write-Log 'INFO' '================ ARMED HOTFIX ================'

$elevated = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Log 'INFO' ("elevated: {0}" -f $elevated)
if (-not $elevated) {
    Write-Log 'WARN' 'NOT elevated -- schtasks /Run will be denied; will fall back to launch.bat (server runs as Wesley until next reboot)'
}

Push-Location $SRV
$ahead = (git rev-list --count '@{u}..HEAD' 2>$null)
Write-Log 'INFO' ("commits to push: {0}" -f $ahead)
if ([string]::IsNullOrWhiteSpace($ahead)) { Fail-Out 'could not read git upstream state' }

# local index hash we must see served by Pages before syncing
$packToml  = Get-Content (Join-Path $SRV 'pack\pack.toml') -Raw
$localHash = ([regex]::Match($packToml, '(?ms)^\[index\].*?^hash\s*=\s*"([0-9a-f]+)"')).Groups[1].Value
if (-not $localHash) { Fail-Out 'could not parse local index hash from pack\pack.toml' }
Write-Log 'INFO' ("local index hash: {0}" -f $localHash)
Pop-Location

# ------------------------------------------------------- 1. wait for empty
$clean = 0
$deadline = (Get-Date).AddHours($MAX_WAIT_HOURS)
Write-Log 'INFO' ("waiting for an empty server ({0} consecutive polls, {1}s apart)" -f $EMPTY_POLLS_REQUIRED, $POLL_SECONDS)

while ($true) {
    if (Test-Path $ABORT) { Write-Log 'INFO' 'abort file present -- standing down, nothing changed'; exit 0 }
    if ((Get-Date) -gt $deadline) { Fail-Out "no empty window within $MAX_WAIT_HOURS hours" }

    # reuse backup.ps1's tested RCON path; it appends a row to presence.csv
    try { & $BACKUP -Mode Presence | Out-Null } catch { }
    $row   = (Get-Content $PRESENCE -Tail 1 -ErrorAction SilentlyContinue)
    $count = -1
    if ($row -match '^[^,]+,(-?\d+),') { $count = [int]$Matches[1] }

    if ($count -eq 0) {
        $clean++
        Write-Log 'INFO' ("empty check {0}/{1}" -f $clean, $EMPTY_POLLS_REQUIRED)
        if ($clean -ge $EMPTY_POLLS_REQUIRED) { break }
    }
    elseif ($count -lt 0) { $clean = 0; Write-Log 'WARN' 'server not answering RCON -- waiting (will not bounce a down server)' }
    else                  { $clean = 0; Write-Log 'INFO' ("{0} player(s) online -- waiting" -f $count) }

    Start-Sleep -Seconds $POLL_SECONDS
}
Write-Log 'INFO' 'server confirmed empty -- starting maintenance window'

# ------------------------------------------------- 2. claim the maintenance lock
if (Test-Path $LOCK) {
    $owner = (Get-Content $LOCK -Raw -ErrorAction SilentlyContinue).Trim()
    Fail-Out "maintenance.lock already held by: '$owner' -- another job owns this window, refusing to race it"
}
Set-Content -Path $LOCK -Encoding utf8 -Value ("armed hotfix {0}" -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'))
Write-Log 'OK' 'maintenance lock claimed'

# ------------------------------- 3. push + Pages (server still UP on purpose)
Push-Location $SRV
$push = Invoke-Native 'git' @('push')
Pop-Location
if ($push.Code -ne 0) { Fail-Out ("git push failed (server untouched): " + $push.Out) }
Write-Log 'OK' ('git push: ' + ($push.Out -replace '\s+', ' '))

Write-Log 'INFO' 'waiting for GitHub Pages to serve the new manifest...'
$served = $false
for ($i = 1; $i -le 40; $i++) {
    try {
        $r = Invoke-WebRequest -Uri $PACK_URL -UseBasicParsing -TimeoutSec 20
        # PS 5.1 returns byte[] for text/plain TOML -- decode explicitly or the
        # regex silently never matches and we "confirm" a stale manifest.
        $body = if ($r.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
        $servedHash = ([regex]::Match($body, '(?ms)^\[index\].*?^hash\s*=\s*"([0-9a-f]+)"')).Groups[1].Value
        if ($servedHash -eq $localHash) { $served = $true; Write-Log 'OK' ("Pages live after ~{0}s" -f ($i*15)); break }
        Write-Log 'INFO' ("[{0}] Pages still stale (served {1}...)" -f $i, $servedHash.Substring(0, [Math]::Min(12, $servedHash.Length)))
    } catch { Write-Log 'WARN' ("Pages fetch failed: {0}" -f $_.Exception.Message) }
    Start-Sleep -Seconds 15
}
if (-not $served) { Fail-Out 'Pages never served the new manifest (server untouched, still running)' }

# ------------------------------------------------------- 4. graceful stop
Write-Log 'INFO' 'announcing 60s warning'
try { & $BACKUP -Mode Announce -Message 'Server restarting for a maintenance update in 60 seconds.' | Out-Null } catch { Write-Log 'WARN' 'announce failed (continuing)' }
Start-Sleep -Seconds 60
Write-Log 'INFO' 'issuing graceful stop'
try { & $BACKUP -Mode Stop | Out-Null } catch { Fail-Out "RCON stop failed: $($_.Exception.Message)" }

# Down = port closed AND no matching java process. BOTH gates on purpose:
# a non-elevated Win32_Process query returns a NULL CommandLine for a
# SYSTEM-owned server, so the process check alone would report a running
# server as DOWN and we would archive + rewrite mods/ underneath it.
# Port state is authoritative regardless of who owns the process.
$gone = $false
for ($i = 1; $i -le 60; $i++) {
    $portOpen = [bool](netstat -an | Select-String ':25565' | Select-String 'LISTENING')
    $srvProc  = Get-CimInstance Win32_Process -Filter "Name='java.exe'" -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandLine -match 'neoforged.neoforge.21\.1\.' -and $_.CommandLine -match 'Xms10G' }
    if (-not $portOpen -and -not $srvProc) { $gone = $true; break }
    Start-Sleep -Seconds 5
}
if (-not $gone) { Fail-Out 'server did not fully stop within 5 minutes (port still listening or process alive) -- NOT killing it, a mid-write world is worse' }
Write-Log 'OK' 'server is down (port closed and process gone)'

# ------------------------------------------------------- 5. archive backup
Write-Log 'INFO' 'archiving the quiesced world'
try { & $BACKUP -Mode Archive | Out-Null; Write-Log 'OK' 'archive done' }
catch { Fail-Out "archive failed -- refusing to touch mods/ without a backup: $($_.Exception.Message)" }

# ------------------------- 6. config edits (server is STOPPED -- the safe window)
$confluence = Join-Path $SRV 'config\confluence-common.toml'
$c = Get-Content $confluence -Raw
$c2 = [regex]::Replace($c, '(bloodMoonEventInvertChance\s*=\s*)\d+', '${1}65')
if ($c2 -eq $c) { Write-Log 'WARN' 'bloodMoonEventInvertChance not matched -- left unchanged' }
else { Set-Content -Path $confluence -Value $c2 -Encoding utf8 -NoNewline; Write-Log 'OK' 'bloodMoonEventInvertChance -> 65 (4x rarer)' }

$god = Join-Path $SRV 'config\gateway_of_doom.json'
$g = Get-Content $god -Raw
$g2 = $g -replace '"minIntervalSeconds"\s*:\s*1800', '"minIntervalSeconds": 5400'
$g2 = $g2 -replace '"maxIntervalSeconds"\s*:\s*3600', '"maxIntervalSeconds": 10800'
if ($g2 -eq $g) { Write-Log 'WARN' 'gateway intervals not matched -- left unchanged' }
else { Set-Content -Path $god -Value $g2 -Encoding utf8 -NoNewline; Write-Log 'OK' 'gateway_of_doom intervals -> 5400/10800 (3x rarer)' }

# verify the edits actually landed on disk
$vc = (Get-Content $confluence -Raw) -match 'bloodMoonEventInvertChance\s*=\s*65'
$vg = ((Get-Content $god -Raw | Select-String -AllMatches '"minIntervalSeconds": 5400').Matches).Count
Write-Log 'INFO' ("verify: bloodmoon=65 {0} | gateway rules at 5400: {1}/3" -f $vc, $vg)

# ------------------------------------------------------- 7. packwiz sync
Write-Log 'INFO' 'syncing mods/ from the packwiz manifest'
Push-Location $SRV
$sync = Invoke-Native $JAVA @('-jar', (Join-Path $SRV 'packwiz-installer-bootstrap.jar'), '-g', '-s', 'server', $PACK_URL)
Pop-Location
Write-Log 'INFO' ('packwiz output: ' + (($sync.Out -replace '\s+', ' ')))
$syncCode = $sync.Code
if ($syncCode -ne 0) {
    Fail-Out "packwiz sync failed (exit $syncCode) -- server left DOWN on purpose; mods/ may be half-updated, do not start it blind"
}
Write-Log 'OK' 'packwiz sync done'

$jei  = @(Get-ChildItem (Join-Path $SRV 'mods') -Filter '*jei*.jar' -ErrorAction SilentlyContinue).Count
$blkp = @(Get-ChildItem (Join-Path $SRV 'mods') -Filter '*bf_blockpack*.jar' -ErrorAction SilentlyContinue).Count
$mods = @(Get-ChildItem (Join-Path $SRV 'mods') -Filter '*.jar').Count
Write-Log 'INFO' ("mods/: {0} jars | JEI present: {1} | Block Pack present: {2}" -f $mods, $jei, $blkp)
if ($jei -eq 0)  { Write-Log 'WARN' 'JEI did NOT land -- the + button and server-truth recipes will still be broken' }
if ($blkp -ne 0) { Write-Log 'WARN' 'Block Pack did NOT get removed' }

# ------------------------------------------------------- 8. restart
Write-Log 'INFO' 'starting the server'
$started = $false
if ($elevated) {
    $run = Invoke-Native 'schtasks' @('/Run', '/TN', $TASK)
    if ($run.Code -eq 0) { $started = $true; Write-Log 'OK' 'started via SYSTEM boot task (ownership back to SYSTEM)' }
    else { Write-Log 'WARN' ("schtasks /Run failed (exit {0}): {1} -- falling back to launch.bat" -f $run.Code, $run.Out) }
}
if (-not $started) {
    Start-Process -FilePath (Join-Path $SRV 'launch.bat') -WorkingDirectory $SRV -WindowStyle Hidden
    Write-Log 'OK' 'started via launch.bat (runs as Wesley; SYSTEM boot task reclaims at next reboot)'
}

$up = $false
for ($i = 1; $i -le 40; $i++) {
    Start-Sleep -Seconds 15
    if ((netstat -an | Select-String ':25565' | Select-String 'LISTENING')) { $up = $true; break }
}
Write-Log ($(if ($up) {'OK'} else {'WARN'})) ("port 25565 listening: {0}" -f $up)

# ------------------------------------------------------- 9. done
Remove-Item $LOCK -Force -ErrorAction SilentlyContinue
Write-Log 'OK' 'maintenance lock cleared'
Set-Content -Path $DONE -Encoding utf8 -Value @(
    "armed hotfix completed $(Get-Date -f 'yyyy-MM-dd HH:mm:ss')"
    "JEI present: $jei | Block Pack present: $blkp | mods: $mods"
    "bloodMoonEventInvertChance=65 verified: $vc | gateway rules at 5400: $vg/3"
    "port 25565 listening: $up"
)
Write-Log 'INFO' '================ ARMED HOTFIX COMPLETE ================'
