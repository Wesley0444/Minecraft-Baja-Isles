<#
=============================================================================
 watchdog.ps1  --  Minecraft "Baja Isles" : crash watchdog + SYSTEM start bridge
-----------------------------------------------------------------------------
 WHAT IT DOES

   -Mode Watch   (task 'Minecraft Watchdog', every 3 min, Wesley / S4U / Highest)
       One health check per run.
         server process gone                          => relaunch via SYSTEM boot task
         process alive, RCON dead 3 runs in a row     => kill it, relaunch (hung)
         anything else                                => heartbeat, exit
       Stands down for maintenance.lock, a booting server, and a crash loop.

   -Mode Start   (task 'Minecraft Start', NO trigger, Wesley / S4U / Highest)
       THE BRIDGE. Makes sure the server is running UNDER THE SYSTEM BOOT TASK.
       Fire it from ANY shell, elevated or not:
             schtasks /Run /TN "Minecraft Start"          (or start.bat)
       Works non-elevated because Wesley owns the task; the task itself runs
       elevated, so it can Start-ScheduledTask the SYSTEM task. Ignores the
       lock / cooldown / loop guard -- a human or a script asked for it.

   -DryRun       probe, log the verdict, touch nothing. Also the FORCED
                 behaviour when not elevated (below). Safe to run any time.

 WHY IT EXISTS (2026-09-03)
   * 02:08 the server died (ServerHangWatchdog -> JVM exit, Antarchy ant
     teleport) and stayed dead 4 h. Nothing was watching: the SYSTEM boot
     task fires only at boot, and this box reboots about every 6 weeks.
   * Every non-elevated Claude session that restarted the server did it with
     a detached launch.bat -- "runs as Wesley; SYSTEM reclaims at next
     reboot", i.e. effectively never. The Start bridge ends that pattern.

 WHY IT IS BUILT THIS WAY
   * Runs as WESLEY (S4U, RunLevel Highest), NOT as SYSTEM like Palworld's.
     `schtasks /Run` from a non-elevated shell is allowed on a task you own
     (proven on the Discord bot task) and DENIED on a SYSTEM task. S4U = runs
     logged-on or not, no stored password (Wesley's account has none).
     RunLevel Highest = elevated token: sees SYSTEM processes' command lines,
     may Start-ScheduledTask the SYSTEM boot task.
   * NOT ELEVATED => OBSERVE ONLY. Non-elevated, Win32_Process hands back a
     NULL CommandLine for a SYSTEM-owned server (CLAUDE.md's recurring trap),
     so "process gone" would be a lie -- and the only relaunch available
     would be the detached-as-Wesley one this script exists to kill.
   * Server process = java.exe whose command line contains THIS folder's
     libraries\ path. NOT 'neoforge': Wesley's CLIENT is NeoForge java on
     this same box. Port 25565's owning PID is the cross-check.
   * Relaunch = Start-ScheduledTask 'Minecraft Dedicated Server', so the
     server always comes back as SYSTEM. launch.bat directly is a last
     resort, logged loudly, only if that task is missing.
   * maintenance.lock => stand down while it is < 45 min old. Longer than
     backup.ps1's 10 min ON PURPOSE: relaunching into a half-done packwiz
     sync or world import corrupts things; a stale lock from a dead script
     only costs downtime. Long maintenance windows should touch the lock.
   * Crash-loop guard: > 3 relaunches / 60 min => Watchdog\halt.flag and go
     dormant. Hammer-restarting a crash-on-boot server shreds the world.
     Delete halt.flag to re-arm.
   * Every DOWN / HUNG / HALT writes Watchdog\incidents\*.json (newest crash
     report, latest.log tail, RAM, top processes) so "why" is answerable.
   * The SYSTEM boot task also has Task Scheduler's own restart-on-failure
     (3 x 5 min) -- a free extra layer once the server runs under it. Not
     relied upon; not counted by the loop guard.

 OPERATING
   start the server (any shell) : schtasks /Run /TN "Minecraft Start"
   watch it think               : Watchdog\watchdog.log, Watchdog\heartbeat.txt
   why did it die               : Watchdog\incidents\
   re-arm after a crash loop    : del Watchdog\halt.flag
   register the tasks           : admin_setup.bat (as admin, once)
=============================================================================
#>
[CmdletBinding()]
param(
  [ValidateSet('Watch','Start')] [string]$Mode = 'Watch',
  [switch]$DryRun
)
# A watchdog must never die on a probe; every failure path is handled explicitly.
$ErrorActionPreference = 'SilentlyContinue'

# --- configuration -----------------------------------------------------------
$SRV        = 'C:\Game Servers\Minecraft'
$TASK       = 'Minecraft Dedicated Server'
$WD         = Join-Path $SRV 'Watchdog'
$INCIDENTS  = Join-Path $WD 'incidents'
$LOCK       = Join-Path $SRV 'maintenance.lock'
$LOG        = Join-Path $WD 'watchdog.log'
$HEARTBEAT  = Join-Path $WD 'heartbeat.txt'
$RESTARTS   = Join-Path $WD 'restarts.log'
$HALT       = Join-Path $WD 'halt.flag'
$STATE      = Join-Path $WD 'state.json'
$GAME_PORT  = 25565
$RCON_HOST  = '127.0.0.1'
$RCON_PORT  = 25575

$BOOT_GRACE_MIN   = 5    # a process younger than this is booting -- never judged (boot measured ~30 s)
$HUNG_STRIKES     = 3    # consecutive RCON failures on a mature process => hung (3 x 3 min = 9 min)
$LOCK_STALE_MIN   = 45   # see header -- deliberately longer than backup.ps1's 10
$LOOP_WINDOW_MIN  = 60
$LOOP_MAX         = 3
$START_VERIFY_SEC = 90

New-Item -ItemType Directory -Force -Path $WD, $INCIDENTS | Out-Null
$now   = Get-Date
$stamp = $now.ToString('yyyy-MM-dd HH:mm:ss')

function Write-Log { param([string]$Status,[string]$Text)
  $line = '{0}  [{1}]  {2}' -f $stamp, $Status, $Text
  Write-Host $line
  Add-Content -Path $LOG -Value $line -Encoding utf8
}
function Set-Beat { param([string]$s) ('{0}  {1}' -f $stamp, $s) | Set-Content -LiteralPath $HEARTBEAT }

$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $elevated -and -not $DryRun) {
  $DryRun = $true
  Write-Log 'WARN' 'not elevated -- forced to -DryRun (cannot see SYSTEM processes, will not launch as Wesley). Use: schtasks /Run /TN "Minecraft Start"'
}

# --- state -------------------------------------------------------------------
function Get-State {
  $s = $null
  if (Test-Path $STATE) { try { $s = Get-Content $STATE -Raw | ConvertFrom-Json } catch {} }
  if (-not $s) { $s = [pscustomobject]@{ last = 'UNKNOWN'; strikes = 0 } }
  return $s
}
function Save-State { param($s) ($s | ConvertTo-Json -Compress) | Set-Content -LiteralPath $STATE }

# --- minimal RCON client (same protocol impl as backup.ps1, incl. the ,$out unroll guard)
function Get-RconPassword {
  $m = Select-String -Path (Join-Path $SRV 'server.properties') -Pattern '^rcon\.password=(.*)$'
  if (-not $m) { throw 'rcon.password not found' }
  $p = $m.Matches[0].Groups[1].Value
  if ([string]::IsNullOrWhiteSpace($p)) { throw 'rcon.password is empty' }
  return $p
}
function Invoke-Rcon {
  param([string[]]$Commands,[int]$TimeoutMs = 8000)
  $pw = Get-RconPassword
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $iar = $client.BeginConnect($RCON_HOST,$RCON_PORT,$null,$null)
    if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) { throw 'RCON connect timeout' }
    $client.EndConnect($iar)
    $s = $client.GetStream(); $s.ReadTimeout = $TimeoutMs; $s.WriteTimeout = $TimeoutMs
    function Send-Packet($id,$type,$body) {
      $b  = [Text.Encoding]::ASCII.GetBytes($body)
      $ms = New-Object IO.MemoryStream; $bw = New-Object IO.BinaryWriter($ms)
      $bw.Write([int](4 + 4 + $b.Length + 2)); $bw.Write([int]$id); $bw.Write([int]$type)
      $bw.Write($b); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Flush()
      $out = $ms.ToArray(); $s.Write($out,0,$out.Length); $s.Flush()
    }
    function Read-Packet {
      $hdr = New-Object byte[] 4; $n = 0
      while ($n -lt 4) { $r = $s.Read($hdr,$n,4-$n); if ($r -le 0) { throw 'RCON closed' }; $n += $r }
      $len = [BitConverter]::ToInt32($hdr,0)
      $buf = New-Object byte[] $len; $n = 0
      while ($n -lt $len) { $r = $s.Read($buf,$n,$len-$n); if ($r -le 0) { throw 'RCON closed' }; $n += $r }
      [pscustomobject]@{ Id = [BitConverter]::ToInt32($buf,0); Type = [BitConverter]::ToInt32($buf,4)
                         Body = [Text.Encoding]::ASCII.GetString($buf,8,$len-10) }
    }
    Send-Packet 1 3 $pw
    $auth = Read-Packet
    if ($auth.Type -ne 2) { $auth = Read-Packet }
    if ($auth.Id -eq -1)  { throw 'RCON auth failed' }
    $results = @(); $i = 2
    foreach ($c in $Commands) { Send-Packet $i 2 $c; $results += (Read-Packet).Body; $i++ }
    return ,$results
  } finally { $client.Close() }
}
# Returns the `list` line on success, $null on any failure. Never throws.
function Probe-Rcon {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Stop'
  try { return (Invoke-Rcon -Commands @('list') -TimeoutMs 6000)[0] } catch { return $null } finally { $ErrorActionPreference = $old }
}

# --- process / port discovery -----------------------------------------------
# Server java = command line contains THIS folder's libraries path (never 'neoforge'
# alone -- Wesley's client is NeoForge java too). Non-elevated callers see NULL
# CommandLine for a SYSTEM server, which is why they are forced to -DryRun above.
function Get-ServerProcs {
  $p = @(Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
         Where-Object { $_.CommandLine -and $_.CommandLine -like '*Game Servers\Minecraft\libraries*' })
  return ,$p
}
function Get-PortOwnerPid {
  $c = Get-NetTCPConnection -LocalPort $GAME_PORT -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($c) { return [int]$c.OwningProcess } else { return 0 }
}
function Get-ProcOwner { param([int]$Id)
  try { $p = Get-Process -Id $Id -IncludeUserName -ErrorAction Stop; return $p.UserName } catch { return '?' }
}

# One snapshot of everything the verdict needs.
function Get-Health {
  $procs   = Get-ServerProcs
  $portPid = Get-PortOwnerPid
  $pids    = @($procs | ForEach-Object { [int]$_.ProcessId })
  if ($portPid -and ($pids -notcontains $portPid)) { $pids += $portPid }
  $present = ($pids.Count -gt 0)
  $ageMin  = $null
  if ($present) {
    $starts = @()
    foreach ($id in $pids) { $gp = Get-Process -Id $id -ErrorAction SilentlyContinue; if ($gp -and $gp.StartTime) { $starts += $gp.StartTime } }
    if ($starts.Count) { $ageMin = [math]::Round(($now - ($starts | Sort-Object | Select-Object -First 1)).TotalMinutes, 1) }
  }
  $rcon = Probe-Rcon
  $players = $null
  if ($rcon -and $rcon -match 'There are (\d+) of a max of \d+ players online') { $players = [int]$Matches[1] }
  [pscustomobject]@{
    Pids = $pids; PortPid = $portPid; Present = $present; AgeMin = $ageMin
    RconOk = [bool]$rcon; Players = $players; Owner = $(if ($pids.Count) { Get-ProcOwner $pids[0] } else { '' })
  }
}

# --- the relaunch ------------------------------------------------------------
# Via the SYSTEM boot task, so ownership is right. Returns $true if a server
# process showed up within $START_VERIFY_SEC.
function Start-ServerViaTask { param([string]$Reason)
  $t = Get-ScheduledTask -TaskName $TASK -ErrorAction SilentlyContinue
  if (-not $t) {
    # Only reachable if the boot task was never registered / got deleted.
    Write-Log 'WARN' "task '$TASK' NOT FOUND (run admin_setup.bat) -- LAST RESORT: launching launch.bat directly (server will run as this task's user, not SYSTEM)"
    Start-Process -FilePath (Join-Path $SRV 'launch.bat') -WorkingDirectory $SRV -WindowStyle Hidden
  } else {
    if ($t.State -eq 'Running') {
      # The wrapper cmd.exe is alive but java is not (or is hung and we just killed it).
      Write-Log 'INFO' "task '$TASK' shows Running with no healthy server -- ending it first"
      Stop-ScheduledTask -TaskName $TASK -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 3
    }
    Start-ScheduledTask -TaskName $TASK -ErrorAction SilentlyContinue
    Write-Log 'OK' "Start-ScheduledTask '$TASK' issued ($Reason)"
  }
  $now.ToString('yyyy-MM-dd HH:mm:ss') | Add-Content -LiteralPath $RESTARTS

  $deadline = (Get-Date).AddSeconds($START_VERIFY_SEC)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    $p = Get-ServerProcs
    if ($p.Count) {
      Write-Log 'OK' ("server process up: pid {0} owner {1}" -f $p[0].ProcessId, (Get-ProcOwner ([int]$p[0].ProcessId)))
      return $true
    }
  }
  Write-Log 'FAIL' "no server process within $START_VERIFY_SEC s of starting the task -- check launch.bat / logs\latest.log"
  return $false
}

# Get-Content hangs PSPath/PSDrive/PSProvider note properties on every string it
# returns and ConvertTo-Json serialises all of them: ~2.2 MB PER LOG LINE, which
# made every incident file 50-199 MB and 95 s to write (found 2026-09-18).
# "$_" builds a plain string; the cap guards against one giant line (a 2.9 MB
# log line exists in this pack -- see armed-endboss).
function Get-PlainLines { param([string]$Path,[int]$Tail = 0,[int]$Head = 0)
  $a = @{ LiteralPath = $Path; ErrorAction = 'SilentlyContinue' }
  if ($Tail -gt 0) { $a.Tail = $Tail } elseif ($Head -gt 0) { $a.TotalCount = $Head }
  @(Get-Content @a | ForEach-Object { $t = "$_"; if ($t.Length -gt 2000) { $t.Substring(0,2000) + ' ...[truncated]' } else { $t } })
}

function Write-Incident { param([string]$Kind,[string]$Symptom,[string]$Action,[int]$Recent,$H)
  $os  = Get-CimInstance Win32_OperatingSystem
  $procs = Get-Process
  $top = $procs | Sort-Object WorkingSet64 -Descending | Select-Object -First 6 | ForEach-Object {
           @{ name = $_.ProcessName; pid = $_.Id; wsGB = [math]::Round($_.WorkingSet64/1GB,2) } }
  # Commit, not working set: under memory pressure the hog is PAGED OUT and drops
  # off the WS list (2026-09-18: the ~30 GB archive job showed as 1.39 GB WS).
  $topCommit = $procs | Sort-Object PagedMemorySize64 -Descending | Select-Object -First 6 | ForEach-Object {
           @{ name = $_.ProcessName; pid = $_.Id; commitGB = [math]::Round($_.PagedMemorySize64/1GB,2) } }
  $crash = Get-ChildItem (Join-Path $SRV 'crash-reports') -Filter '*.txt' -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $crashInfo = $null
  if ($crash -and ($now - $crash.LastWriteTime).TotalMinutes -lt 240) {
    $crashInfo = @{ file = $crash.Name; age_min = [math]::Round(($now - $crash.LastWriteTime).TotalMinutes,1)
                    head = (Get-PlainLines -Path $crash.FullName -Head 12) }
  }
  $inc = [ordered]@{
    time = $stamp; kind = $Kind; symptom = $Symptom; action = $Action; restartsInWindow = $Recent
    health = @{ pids = $H.Pids; portPid = $H.PortPid; ageMin = $H.AgeMin; rconOk = $H.RconOk; owner = $H.Owner }
    freeRAM_GB = [math]::Round($os.FreePhysicalMemory/1MB,2)
    commitUsed_GB  = [math]::Round(($os.TotalVirtualMemorySize - $os.FreeVirtualMemory)/1MB,2)
    commitLimit_GB = [math]::Round($os.TotalVirtualMemorySize/1MB,2)
    topProcesses = $top
    topCommit = $topCommit
    newestCrashReport = $crashInfo
    latestLogTail = (Get-PlainLines -Path (Join-Path $SRV 'logs\latest.log') -Tail 40)
    backupLogTail = (Get-PlainLines -Path 'H:\Game Server Backups\Minecraft\backup.log' -Tail 5)
    presenceTail  = (Get-PlainLines -Path 'H:\Game Server Backups\Minecraft\presence.csv' -Tail 3)
  }
  $f = Join-Path $INCIDENTS ('{0}-{1}.json' -f $Kind.ToLower(), $now.ToString('yyyyMMdd-HHmmss'))
  ($inc | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $f -Encoding utf8
  return $f
}

function Get-RecentRestarts {
  $n = 0
  if (Test-Path $RESTARTS) {
    $cut = $now.AddMinutes(-$LOOP_WINDOW_MIN)
    foreach ($l in Get-Content $RESTARTS) {
      try { if ([datetime]::ParseExact($l.Trim(),'yyyy-MM-dd HH:mm:ss',$null) -ge $cut) { $n++ } } catch {}
    }
  }
  return $n
}

# =============================================================================
$H = Get-Health

# ------------------------------------------------------------------ Start mode
if ($Mode -eq 'Start') {
  if ($H.Present) {
    Write-Log 'OK' ("Start: server already running -- pid {0} owner '{1}' age {2} min rcon={3}. Nothing to do." -f ($H.Pids -join ','), $H.Owner, $H.AgeMin, $H.RconOk)
    if ($H.Owner -and $H.Owner -ne '?' -and $H.Owner -notmatch 'SYSTEM') { Write-Log 'INFO' "Start: note -- current owner is '$($H.Owner)', not SYSTEM. It will be SYSTEM after its next stop+start through this bridge." }
    exit 0
  }
  if ($DryRun) { Write-Log 'INFO' 'Start: server DOWN -- would Start-ScheduledTask (dry run / not elevated, so not doing it)'; exit 2 }
  if (Start-ServerViaTask -Reason 'Start mode: requested') { exit 0 } else { exit 1 }
}

# ------------------------------------------------------------------ Watch mode
$st = Get-State

if (Test-Path $HALT) {
  Set-Beat 'HALTED (crash-loop; delete Watchdog\halt.flag to re-arm)'
  if ($H.RconOk) { Set-Beat 'HALTED but server is UP -- delete Watchdog\halt.flag to re-arm' }
  exit 0
}

# healthy ---------------------------------------------------------------------
if ($H.RconOk) {
  if ($st.last -ne 'OK') { Write-Log 'OK' ("RECOVERED/UP -- pid {0} owner '{1}' players={2} (was {3})" -f ($H.Pids -join ','), $H.Owner, $H.Players, $st.last) }
  $st.last = 'OK'; $st.strikes = 0; Save-State $st
  Set-Beat ("OK  pid={0} owner={1} players={2}" -f ($H.Pids -join ','), $H.Owner, $H.Players)
  exit 0
}

# booting ---------------------------------------------------------------------
if ($H.Present -and $H.AgeMin -ne $null -and $H.AgeMin -lt $BOOT_GRACE_MIN) {
  Set-Beat ("BOOTING  pid={0} age={1}m" -f ($H.Pids -join ','), $H.AgeMin)
  exit 0
}

# unhealthy: decide the symptom -------------------------------------------------
if ($H.Present) {
  $st.strikes = [int]$st.strikes + 1
  if ($st.strikes -lt $HUNG_STRIKES) {
    $st.last = 'DEGRADED'; Save-State $st
    Write-Log 'WARN' ("RCON dead on a mature process (strike {0}/{1}) -- pid {2} age {3}m port={4}" -f $st.strikes, $HUNG_STRIKES, ($H.Pids -join ','), $H.AgeMin, $H.PortPid)
    Set-Beat ("DEGRADED strike {0}/{1}" -f $st.strikes, $HUNG_STRIKES)
    exit 0
  }
  $symptom = "hung (process alive pid {0}, RCON dead {1} consecutive runs)" -f ($H.Pids -join ','), $st.strikes
} else {
  $symptom = 'process-gone (no server java, port 25565 closed)'
}

# planned downtime? -------------------------------------------------------------
if (Test-Path $LOCK) {
  $age = ($now - (Get-Item $LOCK).LastWriteTime).TotalMinutes
  if ($age -lt $LOCK_STALE_MIN) {
    if ($st.last -ne 'MAINT') { Write-Log 'INFO' ("down but maintenance.lock present ({0:n0} min old, owner: '{1}') -- standing down" -f $age, ((Get-Content $LOCK -Raw) -replace '\s+',' ').Trim()) }
    $st.last = 'MAINT'; Save-State $st
    Set-Beat ("SKIP maintenance lock ({0:n0}m old)" -f $age)
    exit 0
  }
  Write-Log 'WARN' ("maintenance.lock is {0:n0} min old (> {1}) -- treating as stale" -f $age, $LOCK_STALE_MIN)
}

# cooldown (we just relaunched and nothing has appeared yet) --------------------
$lastRestart = $null
if (Test-Path $RESTARTS) { $l = Get-Content $RESTARTS -Tail 1; if ($l) { try { $lastRestart = [datetime]::ParseExact($l.Trim(),'yyyy-MM-dd HH:mm:ss',$null) } catch {} } }
if ($lastRestart -and ($now - $lastRestart).TotalMinutes -lt $BOOT_GRACE_MIN) {
  Set-Beat 'SKIP cooldown (relaunched < 5 min ago)'; exit 0
}

# act -----------------------------------------------------------------------------
$recent = Get-RecentRestarts
if ($DryRun) {
  Write-Log 'INFO' ("DRY RUN: would act on '{0}' (restarts in last {1} min: {2}; elevated={3})" -f $symptom, $LOOP_WINDOW_MIN, $recent, $elevated)
  Set-Beat "DRY RUN would act: $symptom"
  exit 0
}

if ($recent -ge $LOOP_MAX) {
  $f = Write-Incident -Kind 'CRASHLOOP' -Symptom $symptom -Action "HALT: $recent relaunches in $LOOP_WINDOW_MIN min; awaiting human" -Recent $recent -H $H
  "$stamp  CRASH-LOOP: $recent relaunches in $LOOP_WINDOW_MIN min. Watchdog halted.`r`nRead Watchdog\incidents\, fix the cause, then DELETE this file to re-arm." | Set-Content -LiteralPath $HALT
  Write-Log 'FAIL' "CRASH-LOOP HALT ($symptom) -- $recent relaunches/$LOOP_WINDOW_MIN min. Incident: $f"
  $st.last = 'HALT'; Save-State $st
  Set-Beat 'CRASH-LOOP HALT (needs human -- see Watchdog\incidents)'
  exit 0
}

if ($H.Present) {
  foreach ($id in $H.Pids) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Seconds 5
  Write-Log 'WARN' ("killed hung server pid(s) {0}" -f ($H.Pids -join ','))
}
$ok = Start-ServerViaTask -Reason $symptom
$kind = 'DOWN'; if ($H.Present) { $kind = 'HUNG' }
$act  = 'relaunch ISSUED but no process appeared'; if ($ok) { $act = 'relaunched via SYSTEM boot task' }
$f = Write-Incident -Kind $kind -Symptom $symptom -Action $act -Recent ($recent + 1) -H $H
$lvl = 'FAIL'; $res = 'UNVERIFIED'; if ($ok) { $lvl = 'OK'; $res = 'succeeded' }
Write-Log $lvl ("{0} -- relaunch {1}. restartsInWindow={2}. Incident: {3}" -f $symptom, $res, ($recent + 1), $f)
$st.last = 'DOWN'; $st.strikes = 0; Save-State $st
if ($ok) { Set-Beat 'RESTARTED (was down)' } else { Set-Beat 'RESTART ATTEMPTED - unverified' }
