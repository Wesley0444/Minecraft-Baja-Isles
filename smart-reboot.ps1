<#
=============================================================================
 smart-reboot.ps1  --  take Windows Update's restart GRACEFULLY, on our terms
-----------------------------------------------------------------------------
 WHAT IT DOES   (task 'Minecraft Smart Reboot', SYSTEM: daily 07:01 then every
                 15 min until ~12:46 = Windows' own restart window, + at boot)

   first run after a boot (uptime < 10 min)=> clear OUR lock, log whether the
                                             restart cleared, never reboot
   no Windows restart pending              => heartbeat file, exit
   pending, Wesley at the desktop          => stand down, retry next run
   pending, server EMPTY (or not running)  => snapshot -> lock -> RCON stop ->
                                             wait for the JVM to EXIT -> reboot
   pending, players ONLINE                 => in-game warnings T-10 / T-5 / T-1,
                                             go early if everyone leaves, and
                                             at T-0 the same graceful stop anyway
   someone else's fresh maintenance.lock   => stand down, retry next run
   already rebooted today, STILL pending   => warn once, never loop

 WHY IT EXISTS (2026-09-15)
   * Windows Update restarts this box by itself ~29 min after Active Hours
     end (04:29 on 09-09 AND 09-15). Nothing stopped the server first: a hard
     kill with a player online both times, and both times it also killed the
     nightly archive mid-zip.
   * Play history (314 sessions, 08-30..09-15) put 04:29 in the tail of PEAK
     (someone online 80% of days). The quiet band is 06:30-10:45, so Active
     Hours now end at 07:00 (setup-tasks.ps1) and Windows' own restart lands
     ~07:29. This beats it by ~25 min on an empty server, and by ~15 min --
     with warnings -- on a busy one. Either way the world is saved cleanly.
   * Palworld had the same idea (its smart-reboot.ps1 at 04:30 -- almost
     certainly the 08-13 04:30 shutdown.exe in the event log) and it died with
     the mothball. This is that for Minecraft, plus the warn-and-go path.

 WHY IT IS BUILT THIS WAY
   * SYSTEM: needs the shutdown privilege and must SEE the SYSTEM server's
     command line to know when the JVM is really gone. Not elevated => forced
     -DryRun (a normal shell gets a NULL CommandLine for a SYSTEM process).
   * This box is also Wesley's gaming PC. Windows waits for an idle desktop
     before it restarts; a script must too. SYSTEM cannot see console input
     (WTS LastInputTime is 0 for the console, quser is absent on Home), so it
     fires the on-demand 'Minecraft Idle Probe' task, which runs in HIS session
     with no window (idle-probe.vbs) and writes the idle seconds to a file.
     No answer = nobody logged on = nobody to disturb.
   * "Pending" = any of: WU Auto Update\RebootRequired key, CBS RebootPending
     key, the WUA Microsoft.Update.SystemInfo.RebootRequired flag. Which fired
     is logged -- the first real event is the evidence for which Windows uses.
     PendingFileRenameOperations is ignored on purpose: installers set it all
     the time and it is not Windows Update asking for a restart.
   * Snapshot BEFORE the lock: backup.ps1 -Mode Snapshot skips under a lock.
   * Wait for the JVM to EXIT, not the port: the port closes ~10 s before the
     JVM finishes saving (the Discord bot's /restart learned this the hard way).
   * The lock is KEPT through the reboot (watchdog must not relaunch java into
     a shutting-down box) and cleared by the boot-time run. If the reboot never
     happens (shutdown /a, failure) the next run sees its own lock on a box that
     has not rebooted, clears it, and the watchdog brings the server back.
   * `shutdown /r /t 60` with a comment: a user the probe missed still gets
     Windows' one-minute notice and can `shutdown /a`.
   * One smart reboot per day, max. If a plain restart does not clear Windows'
     pending flag, rebooting every 15 min would be worse than letting Windows
     finish the job itself.
   * Never reboots from a boot-time run: a power-cut boot at 22:00 must not
     turn into a peak-hour restart.

 OPERATING
   what it did              : H:\Game Server Backups\Minecraft\smart-reboot.log
   is the task firing       : H:\Game Server Backups\Minecraft\smart-reboot.heartbeat
   dry run (safe, any shell): powershell -File smart-reboot.ps1 -DryRun
   dry run of the busy path : powershell -File smart-reboot.ps1 -DryRun -AssumePending
   cancel a restart in its 60 s notice : shutdown /a   (then the next run
                                          clears the lock and the watchdog
                                          restarts the server)
   register / reschedule    : admin_setup.bat (as admin) -> setup-tasks.ps1
=============================================================================
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$AssumePending   # pretend Windows wants a restart -- only honoured with -DryRun
)
# Every failure path is handled explicitly (same stance as watchdog.ps1).
$ErrorActionPreference = 'SilentlyContinue'

# --- configuration -----------------------------------------------------------
$SRV        = 'C:\Game Servers\Minecraft'
$LOCK       = Join-Path $SRV 'maintenance.lock'
$BAK        = 'H:\Game Server Backups\Minecraft'
$LOG        = Join-Path $BAK 'smart-reboot.log'
$HEARTBEAT  = Join-Path $BAK 'smart-reboot.heartbeat'
$STATE      = Join-Path $BAK 'smart-reboot.state'
$IDLEFILE   = Join-Path $BAK 'console-idle.txt'
$PROBE_TASK = 'Minecraft Idle Probe'
$LOCK_TAG   = 'smart-reboot:'
$GAME_PORT  = 25565
$RCON_HOST  = '127.0.0.1'
$RCON_PORT  = 25575
$LOCK_STALE_MIN = 45     # the watchdog's window -- anything younger is someone's live job
$WARN_MIN       = 10     # countdown when players are online
$EXIT_WAIT_SEC  = 180    # graceful-stop budget before a force-kill
$IDLE_MIN       = 20     # desktop input newer than this = Wesley is using the PC
$BOOT_RUN_MIN   = 10     # uptime below this = boot-time run: clean up only

New-Item -ItemType Directory -Force -Path $BAK | Out-Null

function Write-Log { param([string]$Status,[string]$Text)
  $line = '{0}  [{1}]  {2}' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'), $Status, $Text
  Write-Host $line
  Add-Content -Path $LOG -Value $line -Encoding utf8
}

$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $elevated -and -not $DryRun) {
  $DryRun = $true
  Write-Log 'WARN' 'not elevated -- forced to -DryRun (cannot see the SYSTEM server process)'
}
if ($AssumePending -and -not $DryRun) { Write-Log 'WARN' '-AssumePending ignored without -DryRun'; $AssumePending = $false }

# --- minimal RCON client (same protocol impl as backup.ps1, incl. the ,$results unroll guard)
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
# Player count, or $null when RCON does not answer. Never throws.
function Get-Players {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Stop'
  try {
    $r = (Invoke-Rcon -Commands @('list') -TimeoutMs 6000)[0]
    if ($r -match 'There are (\d+) of a max of \d+ players online') { return [int]$Matches[1] }
    return $null
  } catch { return $null } finally { $ErrorActionPreference = $old }
}
function Send-Rcon { param([string]$Command)
  if ($DryRun) { Write-Log 'DRY' "would RCON: $Command"; return }
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Stop'
  try { Invoke-Rcon -Commands @($Command) -TimeoutMs 10000 | Out-Null }
  catch { Write-Log 'WARN' "RCON '$Command' failed: $($_.Exception.Message)" }
  finally { $ErrorActionPreference = $old }
}

# --- process / port / pending / desktop ----------------------------------------
# Server java = command line contains THIS folder's libraries path (never 'neoforge'
# alone -- Wesley's client is NeoForge java on this box too).
function Get-ServerProcs {
  $p = @(Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
         Where-Object { $_.CommandLine -and $_.CommandLine -like '*Game Servers\Minecraft\libraries*' })
  return ,$p
}
function Test-PortListening { [bool](Get-NetTCPConnection -LocalPort $GAME_PORT -State Listen -ErrorAction SilentlyContinue) }
function Get-PendingReasons {
  $r = @()
  if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $r += 'WU:RebootRequired' }
  if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $r += 'CBS:RebootPending' }
  try { if ((New-Object -ComObject 'Microsoft.Update.SystemInfo').RebootRequired) { $r += 'WUA:SystemInfo' } } catch {}
  return ,$r
}
# Minutes since the last keyboard/mouse input in Wesley's desktop session, or
# $null when nobody is logged on (the Interactive probe task cannot start).
function Get-DesktopIdleMin {
  Remove-Item -LiteralPath $IDLEFILE -Force
  Start-ScheduledTask -TaskName $PROBE_TASK
  $until = (Get-Date).AddSeconds(20)
  while ((Get-Date) -lt $until) {
    Start-Sleep -Seconds 1
    if (Test-Path $IDLEFILE) {
      $v = ((Get-Content -LiteralPath $IDLEFILE -Raw) -replace '\s','')
      if ($v -match '^\d+$') { return [math]::Round([int]$v / 60, 1) }
    }
  }
  return $null
}

# --- state (one smart reboot per day) -----------------------------------------
$st = $null
if (Test-Path $STATE) { try { $st = Get-Content $STATE -Raw | ConvertFrom-Json } catch {} }
if (-not $st) { $st = [pscustomobject]@{ lastReboot = ''; warned = '' } }
function Save-State { if (-not $DryRun) { ($st | ConvertTo-Json -Compress) | Set-Content -LiteralPath $STATE -Encoding ascii } }
$today     = (Get-Date).ToString('yyyy-MM-dd')
$uptimeMin = ((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalMinutes

# =============================================================================
# 1. Our own lock from an earlier run. Rebooted since => clear it (normal case).
#    Not rebooted => the restart was aborted or failed: clear it anyway so the
#    watchdog brings the server back.
if ((Test-Path $LOCK) -and ((Get-Content -LiteralPath $LOCK -Raw) -match [regex]::Escape($LOCK_TAG))) {
  $lockAge = ((Get-Date) - (Get-Item $LOCK).LastWriteTime).TotalMinutes
  $rebooted = $uptimeMin -lt $lockAge
  if ($DryRun) { Write-Log 'DRY' ("would clear smart-reboot's own lock ({0})" -f $(if ($rebooted) { 'post-reboot' } else { 'reboot never happened' })) }
  else {
    Remove-Item -LiteralPath $LOCK -Force
    if ($rebooted) { Write-Log 'OK' ("post-reboot: cleared smart-reboot's lock (up {0:n0} min); still pending: {1}" -f $uptimeMin, $(if ((Get-PendingReasons).Count) { (Get-PendingReasons) -join ',' } else { 'nothing' })) }
    else { Write-Log 'WARN' "our reboot never happened (shutdown /a or a failure?) -- cleared our lock; the watchdog will restart the server" }
  }
}

# 2. A boot-time run only cleans up. A 22:00 power-cut boot must not become a
#    peak-hour restart, and a box that just booted is not due another one.
if ($uptimeMin -lt $BOOT_RUN_MIN -and -not $DryRun) { exit 0 }

# 3. Does Windows want a restart at all?
$reasons = Get-PendingReasons
if ($AssumePending -and $reasons.Count -eq 0) { $reasons = @('ASSUMED(-AssumePending)') }
if ($reasons.Count -eq 0) {
  if ($DryRun) { Write-Log 'DRY' 'no Windows restart pending -- nothing to do' }
  else { ('{0}  no restart pending' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss')) | Set-Content -LiteralPath $HEARTBEAT -Encoding ascii }
  exit 0
}
$why = $reasons -join ','

# 4. At most one smart reboot a day.
if ($st.lastReboot -like "$today*") {
  if ($st.warned -ne $today) {
    Write-Log 'WARN' "restart STILL pending ($why) after this morning's smart reboot ($($st.lastReboot)) -- not looping; Windows will finish it"
    $st.warned = $today; Save-State
  }
  exit 0
}

# 5. Someone else's job holds the lock.
if (Test-Path $LOCK) {
  $age = ((Get-Date) - (Get-Item $LOCK).LastWriteTime).TotalMinutes
  if ($age -lt $LOCK_STALE_MIN) {
    Write-Log 'INFO' ("restart pending ($why) but maintenance.lock is held ({0:n0} min, '{1}') -- standing down, retrying next run" -f $age, ((Get-Content $LOCK -Raw) -replace '\s+',' ').Trim())
    exit 0
  }
}

# 6. Is Wesley at the PC? Windows would wait for him; so do we.
$idle = Get-DesktopIdleMin
if ($null -ne $idle -and $idle -lt $IDLE_MIN) {
  Write-Log 'INFO' "restart pending ($why) but the desktop is in use (last input $idle min ago) -- not rebooting the PC under Wesley; retrying next run"
  exit 0
}

# 7. Server state.
$up = ((Get-ServerProcs).Count -gt 0) -or (Test-PortListening)
$players = 0
if ($up) {
  $players = Get-Players
  if ($null -eq $players) { Start-Sleep -Seconds 5; $players = Get-Players }
  if ($null -eq $players) {
    Write-Log 'WARN' "restart pending ($why) but the server is up and RCON is not answering -- standing down (hung servers are the watchdog's job)"
    exit 0
  }
}
Write-Log 'INFO' ("Windows restart pending ($why); desktop {0}; server {1}" -f `
  $(if ($null -eq $idle) { 'not logged on' } else { "idle $idle min" }), $(if ($up) { "up, $players online" } else { 'not running' }))

# 8. Players online: warn, then go anyway.
if ($up -and $players -gt 0) {
  Send-Rcon "say [Server] Windows needs to restart this PC for updates. Restarting in $WARN_MIN minutes -- get somewhere safe. Back in ~5 min."
  if ($DryRun) {
    Write-Log 'DRY' "would re-warn at T-5 and T-1, poll players every 20 s, go early if empty, go at T-0 regardless"
  } else {
    $deadline = (Get-Date).AddMinutes($WARN_MIN); $said5 = $false; $said1 = $false
    while ((Get-Date) -lt $deadline) {
      Start-Sleep -Seconds 20
      $left = ($deadline - (Get-Date)).TotalMinutes
      if (-not $said5 -and $left -le 5) { Send-Rcon 'say [Server] Restarting for Windows updates in 5 minutes.'; $said5 = $true }
      if (-not $said1 -and $left -le 1) { Send-Rcon 'say [Server] Restarting in 1 minute -- log off now to be safe.'; $said1 = $true }
      $n = Get-Players
      if ($n -eq 0) { Write-Log 'INFO' 'server emptied during the countdown -- restarting now'; break }
    }
  }
}

# 9. The graceful reboot.
if ($DryRun) {
  Write-Log 'DRY' "would: snapshot -> lock -> RCON stop -> wait for JVM exit (<= $EXIT_WAIT_SEC s, then force-kill) -> shutdown /r /t 60 (lock kept; the boot-time run clears it)"
  exit 0
}

if ($up) {
  # Snapshot BEFORE the lock (Snapshot skips under one). Wait out a :00/:30 run first.
  $until = (Get-Date).AddMinutes(3)
  while ((Get-Process robocopy -ErrorAction SilentlyContinue) -and (Get-Date) -lt $until) { Start-Sleep -Seconds 3 }
  # Start-Process does NOT quote -ArgumentList; the spaced path needs its own quotes.
  $bp = Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$SRV\backup.ps1`"",'-Mode','Snapshot') `
          -WindowStyle Hidden -Wait -PassThru
  Write-Log 'INFO' "pre-reboot snapshot exit $($bp.ExitCode) -- result line is in backup.log"
}

('{0} {1} graceful restart for Windows Update ({2})' -f (Get-Date -f 's'), $LOCK_TAG, $why) | Set-Content -LiteralPath $LOCK -Encoding ascii

if ($up) {
  Send-Rcon 'say [Server] Restarting for Windows updates now. Back in ~5 min.'
  Send-Rcon 'stop'
  $t0 = Get-Date; $retried = $false
  while ((((Get-ServerProcs).Count -gt 0) -or (Test-PortListening)) -and ((Get-Date) - $t0).TotalSeconds -lt $EXIT_WAIT_SEC) {
    Start-Sleep -Seconds 2
    # This server has dropped an RCON connection mid-stop before (armed-antfix, 09-04): one retry.
    if (-not $retried -and ((Get-Date) - $t0).TotalSeconds -gt 30 -and (Test-PortListening)) {
      Write-Log 'WARN' 'still listening 30 s after stop -- re-sending stop'; Send-Rcon 'stop'; $retried = $true
    }
  }
  $alive = Get-ServerProcs
  if ($alive.Count -gt 0) {
    Write-Log 'WARN' ("JVM still alive after {0} s -- force-killing pid {1} (Windows would hard-kill it anyway)" -f $EXIT_WAIT_SEC, $alive[0].ProcessId)
    $alive | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  } else {
    Write-Log 'OK' ('server exited cleanly in {0:n0} s' -f ((Get-Date) - $t0).TotalSeconds)
  }
}

$st.lastReboot = (Get-Date -f 'yyyy-MM-dd HH:mm:ss'); Save-State
Write-Log 'OK' "rebooting in 60 s (shutdown /r /t 60) -- pending: $why"
$msg = 'Baja Isles: restarting in 60 s to finish Windows updates (Minecraft already saved). Cancel: shutdown /a'
& shutdown.exe /r /t 60 /d p:2:17 /c $msg
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1190) {
  Write-Log 'WARN' "shutdown.exe with a reason code exited $LASTEXITCODE -- retrying without /d"
  & shutdown.exe /r /t 60 /c $msg
}
if ($LASTEXITCODE -eq 1190) { Write-Log 'INFO' 'a shutdown was already scheduled (1190) -- Windows is restarting anyway' }
elseif ($LASTEXITCODE -ne 0) {
  # Clear our lock so the watchdog brings the stopped server back within ~3 min.
  Remove-Item -LiteralPath $LOCK -Force
  Write-Log 'FAIL' "shutdown.exe exited $LASTEXITCODE -- NOT rebooting; lock cleared, the watchdog will restart the server"
  exit 1
}
exit 0
