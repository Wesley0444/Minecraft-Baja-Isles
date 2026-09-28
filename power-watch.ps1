<#
=============================================================================
 power-watch.ps1  --  Minecraft : graceful stop before the UPS runs dry
-----------------------------------------------------------------------------
 WHAT IT DOES
   Watches the UPS (Win32_Battery -- it reports over USB HID as a battery)
   every -PollSec seconds for the length of a house power outage.

     * outage lasts -NoticeAfterSec    -> one in-game heads-up (blips stay silent)
     * charge <= -WarnAt   (once)      -> in-game warning
     * charge <= -StopAt, or runtime estimate <= -RuntimeStopMin on two
       consecutive polls               -> maintenance.lock, -CountdownSec in-game
                                          countdown, RCON stop, wait for port 25565
     * power back mid-countdown        -> cancel, lock removed, server stays up
     * after OUR stop ("HELD")         -> lock refreshed every 5 min; once AC has
                                          been stable -AcStableMin: lock removed +
                                          server started through the 'Minecraft
                                          Start' bridge (it comes back as SYSTEM)
     * server started by someone else while HELD -> back to watching it
     * power back and the players were told -> "power is back" message
     * AC stable -ExitAfterAcMin (and not HELD) -> exit

 HOW IT STARTS
   Automatically: scheduled task 'Minecraft Power Watch' (SYSTEM, registered by
   admin_setup.bat -> setup-tasks.ps1), triggered by System log event
   Kernel-Power 105 "Power source change" with AcOnline=false -- Windows writes
   it within a second of the UPS going to battery. Task setting IgnoreNew + the
   mutex below = one watcher per outage however much the power flickers.
   By hand (a Claude session, or if the task is missing): see USAGE.

 WHY
   Windows hibernates at the CRITICAL battery level (10 % since 2026-09-27; was
   5 %). Hibernating a live server bets the world on the hiberfile finishing
   before the UPS dies. Stopping at 20 % takes the bet off the table and the
   stopped server stretches the runtime. The runtime trigger exists because
   UPS charge is not linear near the end; it needs two reads so one load spike
   cannot fire it. The notice waits 2 min because this house gets 8-9 s blips
   (09-21 twice) -- nobody needs a chat message for those.

   First real outage 2026-09-27 19:56 -> ~22:07: stop at 20 % 21:17 (clean,
   23 s), hibernate at 10 % 21:26, resume 22:07. Record: memory
   ups-power-outage-runbook, skill .claude\skills\power-outage.

 USAGE
   powershell -NoProfile -ExecutionPolicy Bypass -File power-watch.ps1
     -DryRun        real sensors, sends nothing, writes no lock
     -Probe         one real RCON 'list' through this script's client, then exit
     -SimulateFile  test harness: a JSON file {"onBattery":bool,"charge":n,
                    "runtime":n} replaces the UPS, <file>.server ("1"/"0")
                    replaces port 25565, and log/lock/markers live beside it.
                    Nothing real is touched.
   Abort a running watcher: create H:\Game Server Backups\Minecraft\POWER-WATCH-ABORT.txt
   Log: H:\Game Server Backups\Minecraft\power-watch.log  (never tail -F it:
        a held-open log is how armed-endboss died -- poll with short reads)
   Done marker: POWER-STOP-DONE.txt (same folder), written after a clean stop
=============================================================================
#>
param(
  [int]$StopAt           = 20,
  [int]$WarnAt           = 30,
  [int]$RuntimeStopMin   = 7,
  [int]$PollSec          = 20,
  [int]$NoticeAfterSec   = 120,
  [int]$CountdownSec     = 60,
  [double]$AcStableMin   = 5,
  [double]$ExitAfterAcMin = 15,
  [switch]$DryRun,
  [switch]$Probe,
  [string]$SimulateFile
)
$ErrorActionPreference = 'Stop'

$SRV   = 'C:\Game Servers\Minecraft'
$PROPS = Join-Path $SRV 'server.properties'
$Sim   = [bool]$SimulateFile
if ($Sim) {
  $SimulateFile = (Resolve-Path $SimulateFile).Path
  $STATE = Split-Path -Parent $SimulateFile
  $LOCK  = Join-Path $STATE 'maintenance.lock'
} else {
  $STATE = 'H:\Game Server Backups\Minecraft'
  $LOCK  = Join-Path $SRV 'maintenance.lock'
}
$LOG    = Join-Path $STATE 'power-watch.log'
$DONE   = Join-Path $STATE 'POWER-STOP-DONE.txt'
$ABORT  = Join-Path $STATE 'POWER-WATCH-ABORT.txt'
$SIMSRV = "$SimulateFile.server"
$TAG    = if ($Sim) { '(sim) ' } elseif ($DryRun) { '(dry) ' } else { '' }

function Log([string]$lvl, [string]$msg) {
  $line = '{0}  [{1}]  {2}{3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $lvl, $TAG, $msg
  for ($i = 0; $i -lt 25; $i++) {
    try { [IO.File]::AppendAllText($LOG, $line + "`r`n"); return } catch { Start-Sleep -Milliseconds 200 }
  }
}

# ------------------------------------------------------------------ sensors
function Read-SimJson {
  for ($i = 0; $i -lt 20; $i++) {
    try { return ([IO.File]::ReadAllText($SimulateFile) | ConvertFrom-Json) } catch { Start-Sleep -Milliseconds 100 }
  }
  return $null
}

function Get-Power {
  # BatteryStatus 1 = discharging, 4 = low, 5 = critical -> on battery. Anything else = on AC.
  if ($Sim) {
    $j = Read-SimJson
    if (-not $j) { return [pscustomobject]@{ Ok = $false } }
    return [pscustomobject]@{ Ok = $true; Charge = [int]$j.charge; Runtime = [int]$j.runtime
                              OnBattery = [bool]$j.onBattery; Status = -1; Src = 'sim' }
  }
  try {
    $b = @(Get-CimInstance Win32_Battery -ErrorAction Stop)[0]
    if ($b) {
      $rt = [int64]$b.EstimatedRunTime
      if ($rt -ge 71582788) { $rt = -1 }   # sentinel = unknown / on AC
      return [pscustomobject]@{ Ok = $true; Charge = [int]$b.EstimatedChargeRemaining; Runtime = $rt
                                OnBattery = @(1,4,5) -contains [int]$b.BatteryStatus; Status = [int]$b.BatteryStatus; Src = 'cim' }
    }
  } catch {}
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $p = [System.Windows.Forms.SystemInformation]::PowerStatus
    return [pscustomobject]@{ Ok = $true; Charge = [int]([math]::Round($p.BatteryLifePercent * 100))
                              Runtime = $(if ($p.BatteryLifeRemaining -gt 0) { [int]($p.BatteryLifeRemaining / 60) } else { -1 })
                              OnBattery = ($p.PowerLineStatus -eq 'Offline'); Status = -1; Src = 'forms' }
  } catch {}
  return [pscustomobject]@{ Ok = $false }
}

function Test-ServerUp {
  if ($Sim) {
    for ($i = 0; $i -lt 20; $i++) { try { return ([IO.File]::ReadAllText($SIMSRV).Trim() -eq '1') } catch { Start-Sleep -Milliseconds 100 } }
    return $false
  }
  # Port state, never the process command line: a non-elevated query sees a
  # SYSTEM server's CommandLine as NULL (CLAUDE.md, third costume of that trap).
  try { return [bool](Get-NetTCPConnection -LocalPort 25565 -State Listen -ErrorAction Stop) } catch { return $false }
}

function Set-SimServer([string]$v) { for ($i = 0; $i -lt 20; $i++) { try { [IO.File]::WriteAllText($SIMSRV, $v); return } catch { Start-Sleep -Milliseconds 100 } } }

# --------------------------------------------------------------------- RCON
function Get-RconPassword {
  $l = Get-Content $PROPS | Where-Object { $_ -like 'rcon.password=*' } | Select-Object -First 1
  return $l.Substring('rcon.password='.Length)
}

function Invoke-RconOnce([string[]]$Commands, [int]$TimeoutMs = 8000) {
  $pw = Get-RconPassword
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $iar = $client.BeginConnect('127.0.0.1', 25575, $null, $null)
    if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) { throw 'RCON connect timeout' }
    $client.EndConnect($iar)
    $s = $client.GetStream(); $s.ReadTimeout = $TimeoutMs; $s.WriteTimeout = $TimeoutMs
    $send = {
      param($id, $type, $body)
      $b = [Text.Encoding]::UTF8.GetBytes($body)
      $ms = New-Object IO.MemoryStream; $bw = New-Object IO.BinaryWriter($ms)
      $bw.Write([int](10 + $b.Length)); $bw.Write([int]$id); $bw.Write([int]$type)
      $bw.Write($b); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Flush()
      $o = $ms.ToArray(); $s.Write($o, 0, $o.Length); $s.Flush()
    }
    $read = {
      $h = New-Object byte[] 4; $n = 0
      while ($n -lt 4) { $r = $s.Read($h, $n, 4 - $n); if ($r -le 0) { throw 'RCON closed' }; $n += $r }
      $len = [BitConverter]::ToInt32($h, 0); $buf = New-Object byte[] $len; $n = 0
      while ($n -lt $len) { $r = $s.Read($buf, $n, $len - $n); if ($r -le 0) { throw 'RCON closed' }; $n += $r }
      [pscustomobject]@{ Id = [BitConverter]::ToInt32($buf, 0); Type = [BitConverter]::ToInt32($buf, 4)
                         Body = [Text.Encoding]::UTF8.GetString($buf, 8, $len - 10) }
    }
    & $send 1 3 $pw
    $a = & $read; if ($a.Type -ne 2) { $a = & $read }
    if ($a.Id -eq -1) { throw 'RCON auth failed' }
    $out = @(); $i = 2
    foreach ($c in $Commands) { & $send $i 2 $c; $out += (& $read).Body; $i++ }
    return ,$out   # comma is load-bearing: stops PS unrolling a 1-element array
  } finally { $client.Close() }
}

function Invoke-Rcon([string[]]$Commands) {
  if ($Sim -or $DryRun) {
    Log 'DRY' ('would send: ' + ($Commands -join ' | '))
    if ($Sim -and ($Commands -contains 'stop')) { Set-SimServer '0' }   # the simulated server obeys
    return ,@()
  }
  # 4 tries: this server has dropped the FIRST rcon connection after a boot 4 times.
  for ($t = 1; $t -le 4; $t++) {
    try { return (Invoke-RconOnce $Commands) } catch { Log 'WARN' "rcon try $t failed: $($_.Exception.Message)"; Start-Sleep -Seconds 2 }
  }
  throw 'RCON failed 4x'
}

function Say([string]$text) {
  try { Invoke-Rcon @("say $text") | Out-Null; Log 'INFO' "said: $text" } catch { Log 'FAIL' "say failed: $($_.Exception.Message)" }
}

# ------------------------------------------------------------ lock + start
function Write-Lock([string]$why) {
  if ($DryRun -and -not $Sim) { return }
  [IO.File]::WriteAllText($LOCK, "power-watch: $why ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))")
}

function Remove-OwnLock {
  if ($DryRun -and -not $Sim) { return }
  if (-not (Test-Path $LOCK)) { return }
  $c = [IO.File]::ReadAllText($LOCK)
  if ($c.StartsWith('power-watch:')) { [IO.File]::Delete($LOCK); Log 'INFO' 'removed our maintenance.lock' }
  else { Log 'INFO' "left someone else's maintenance.lock alone: $($c.Trim())" }
}

function Start-Server {
  # The bridge, not the SYSTEM task directly: works from SYSTEM *and* from a
  # non-elevated session, and it is idempotent ("already running" = no-op).
  if ($Sim) { Log 'DRY' 'would run: schtasks /Run /TN "Minecraft Start"'; Set-SimServer '1'; return }
  if ($DryRun) { Log 'DRY' 'would run: schtasks /Run /TN "Minecraft Start"'; return }
  $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'   # native exe + stderr under Stop = throw (PS 5.1)
  try {
    $out = & schtasks.exe /Run /TN 'Minecraft Start' 2>&1 | ForEach-Object { "$_" }
    Log 'INFO' ("schtasks /Run 'Minecraft Start' -> exit {0}: {1}" -f $LASTEXITCODE, ($out -join ' '))
  } finally { $ErrorActionPreference = $eap }
}

# ------------------------------------------------------------------- probe
if ($Probe) { Log 'PROBE' ('rcon list -> ' + ((Invoke-Rcon @('list')) -join ' ')); exit 0 }

# ----------------------------------------------------------- one at a time
# The task's IgnoreNew stops task-vs-task; this stops task-vs-hand-launch. A
# mutex created by SYSTEM can be unopenable for a user process (ACL) -- that
# also means "someone is already watching", so it counts as held.
$mtxName = if ($Sim) { 'Global\BajaPowerWatchSim' } else { 'Global\BajaPowerWatch' }
$held = $false; $mtx = $null
try { $mtx = [System.Threading.Mutex]::new($false, $mtxName) } catch { $mtx = $null }
if ($mtx) {
  try { $held = $mtx.WaitOne(0) }
  catch { if ($_.Exception.InnerException -is [System.Threading.AbandonedMutexException]) { $held = $true } else { throw } }
}
if (-not $held) { Log 'INFO' "another power-watch already holds $mtxName -- exiting"; exit 0 }

# ---------------------------------------------------------------- main loop
$who = [Security.Principal.WindowsIdentity]::GetCurrent().Name
Log 'INFO' "=== POWER WATCH START as $who pid $PID (stop<=$StopAt% or runtime<=$RuntimeStopMin min x2, warn<=$WarnAt%, notice after ${NoticeAfterSec}s, poll ${PollSec}s) ==="

$state = 'WATCH'          # WATCH = protecting a server (or waiting for one); HELD = we stopped it
$noticed = $false; $warned = $false; $lowRt = 0
$outageSince = $null; $acSince = $null; $lastTouch = [datetime]::MinValue; $failPolls = 0

while ($true) {
  if (Test-Path $ABORT) { Log 'INFO' 'abort file present -- exiting'; break }
  $p = Get-Power
  if (-not $p.Ok) {
    $failPolls++; Log 'WARN' "battery query failed ($failPolls in a row)"
    Start-Sleep -Seconds $PollSec; continue
  }
  $failPolls = 0
  $up  = Test-ServerUp
  $now = Get-Date
  Log 'POLL' ('{0} {1}% runtime={2}m state={3} server={4}' -f $(if ($p.OnBattery) { 'BATTERY' } else { 'AC' }), $p.Charge, $p.Runtime, $state, $(if ($up) { 'UP' } else { 'DOWN' }))

  if ($p.OnBattery) {
    if (-not $outageSince) { $outageSince = $now; Log 'INFO' "on BATTERY ($($p.Charge)%)" }
    $acSince = $null
  } else {
    if (-not $acSince) { $acSince = $now; Log 'INFO' "AC power ($($p.Charge)%)" }
    $outageSince = $null; $lowRt = 0
  }

  # ---- HELD: we stopped the server; keep it down until the power is back for real
  if ($state -eq 'HELD') {
    if ($up) {
      Log 'INFO' 'server is up again while HELD (started by someone else) -- back to WATCH'
      Remove-OwnLock
      $state = 'WATCH'; $noticed = $false; $warned = $false
      # fall through: it gets protected from this poll on
    } else {
      if (($now - $lastTouch).TotalMinutes -ge 5) { Write-Lock 'server stopped for a power outage'; $lastTouch = $now }
      if ($acSince -and ($now - $acSince).TotalMinutes -ge $AcStableMin) {
        Log 'INFO' ("RELEASE: AC stable {0:n1} min, UPS {1}% -- starting the server" -f ($now - $acSince).TotalMinutes, $p.Charge)
        Remove-OwnLock
        Start-Server
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $limit = if ($Sim) { 10 } else { 240 }
        while (-not (Test-ServerUp) -and $sw.Elapsed.TotalSeconds -lt $limit) { Start-Sleep -Seconds 2 }
        if (Test-ServerUp) { Log 'OK' ("server port up {0:n0} s after the start request" -f $sw.Elapsed.TotalSeconds) }
        else { Log 'FAIL' "server port not up $limit s after the start request -- the watchdog should relaunch it (lock is gone)" }
        $state = 'WATCH'; $noticed = $false; $warned = $false
      }
      Start-Sleep -Seconds $PollSec; continue
    }
  }

  # ---- WATCH, on AC
  if (-not $p.OnBattery) {
    if ($noticed -and $up) { Say 'Power is back at the host. Carry on.'; $noticed = $false; $warned = $false }
    if (($now - $acSince).TotalMinutes -ge $ExitAfterAcMin) {
      Log 'INFO' ("AC stable {0} min -- exiting (server {1})" -f $ExitAfterAcMin, $(if ($up) { 'UP' } else { 'DOWN' }))
      break
    }
    Start-Sleep -Seconds $PollSec; continue
  }

  # ---- WATCH, on battery
  if (-not $up) { Start-Sleep -Seconds $PollSec; continue }   # nothing to protect right now

  if ($p.Runtime -ge 0 -and $p.Runtime -le $RuntimeStopMin) { $lowRt++ } else { $lowRt = 0 }

  if (-not $noticed -and ($now - $outageSince).TotalSeconds -ge $NoticeAfterSec) {
    Say "Heads up: the power is out at the host and the server is running on UPS battery ($($p.Charge)%). If power isn't back first, it shuts down cleanly at $StopAt% with a $CountdownSec-second warning - nothing gets lost."
    $noticed = $true
  }
  if (-not $warned -and $p.Charge -le $WarnAt -and $p.Charge -gt $StopAt) {
    Say "UPS battery at $($p.Charge)% - the server shuts down at $StopAt%. Get somewhere safe."
    $warned = $true; $noticed = $true
  }

  $trigger = $null
  if ($p.Charge -le $StopAt) { $trigger = "charge $($p.Charge)% <= $StopAt%" }
  elseif ($lowRt -ge 2)      { $trigger = "runtime $($p.Runtime) min <= $RuntimeStopMin on 2 polls" }
  if (-not $trigger) { Start-Sleep -Seconds $PollSec; continue }

  # ---- shutdown
  Log 'INFO' "TRIGGER: $trigger -- starting $CountdownSec s countdown"
  Write-Lock "graceful stop, UPS $($p.Charge)%"; $lastTouch = Get-Date
  Say "Power outage: UPS battery at $($p.Charge)%. Server stopping in $CountdownSec seconds - log out somewhere safe. It comes back by itself once the power is back."
  try { Invoke-Rcon @("title @a title {`"text`":`"Server stopping in ${CountdownSec}s`",`"color`":`"red`"}",
                      'title @a subtitle {"text":"Power outage - UPS battery low","color":"gold"}') | Out-Null } catch {}

  $cancel = $false; $remaining = $CountdownSec
  foreach ($mark in @(30, 10)) {
    if ($mark -ge $remaining) { continue }
    Start-Sleep -Seconds ($remaining - $mark); $remaining = $mark
    $q = Get-Power
    if ($q.Ok -and -not $q.OnBattery) { $cancel = $true; break }
    Say "Server stopping in $mark seconds (power outage)."
  }
  if (-not $cancel) {
    Start-Sleep -Seconds $remaining
    $q = Get-Power
    if ($q.Ok -and -not $q.OnBattery) { $cancel = $true }
  }
  if ($cancel) {
    Say 'Power is back - shutdown cancelled. Carry on.'
    Remove-OwnLock
    Log 'INFO' 'AC returned during the countdown -- CANCELLED'
    $noticed = $false; $warned = $false; $lowRt = 0
    continue
  }

  try { $r = Invoke-Rcon @('stop'); Log 'INFO' ("stop sent: {0}" -f ($r -join ' ').Trim()) } catch { Log 'FAIL' "stop failed: $($_.Exception.Message)" }
  if ($DryRun -and -not $Sim) { Log 'DRY' 'would wait for port 25565 to close, write DONE, then HOLD'; break }

  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ((Test-ServerUp) -and $sw.Elapsed.TotalSeconds -lt 180) { Start-Sleep -Seconds 2 }
  if (Test-ServerUp) {
    Log 'FAIL' 'port 25565 still listening 180 s after stop -- server did not stop; hibernate will freeze it'
  } else {
    if (-not $Sim) { Start-Sleep -Seconds 20 }   # the port closes ~10 s before the JVM finishes exiting
    Log 'OK' ("server stopped ({0:n0} s)" -f $sw.Elapsed.TotalSeconds)
    [IO.File]::WriteAllText($DONE, "graceful stop at UPS $($p.Charge)% ($trigger) $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
  }
  $state = 'HELD'
}
if ($mtx) { try { $mtx.ReleaseMutex() } catch {} }
Log 'INFO' '=== POWER WATCH END ==='
