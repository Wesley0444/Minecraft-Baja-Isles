# =============================================================================
#  armed-endboss.ps1  --  wait for an empty server, then ship David's 2026-09-15 batch:
#                         Savage Ender Dragon + YUNG's Better End Island (server jars),
#                         the baja-tag-compat datapack, and a fresh Better-End-Island End.
# -----------------------------------------------------------------------------
#  WHAT LANDS (commit on the pack repo; index hash below proves Pages serves it)
#    mods\dragonfight-1.21-4.7.jar                        Savage Ender Dragon (server only)
#    mods\YungsBetterEndIsland-1.21.1-NeoForge-3.1.2.jar  Better End Island   (server only)
#    config\paxi\datapacks\baja-tag-compat                deployed BEFORE arming by
#                                                         datapacks\deploy-datapacks.ps1
#    (client-only, pulled by each Prism launch, no server part: EMF + ETF + Boss Refreshed)
#
#  WHY THE END GETS REGENERATED, AND WHY THAT IS SAFE TODAY
#    Better End Island replaces the main-island worldgen (10 pillars at radius 54 instead of
#    vanilla's 10 at radius 42, bell tower, summon-on-approach dragon). The End was Chunky-
#    baked with VANILLA geometry on 2026-09-01. Adding BEI on top of that leaves both pillar
#    sets standing; YUNG's retrofit (/end_island reset) scars a 23x23x61 box per pillar.
#    But as of 2026-09-15 NOBODY HAS ENTERED THE END: no player holds enter_the_end, every
#    player .dat is in the overworld, DIM1\region has not been written since the bake and
#    level.dat's DragonFight is still unscanned. So the clean route is: park DIM1\region,
#    entities and poi on H:, boot with BEI, re-Chunky r=1000 (the 09-01 bake took 2 min).
#    Test-EndUntouched re-proves those facts at arm time AND after the stop; if anyone has
#    been to the End by then this script REFUSES and nothing is regenerated.
#
#  ORDER: preflight -> wait empty -> snapshot (before the lock) -> lock -> RCON stop -> wait
#  JVM exit -> re-check End untouched -> park End -> packwiz sync -> jar + config gates ->
#  Start bridge (SYSTEM-owned) -> verify (command, datapack, item tags) -> Chunky the End ->
#  save -> endscan.py proves radius-54 pillars on disk -> unlock. Any gate failure before the
#  start aborts with the lock KEPT (and the parked End can be moved back by hand).
#
#  Watch:  H:\Game Server Backups\Minecraft\armed-endboss.log
#  Abort:  create H:\Game Server Backups\Minecraft\ENDBOSS-ABORT.txt
#  Done:   H:\Game Server Backups\Minecraft\ENDBOSS-DONE.txt
#  Run now regardless of players:  -Force   (still refuses a foreign lock)
# =============================================================================
param([switch]$Force)

$ErrorActionPreference = 'Stop'

$SRV     = 'C:\Game Servers\Minecraft'
$LOGDIR  = 'H:\Game Server Backups\Minecraft'
$LOG     = Join-Path $LOGDIR 'armed-endboss.log'
$ABORT   = Join-Path $LOGDIR 'ENDBOSS-ABORT.txt'
$DONE    = Join-Path $LOGDIR 'ENDBOSS-DONE.txt'
$ENDBAK  = Join-Path $LOGDIR ('end-pre-bei-' + (Get-Date -f 'yyyy-MM-dd'))
$LOCK    = Join-Path $SRV 'maintenance.lock'
$MCLOG   = Join-Path $SRV 'logs\latest.log'
$JAVA    = 'C:\Program Files\Microsoft\jdk-21.0.4.7-hotspot\bin\java.exe'
$PY      = 'C:\Program Files\Python313\python.exe'
$BOOT    = Join-Path $SRV 'packwiz-installer-bootstrap.jar'
$SCAN    = Join-Path $SRV 'endscan.py'
$PACKURL = 'https://wesley0444.github.io/Minecraft-Baja-Isles/pack/pack.toml'
$PS      = 'powershell.exe'

# pack.toml's [index] hash after `packwiz refresh` on 2026-09-15 -- proves Pages serves OUR build
$EXPECT_INDEX = '5e28bfcd03a1f6a0e42800998a1b80ddd1201d91ccb07122c44e5965c40c1618'

# jars the sync must produce, sha1 of the exact bytes that booted clean on PregenRig2 2026-09-15
$WANT = @(
    @{ file = 'dragonfight-1.21-4.7.jar';                       sha1 = '9c4b7d0b3568c9cf27668264f0a4d62cd0e002f2' },
    @{ file = 'YungsBetterEndIsland-1.21.1-NeoForge-3.1.2.jar'; sha1 = '832f2c17425debe74a9f267f4136f1a0f0221d19' }
)

# hand-tuned + gitignored: the sync must not touch a single byte of these
$GUARD = @(
    'config\alexscaves-general.toml',
    'config\mowziesmobs-common.toml',
    'config\confluence-common.toml',
    'config\minecolonies-server.toml',
    'config\gravestone-server.toml',
    'config\curios-server.toml',
    'config\servercore\config.yml',
    'config\servercore\optimizations.yml',
    'config\antarchy\antarchy_mobs.toml',
    'server.properties'
)

$END_BAKE_RADIUS      = 1000          # same square the 2026-09-01 bake used (2 min then)
$SPAWN_XYZ            = '0 80 -2944'  # overworld spawn column: spawn chunks are always loaded
$EMPTY_POLLS_REQUIRED = 2
$POLL_SECONDS         = 60
$MAX_WAIT_HOURS       = 48

function Log([string]$level, [string]$msg) {
    $line = '{0}  [{1}]  {2}' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'), $level, $msg
    # A reader holding the log open (a `tail -F`, notepad, a monitor) makes Add-Content throw
    # "being used by another process", and under EAP=Stop that silently KILLED this script's first
    # run 2026-09-15 12:54. Retry instead of dying; the log line is never worth the rollout.
    for ($k = 0; $k -lt 20; $k++) {
        try { Add-Content -Path $LOG -Value $line -Encoding ascii; break } catch { Start-Sleep -Milliseconds 250 }
    }
    Write-Host $line
}
function Fail([string]$msg) {
    Log 'FAIL' $msg
    if (Test-Path $LOCK) { Log 'FAIL' 'lock LEFT IN PLACE -- read the log, fix, then delete maintenance.lock' }
    if (Test-Path (Join-Path $ENDBAK 'DIM1')) { Log 'FAIL' ("the End is PARKED at {0}\DIM1 -- move region/entities/poi back into world\DIM1 before any boot without BEI" -f $ENDBAK) }
    exit 1
}
function Write-NoBom([string]$path, [string]$text) {
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $false))
}
# native exes write progress to stderr; under EAP=Stop that THROWS on exit 0 (proven 2026-09-01).
function Invoke-Native([scriptblock]$sb) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $sb } finally { $ErrorActionPreference = $old }
}

# ---- native RCON client (multi-packet; `return ,$out` is load-bearing -- PS unrolls 1-elem arrays) ----
$props = Get-Content (Join-Path $SRV 'server.properties')
$RCON_PW   = ($props | Where-Object { $_ -like 'rcon.password=*' }) -replace '^rcon\.password=', ''
$RCON_PORT = [int](($props | Where-Object { $_ -like 'rcon.port=*' }) -replace '^rcon\.port=', '')
function Pack([int]$id, [int]$type, [string]$body) {
    $b = [Text.Encoding]::ASCII.GetBytes($body); $len = 4 + 4 + $b.Length + 2
    $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter($ms)
    $w.Write([int32]$len); $w.Write([int32]$id); $w.Write([int32]$type); $w.Write($b); $w.Write([byte]0); $w.Write([byte]0)
    $w.Flush(); return ,$ms.ToArray()
}
function ReadPkt($st) {
    $hdr = New-Object byte[] 4; $n = 0
    while ($n -lt 4) { $r = $st.Read($hdr, $n, 4 - $n); if ($r -le 0) { throw 'eof' }; $n += $r }
    $len = [BitConverter]::ToInt32($hdr, 0); $buf = New-Object byte[] $len; $n = 0
    while ($n -lt $len) { $r = $st.Read($buf, $n, $len - $n); if ($r -le 0) { throw 'eof' }; $n += $r }
    return @{ id = [BitConverter]::ToInt32($buf, 0); body = [Text.Encoding]::UTF8.GetString($buf, 8, $len - 10) }
}
function Invoke-RconOnce([string[]]$cmds, [int]$timeoutMs = 15000) {
    $out = @()
    $c = New-Object Net.Sockets.TcpClient('127.0.0.1', $RCON_PORT); $c.ReceiveTimeout = $timeoutMs; $st = $c.GetStream()
    try {
        $p = Pack 1 3 $RCON_PW; $st.Write($p, 0, $p.Length); $a = ReadPkt $st; if ($a.id -ne 1) { throw 'rcon auth failed' }
        $i = 10
        foreach ($cmd in $cmds) {
            $i++; $p = Pack $i 2 $cmd; $st.Write($p, 0, $p.Length)
            $p2 = Pack ($i + 1000) 2 ''; $st.Write($p2, 0, $p2.Length)
            $body = ''
            while ($true) { $r = ReadPkt $st; if ($r.id -eq ($i + 1000)) { break }; $body += $r.body }
            $out += ($body -replace '\u00a7.', '')
        }
    } finally { $c.Close() }
    return ,$out
}
# This server drops the FIRST rcon connection after a boot ("eof" ~2 ms after connect) -- proven
# 2026-09-04 and 2026-09-08. Never call rcon here without retrying.
function Invoke-Rcon([string[]]$cmds, [int]$timeoutMs = 15000, [int]$tries = 4) {
    for ($a = 1; $a -le $tries; $a++) {
        try { return ,(Invoke-RconOnce $cmds $timeoutMs) }
        catch {
            if ($a -eq $tries) { throw }
            Log 'WARN' "rcon attempt $a/$tries failed ($_) -- retrying"
            Start-Sleep -Seconds 3
        }
    }
}
function Test-Port([int]$port) { return [bool](netstat -an | Select-String ("^\s*TCP\s+0\.0\.0\.0:{0}\s.*LISTENING" -f $port)) }
function Get-PlayerCount {
    try {
        $r = Invoke-RconOnce @('list') 8000
        if ($r[0] -match 'There are (\d+) of a max') { return [int]$Matches[1] }
        return -1
    } catch { return -1 }
}
function Get-ServerPid {
    $line = netstat -ano | Select-String '^\s*TCP\s+0\.0\.0\.0:25565\s.*LISTENING\s+(\d+)' | Select-Object -First 1
    if ($line) { return [int]$line.Matches[0].Groups[1].Value }
    return 0
}
function Hash-Guards {
    $h = @{}
    foreach ($rel in $GUARD) {
        $p = Join-Path $SRV $rel
        if (Test-Path $p) { $h[$rel] = (Get-FileHash $p -Algorithm SHA256).Hash } else { $h[$rel] = 'MISSING' }
    }
    return $h
}
# The whole End-regen premise, re-proven from disk every time it matters.
function Test-EndUntouched([string]$why) {
    foreach ($f in Get-ChildItem (Join-Path $SRV 'world\advancements') -Filter *.json) {
        $j = Get-Content $f.FullName -Raw | ConvertFrom-Json
        foreach ($k in @('minecraft:story/enter_the_end', 'minecraft:end/root')) {
            $a = $j.$k
            if ($a -and $a.done) { Fail ("{0}: {1} has {2} done -- the End HAS been visited; a regen would destroy it. Stop, use YUNG's /end_island reset route instead." -f $why, $f.BaseName, $k) }
        }
    }
    $reg = Join-Path $SRV 'world\DIM1\region'
    if (-not (Test-Path $reg)) { Fail "$why : world\DIM1\region is missing -- is the End already parked?" }
    $newest = (Get-ChildItem $reg -Filter *.mca | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
    if ($newest -gt [datetime]'2026-09-02') { Fail ("{0}: DIM1\region newest mtime {1} is after the 2026-09-01 bake -- something loaded the End; not regenerating blind" -f $why, $newest) }
    Log 'OK' ("{0}: End untouched (no enter_the_end advancement; DIM1\region newest write {1})" -f $why, $newest)
}
# item-tag proof without a player: an armor stand in the spawn chunks holds the item,
# `execute if items` answers "Test passed" / "Test failed" from the SERVER's tag registry.
function Test-Tag([string]$item, [string]$tag) {
    $r = Invoke-Rcon @(
        "item replace entity @e[tag=bajacheck,limit=1] weapon.mainhand with $item",
        "execute if items entity @e[tag=bajacheck,limit=1] weapon.mainhand $tag") 15000
    return [bool]($r[1] -match 'Test passed')
}

# ---- preflight (nothing is touched until every one of these passes) ----
New-Item -ItemType Directory -Force $LOGDIR | Out-Null
Log 'INFO' '==== ARMED ENDBOSS start ===='

foreach ($f in @($JAVA, $PY, $BOOT, $SCAN)) { if (-not (Test-Path $f)) { Fail "missing: $f" } }
foreach ($w in $WANT) {
    if (Test-Path (Join-Path $SRV ('mods\' + $w.file))) { Fail ("{0} already in mods\ -- was this already shipped?" -f $w.file) }
}
if (-not (Test-Path (Join-Path $SRV 'config\paxi\datapacks\baja-tag-compat\pack.mcmeta'))) { Fail 'baja-tag-compat is not deployed to config\paxi\datapacks -- run datapacks\deploy-datapacks.ps1 first' }
if ((Get-Content (Join-Path $SRV 'config\paxi\datapack_load_order.json') -Raw) -notmatch 'baja-tag-compat') { Fail 'baja-tag-compat missing from Paxi load order -- run datapacks\deploy-datapacks.ps1 first' }
if (Test-Path (Join-Path $ENDBAK 'DIM1')) { Fail "$ENDBAK\DIM1 already exists -- a previous run parked the End? sort that out first" }

$served = ''
try {
    $resp = Invoke-WebRequest -Uri ($PACKURL + '?cb=' + (Get-Random)) -UseBasicParsing -TimeoutSec 30
    $served = [Text.Encoding]::UTF8.GetString($resp.Content)
} catch { Fail "could not fetch $PACKURL : $_" }
if ($served -notmatch [regex]::Escape($EXPECT_INDEX)) {
    Fail "Pages is not serving index hash $EXPECT_INDEX yet -- push landed? (got: $(($served -split "`n" | Select-String 'hash =') -join ' | '))"
}
Log 'OK' "Pages serves the expected index hash $($EXPECT_INDEX.Substring(0,16))..."

if (Test-Path $LOCK) {
    $age = (Get-Date) - (Get-Item $LOCK).LastWriteTime
    if ($age.TotalMinutes -lt 45) { Fail ("another job holds maintenance.lock ({0:N0} min old) -- not racing it" -f $age.TotalMinutes) }
    Log 'WARN' ("stale maintenance.lock ({0:N0} min) -- taking it over" -f $age.TotalMinutes)
}
if (Test-Path $ABORT) { Remove-Item $ABORT -Force }
if (Test-Path $DONE)  { Remove-Item $DONE -Force }
Test-EndUntouched 'arm-time'

# ---- wait for an empty server ----
$deadline = (Get-Date).AddHours($MAX_WAIT_HOURS)
$empty = 0
if ($Force) { Log 'INFO' '-Force: skipping the empty-server wait' }
while (-not $Force) {
    if (Test-Path $ABORT) { Log 'INFO' 'ABORT file seen -- exiting, nothing changed'; exit 0 }
    if ((Get-Date) -gt $deadline) { Fail 'gave up waiting for an empty server' }
    $n = Get-PlayerCount
    if ($n -eq 0) { $empty++; Log 'INFO' "empty poll $empty/$EMPTY_POLLS_REQUIRED" }
    elseif ($n -lt 0) { $empty = 0; Log 'WARN' 'RCON unreachable -- server down? not firing on a down server' }
    else { $empty = 0; Log 'INFO' "$n player(s) online -- waiting" }
    if ($empty -ge $EMPTY_POLLS_REQUIRED) { break }
    Start-Sleep -Seconds $POLL_SECONDS
}
if (-not (Test-Port 25565)) { Fail 'port 25565 not listening -- refusing to fire on a down server' }

# ---- 1. snapshot (BEFORE the lock; backup.ps1 -Mode Snapshot SKIPs under one) ----
Log 'INFO' 'snapshot: backup.ps1 -Mode Snapshot'
$snap = Start-Process -FilePath $PS -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f (Join-Path $SRV 'backup.ps1')), '-Mode', 'Snapshot') -Wait -PassThru -NoNewWindow
Log 'INFO' "snapshot exit $($snap.ExitCode)"
$blog = Get-Content (Join-Path $LOGDIR 'backup.log') -Tail 1
Log 'INFO' "backup.log: $blog"
if ($blog -notmatch '\[OK\]') { Fail 'snapshot did not log [OK]' }

# ---- 2. lock + graceful stop ----
Write-NoBom $LOCK ("armed-endboss {0}" -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'))
$pid0 = Get-ServerPid
Log 'INFO' "lock written; server pid $pid0; announcing + stopping"
try { Invoke-Rcon @('say [maintenance] restarting in 15 s -- new dragon fight + a rebuilt End island (nobody has been there yet), modded bows/swords now reforge, Epic Knights shields now enchant', 'save-all') 30000 | Out-Null }
catch { Log 'WARN' "announce failed: $_" }
Start-Sleep -Seconds 15

$t0 = Get-Date; $stopping = $false
for ($try = 1; $try -le 5 -and -not $stopping; $try++) {
    try { Invoke-Rcon @('stop') 5000 | Out-Null } catch { Log 'INFO' "stop attempt $try : connection closed ($_)" }
    Start-Sleep -Seconds 4
    $stopping = [bool](Get-Content $MCLOG -ErrorAction SilentlyContinue | Select-String 'Stopping server' |
                       Where-Object { $_.Line -match ('\[' + (Get-Date -f 'ddMMMyyyy')) } | Select-Object -Last 1)
    if (-not $stopping -and -not (Test-Port 25565)) { $stopping = $true }
}
if (-not $stopping) { Fail 'server never logged "Stopping server" after 5 stop attempts' }
Log 'INFO' 'server acknowledged stop'
while (((Get-Date) - $t0).TotalSeconds -lt 180) {
    $alive = ($pid0 -gt 0) -and (Get-Process -Id $pid0 -ErrorAction SilentlyContinue)
    if (-not (Test-Port 25565) -and -not $alive) { break }
    Start-Sleep -Seconds 2
}
if ((Test-Port 25565) -or (($pid0 -gt 0) -and (Get-Process -Id $pid0 -ErrorAction SilentlyContinue))) {
    Fail 'server did not exit within 180 s after stop (kill the pid by hand)'
}
Log 'OK' ("server exited in {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds)
Start-Sleep -Seconds 3

# ---- 3. park the never-visited End (region + entities + poi; DIM1\data stays) ----
Test-EndUntouched 'post-stop'
New-Item -ItemType Directory -Force (Join-Path $ENDBAK 'DIM1') | Out-Null
foreach ($sub in @('region', 'entities', 'poi')) {
    $from = Join-Path $SRV ('world\DIM1\' + $sub)
    if (-not (Test-Path $from)) { Log 'WARN' "world\DIM1\$sub absent -- nothing to park"; continue }
    $to = Join-Path $ENDBAK ('DIM1\' + $sub)
    Move-Item -Path $from -Destination $to
    if (Test-Path $from) { Fail "world\DIM1\$sub still present after Move-Item" }
    Log 'OK' ("parked world\DIM1\{0} -> {1} ({2} files)" -f $sub, $to, (Get-ChildItem $to -File).Count)
}

# ---- 4. packwiz sync ----
$before = Hash-Guards
$jarsBefore = (Get-ChildItem (Join-Path $SRV 'mods') -Filter *.jar).Count
Log 'INFO' "syncing pack ($jarsBefore jars before)"
Push-Location $SRV
try {
    Invoke-Native { & $JAVA -jar $BOOT -g -s server $PACKURL } | ForEach-Object { Log 'PACKWIZ' $_ }
    $rc = $LASTEXITCODE
} finally { Pop-Location }
if ($rc -ne 0) { Fail "packwiz-installer exit $rc -- server NOT restarted" }
Log 'OK' 'packwiz sync exit 0'

# ---- 5. gates: the jars the rig booted, and nothing else moved ----
foreach ($w in $WANT) {
    $p = Join-Path $SRV ('mods\' + $w.file)
    if (-not (Test-Path $p)) { Fail ("sync did not deliver mods\{0}" -f $w.file) }
    $got = (Get-FileHash $p -Algorithm SHA1).Hash.ToLower()
    if ($got -ne $w.sha1) { Fail ("{0} sha1 {1} != expected {2}" -f $w.file, $got, $w.sha1) }
    Log 'OK' ("delivered {0} sha1 {1}" -f $w.file, $got)
}
$after = Hash-Guards
$drift = @($GUARD | Where-Object { $before[$_] -ne $after[$_] })
if ($drift.Count -gt 0) { Fail ("sync altered hand-tuned config(s): {0}" -f ($drift -join ', ')) }
Log 'OK' ("{0} hand-tuned configs byte-identical after sync" -f $GUARD.Count)
$jarsAfter = (Get-ChildItem (Join-Path $SRV 'mods') -Filter *.jar).Count
Log 'INFO' "mods\: $jarsBefore -> $jarsAfter jars"
if ($jarsAfter -ne ($jarsBefore + 2)) { Log 'WARN' "expected +2 jars, got $($jarsAfter - $jarsBefore) -- check the PACKWIZ lines above" }

# ---- 6. start via the bridge (SYSTEM-owned) ----
& schtasks /Run /TN 'Minecraft Start' | Out-Null
Log 'INFO' 'Minecraft Start bridge fired; waiting for Done'
$t0 = Get-Date; $done = $false; $tail = $null
while (((Get-Date) - $t0).TotalSeconds -lt 900) {
    Start-Sleep -Seconds 5
    if (Test-Path $MCLOG) {
        $tail = Get-Content $MCLOG -ErrorAction SilentlyContinue
        if ($tail -and (($tail | Select-String 'Done \(' | Measure-Object).Count -gt 0) -and ((Get-Item $MCLOG).LastWriteTime -gt $t0)) { $done = $true; break }
    }
}
if (-not $done) { Fail 'no "Done (" in latest.log within 15 min -- BEI mixins are required:true, a failed target ABORTS the boot; read latest.log' }
Log 'OK' ("server up: {0}" -f (($tail | Select-String 'Done \(' | Select-Object -Last 1).Line -replace '.*\]: ', ''))

# ---- 7. verify: mods answer, datapack listed, tags resolve, no new ERRORs ----
Start-Sleep -Seconds 10
$v = Invoke-Rcon @('list', 'neoforge tps', 'help end_island', 'datapack list') 20000
Log 'INFO' "list: $($v[0])"
Log 'INFO' ("tps: {0}" -f (($v[1] -split "`n") | Select-String 'Overall' | Select-Object -First 1))
if ($v[2] -notmatch 'end_island reset') { Fail "Better End Island command missing: '$($v[2])'" }
Log 'OK' 'Better End Island answers: /end_island reset present'
if ($v[3] -notmatch 'baja-tag-compat \(paxi\)') { Fail 'baja-tag-compat (paxi) not in datapack list' }
Log 'OK' 'baja-tag-compat (paxi) enabled'

# BEI's first boot logs "key missing: bei_ExtraDragonFight in {<the ENTIRE level.dat as text>}" at ERROR
# level -- one 2.9 MB line on 2026-09-15. Regex-matching that line wedged this gate at 100 % of a core
# for 10 min (a sibling session had to kill the run and finish by hand). Skip giant lines, and treat
# that specific first-boot line as known-benign (BEI writes the key on the next save).
$errLines = $tail | Where-Object { $_.Length -lt 4000 -and $_ -match '/ERROR\]|/FATAL\]' }
$huge = @($tail | Where-Object { $_.Length -ge 4000 })
foreach ($h in $huge) { Log 'INFO' ("skipped a {0:N0}-byte log line in the ERROR gate: {1}..." -f $h.Length, $h.Substring(0, [Math]::Min(120, $h.Length))) }
$bad = $errLines | Where-Object { $_ -match 'dragonfight|betterendisland|end_island|[Mm]ixin|baja-tag|c:tools/shield|c:tools/ranged_weapon|enchantable/durability|prefix_melee_only' -and $_ -notmatch 'key missing: bei_ExtraDragonFight' }
if ($bad) {
    # `-replace '.*\]: '` is quadratic on a long line (greedy .* then backtrack per position): on the
    # 2.9 MB BEI line that was ~4e12 regex steps = the 16:45 wedge. Truncate FIRST, then strip the
    # timestamp/thread/logger prefix with an anchored, bounded pattern.
    foreach ($b in $bad) {
        $s = [string]$b; $s = $s.Substring(0, [Math]::Min(300, $s.Length))
        Log 'FAIL' ("boot log: {0}" -f ($s -replace '^\[[^\]]{1,40}\] \[[^\]]{1,80}\] \[[^\]]{1,120}\]: ', ''))
    }
    Fail ("{0} ERROR/FATAL line(s) mentioning the new mods, our tags or mixins" -f @($bad).Count)
}
Log 'OK' 'no dragonfight/betterendisland/tag/mixin ERROR or FATAL lines in the boot log'

Invoke-Rcon @("summon minecraft:armor_stand $SPAWN_XYZ {Tags:[`"bajacheck`"],NoGravity:1b,Invisible:1b}") 15000 | Out-Null
$checks = @(
    @{ item = 'magistuarmory:iron_kiteshield';   tag = '#c:tools/shield';                  want = $true },
    @{ item = 'magistuarmory:iron_kiteshield';   tag = '#minecraft:enchantable/durability'; want = $true },
    @{ item = 'simplybows:vine_bow/vine_bow';    tag = '#confluence:prefix_ranged_only';    want = $true },
    @{ item = 'magistuarmory:longbow';           tag = '#confluence:prefix_ranged_only';    want = $true },
    @{ item = 'simplyswords:iron_longsword';     tag = '#confluence:prefix_melee_only';     want = $true },
    @{ item = 'mowziesmobs:spear';               tag = '#confluence:prefix_melee_only';     want = $true },
    @{ item = 'minecraft:stick';                 tag = '#c:tools/shield';                   want = $false }   # control
)
$tagFail = 0
foreach ($c in $checks) {
    $got = Test-Tag $c.item $c.tag
    $ok = ($got -eq $c.want)
    if (-not $ok) { $tagFail++ }
    Log $(if ($ok) { 'OK' } else { 'FAIL' }) ("tag check {0} in {1}: {2} (expected {3})" -f $c.item, $c.tag, $got, $c.want)
}
Invoke-Rcon @('kill @e[tag=bajacheck]') 15000 | Out-Null
if ($tagFail -gt 0) { Fail "$tagFail item-tag check(s) failed -- datapack not live?" }

$sedCfg = @(Get-ChildItem (Join-Path $SRV 'config') -Filter 'dragonfight*' -ErrorAction SilentlyContinue)
if ($sedCfg.Count -gt 0) { Log 'OK' ("Savage Ender Dragon config generated: {0} (defaults; tune dragonDifficulty / antiflightAbility there)" -f ($sedCfg.Name -join ', ')) }
else { Log 'WARN' 'no dragonfight* file in config\ -- Cupboard writes it on first tick; check later' }

# ---- 8. re-bake the End with Better End Island active ----
$esc = [regex]::Escape('minecraft:the_end')
$finBefore = (Select-String -Path $MCLOG -Pattern "Task finished for $esc" -AllMatches | Measure-Object).Count
$r = Invoke-Rcon @('chunky world minecraft:the_end') 15000
if ($r[0] -notmatch 'World changed') { Fail ("chunky world rejected: {0}" -f ($r -join ' | ')) }
Invoke-Rcon @('chunky center 0 0', 'chunky shape square', "chunky radius $END_BAKE_RADIUS", 'chunky quiet 60', 'chunky start') 15000 | Out-Null
Log 'INFO' "End bake started: square r=$END_BAKE_RADIUS at 0,0"
$t0 = Get-Date; $fin = $false; $loops = 0
while (((Get-Date) - $t0).TotalMinutes -lt 45) {
    Start-Sleep -Seconds 30; $loops++
    $finNow = (Select-String -Path $MCLOG -Pattern "Task finished for $esc" -AllMatches | Measure-Object).Count
    if ($finNow -gt $finBefore) { $fin = $true; break }
    if ($loops % 4 -eq 0) {
        # Chunky chunks on this modset never reach disk without a save (doc 07). flush only on an
        # empty server -- `save-all flush` with players on was the 2026-09-04 self-inflicted crash.
        $n = Get-PlayerCount
        try { Invoke-Rcon @($(if ($n -eq 0) { 'save-all flush' } else { 'save-all' })) 120000 | Out-Null } catch { Log 'WARN' "save failed: $_" }
        $prog = Get-Content $MCLOG | Select-String 'Task running for minecraft:the_end' | Select-Object -Last 1
        if ($prog) { Log 'INFO' ($prog.Line -replace '.*\]: ', '') }
    }
}
if (-not $fin) { Fail 'End bake did not finish within 45 min -- check chunky progress by hand; server is UP and mods are LIVE, only the geometry proof is missing' }
Log 'OK' ("End bake finished in {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds)
$n = Get-PlayerCount
try { Invoke-Rcon @($(if ($n -eq 0) { 'save-all flush' } else { 'save-all' })) 120000 | Out-Null } catch { Log 'WARN' "post-bake save failed: $_" }
Start-Sleep -Seconds 20

# ---- 9. prove the geometry on disk: BEI pillars at r=54, no vanilla ring at r=42 ----
$scanOut = Invoke-Native { & $PY $SCAN (Join-Path $SRV 'world\DIM1\region') 2>&1 }
foreach ($l in $scanOut) { Log 'SCAN' $l }
$res = ($scanOut | Select-String '^RESULT ' | Select-Object -Last 1)
if (-not $res) { Log 'WARN' 'endscan.py printed no RESULT line -- verify the End by hand' }
elseif ($res.Line -match 'vanilla42=(\d+) bei54=(\d+)') {
    $v42 = [int]$Matches[1]; $b54 = [int]$Matches[2]
    if ($v42 -eq 0 -and $b54 -ge 300) { Log 'OK' "End geometry is Better End Island's: 0 obsidian columns at r=42, $b54 at r=54 (rig reference: 0 / 717)" }
    else { Log 'WARN' "End geometry unexpected: vanilla42=$v42 bei54=$b54 (rig reference 0 / 717; live vanilla was 322 / 0) -- inspect before anyone enters" }
}

# ---- 10. unlock + done ----
Remove-Item $LOCK -Force
Write-NoBom $DONE (@(
    ("armed-endboss done {0}" -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss')),
    "dragonfight-1.21-4.7.jar                       sha1 9c4b7d0b3568c9cf27668264f0a4d62cd0e002f2",
    "YungsBetterEndIsland-1.21.1-NeoForge-3.1.2.jar sha1 832f2c17425debe74a9f267f4136f1a0f0221d19",
    "baja-tag-compat datapack live (Confluence melee/ranged prefixes on modded weapons; EK shields enchantable)",
    ("old vanilla End parked at {0}\DIM1 (region/entities/poi) -- delete once the new End is blessed" -f $ENDBAK),
    "pack index $EXPECT_INDEX",
    "Clients: EMF + ETF + Boss Refreshed are client-only and arrive on the next Prism launch; joining without them works.",
    "Smoke test: enter the End (bell tower at 0,0, pillars at radius 54, dragon summons when you approach the centre);",
    "reforge a Simply Swords sword / Simply Bows bow at the Goblin Tinkerer; put Unbreaking on an Epic Knights shield."
) -join "`r`n")
Log 'OK' '==== ARMED ENDBOSS DONE -- lock cleared ===='
exit 0
