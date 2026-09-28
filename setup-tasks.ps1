# =============================================================================
#  setup-tasks.ps1  --  firewall + scheduled tasks + WU active hours, elevated,
#  self-verifying. Called by admin_setup.bat. Do not run this non-elevated; it
#  will lie to you.
# =============================================================================

$ErrorActionPreference = 'Stop'
$SRV  = 'C:\Game Servers\Minecraft'
$LOG  = 'H:\Game Server Backups\Minecraft\setup-tasks.log'
New-Item -ItemType Directory -Force -Path (Split-Path $LOG) | Out-Null
function Log($m) { $l = "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')  $m"; Write-Host $l; Add-Content -Path $LOG -Value $l -Encoding utf8 }

# Windows Update restart window. Active Hours = when Windows will NOT restart by
# itself (18 h is the most it allows); it restarts ~29 min after ACTIVE_END
# (04:29 on 2026-09-09 and 09-15 under the old 10->4). Picked from play history
# 2026-09-15 (314 sessions): someone online 80% of days at 04:29, 12-27% across
# 06:30-10:45. 'Minecraft Smart Reboot' runs from ACTIVE_END:01 to beat Windows
# to it with a graceful stop. Change these two numbers, re-run admin_setup.bat.
$ACTIVE_START = 13
$ACTIVE_END   = 7

# Daily triggers must fire on LOCAL wall-clock time. New-ScheduledTaskTrigger
# stamps StartBoundary with a UTC offset (the registered offsite task read
# "04:15:00-05:00") = "synchronize across time zones", so after DST ends a
# "05:15" fires at 04:15 and a "07:01" at 06:01 -- while Active Hours stay in
# local time. An offset-free StartBoundary is local time. (Found 2026-09-15.)
function LocalAt([string]$hhmm) { ([datetime]::Today + [TimeSpan]::Parse($hhmm)).ToString('s') }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Not elevated. Run admin_setup.bat, not this script directly."
}
Log "=== setup-tasks.ps1 START (elevated) ==="

# --- [1/8] purge stray program-scoped popup rules for java -------------------
Log "[1/8] Removing any 'Query User' / program-scoped java firewall rules..."
$killed = 0
foreach ($r in (Get-NetFirewallRule -Direction Inbound -ErrorAction SilentlyContinue)) {
  $app = $null
  try { $app = ($r | Get-NetFirewallApplicationFilter -ErrorAction Stop).Program } catch { continue }
  if ($app -and ($app -match 'java\.exe$' -or $app -match 'javaw\.exe$')) {
    Log "        DELETE: '$($r.DisplayName)'  action=$($r.Action)  program=$app"
    Remove-NetFirewallRule -Name $r.Name -ErrorAction SilentlyContinue
    $killed++
  }
}
Log "        removed $killed program-scoped java rule(s)."

# --- [2/8] allow the game port, and ONLY the game port ----------------------
Log "[2/8] Firewall ALLOW: TCP 25565, UDP 25565"
foreach ($p in @(@{n='Minecraft (TCP 25565)';x='TCP'}, @{n='Minecraft (UDP 25565)';x='UDP'})) {
  Remove-NetFirewallRule -DisplayName $p.n -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName $p.n -Direction Inbound -Action Allow `
    -Protocol $p.x -LocalPort 25565 -Profile Any -Enabled True | Out-Null
}

# --- [3/8] explicitly BLOCK RCON --------------------------------------------
Log "[3/8] Firewall BLOCK: TCP 25575 (RCON). Block beats Allow; loopback unaffected."
Remove-NetFirewallRule -DisplayName 'Minecraft RCON BLOCK (TCP 25575)' -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName 'Minecraft RCON BLOCK (TCP 25575)' -Direction Inbound `
  -Action Block -Protocol TCP -LocalPort 25575 -Profile Any -Enabled True | Out-Null

# --- [4/8] boot task (SYSTEM) ------------------------------------------------
Log "[4/8] Registering boot task 'Minecraft Dedicated Server' (SYSTEM, ONSTART)"
$a = New-ScheduledTaskAction -Execute "$SRV\launch.bat" -WorkingDirectory $SRV
$t = New-ScheduledTaskTrigger -AtStartup
$p = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
       -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'Minecraft Dedicated Server' -Action $a -Trigger $t `
  -Principal $p -Settings $s -Force | Out-Null

# --- [5/8] backup + presence + watchdog + smart-reboot tasks -----------------
Log "[5/8] Registering 'Minecraft Backup' (every 30 min, SYSTEM)"
$a2 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\backup.ps1`" -Mode Snapshot" -WorkingDirectory $SRV
# NOTE: no -RepetitionDuration. Omitted = repeat indefinitely. Passing
# [TimeSpan]::MaxValue serializes to out-of-range task XML (0x80041318) and the
# registration THROWS -- found live 2026-08-30 (doc 02's draft had it; the proven
# Palworld setup-tasks.ps1 omits it).
$t2 = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
      -RepetitionInterval (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName 'Minecraft Backup' -Action $a2 -Trigger $t2 `
  -Principal $p -Settings $s -Force | Out-Null

# Offsite runs under the INTERACTIVE user: F:\Google Drive is a per-user mount
# and SYSTEM cannot see it. Same lesson as the Palworld offsite task.
# 05:15, not 04:15 (moved 2026-09-15): 04:15 sat inside the old Windows restart
# window and BOTH Windows Update restarts since launch killed it mid-zip (09-09,
# 09-15 -- the latter left a zip with no level.dat). It must stay at :15 or :45:
# Snapshot rewrites the NEWEST slot at :00/:30 and Archive zips the newest slot.
# ~22 min long, so it is done well before Active Hours end at ACTIVE_END.
Log "[5/8] Registering 'Minecraft Backup Offsite' (nightly 05:15, interactive user)"
$a3 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\backup.ps1`" -Mode Archive -Offsite" -WorkingDirectory $SRV
$t3 = New-ScheduledTaskTrigger -Daily -At '05:15'
$t3.StartBoundary = LocalAt '05:15'
$p3 = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'Minecraft Backup Offsite' -Action $a3 -Trigger $t3 `
  -Principal $p3 -Settings $s -Force | Out-Null

# Presence poller -- the Palworld post-mortem's #1 recommendation, on day one.
Log "[5/8] Registering 'Minecraft Presence' (every 5 min, SYSTEM)"
$a4 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\backup.ps1`" -Mode Presence" -WorkingDirectory $SRV
$t4 = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
      -RepetitionInterval (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'Minecraft Presence' -Action $a4 -Trigger $t4 `
  -Principal $p -Settings $s -Force | Out-Null

# Watchdog + Start bridge (added 2026-09-03 after the 02:08 crash sat unnoticed
# for 4 h). Both run as WESLEY via S4U with RunLevel Highest -- the Discord bot's
# proven recipe -- NOT as SYSTEM, on purpose:
#   * `schtasks /Run` from a NON-elevated shell works on a task you own and is
#     "Access is denied" on a SYSTEM task. Claude sessions and scripts run
#     non-elevated, so this is the only way they can start the server without
#     the detached-launch.bat "runs as Wesley until next reboot" hack (this box
#     only reboots when Windows Update makes it, so "until next reboot" can
#     mean weeks).
#   * RunLevel Highest gives the task an elevated token, so from inside it
#     Start-ScheduledTask CAN fire the SYSTEM boot task -> server owned by SYSTEM.
#   * S4U = runs whether Wesley is logged on or not, no stored password (his
#     account has none; blank-password batch logon is blocked by policy).
$pW = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest

Log "[5/8] Registering 'Minecraft Watchdog' (every 3 min, Wesley/S4U/Highest)"
$a5 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\watchdog.ps1`" -Mode Watch" -WorkingDirectory $SRV
$t5 = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
      -RepetitionInterval (New-TimeSpan -Minutes 3)
Register-ScheduledTask -TaskName 'Minecraft Watchdog' -Action $a5 -Trigger $t5 `
  -Principal $pW -Settings $s -Force | Out-Null

# No trigger: fired on demand only ->  schtasks /Run /TN "Minecraft Start"  (or start.bat)
Log "[5/8] Registering 'Minecraft Start' (on-demand bridge, Wesley/S4U/Highest)"
$a6 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\watchdog.ps1`" -Mode Start" -WorkingDirectory $SRV
Register-ScheduledTask -TaskName 'Minecraft Start' -Action $a6 `
  -Principal $pW -Settings $s -Force | Out-Null

# Smart reboot (added 2026-09-15): SYSTEM because it needs the shutdown privilege
# and must see the SYSTEM server's command line. From ACTIVE_END:01, every 15 min
# for 5h45m = the whole window in which Windows may restart on its own. Plus a
# boot trigger: that run only clears the lock the script keeps through its reboot.
$sr = '{0:d2}:01' -f $ACTIVE_END
Log "[5/8] Registering 'Minecraft Smart Reboot' (SYSTEM, daily $sr + every 15 min for 5h45m, + at boot)"
$a7 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\smart-reboot.ps1`"" -WorkingDirectory $SRV
# A -Daily trigger takes no repetition parameters, so borrow them from a -Once
# trigger. FINITE duration only -- [TimeSpan]::MaxValue throws 0x80041318 (above).
$t7 = New-ScheduledTaskTrigger -Daily -At $sr
$t7.Repetition = (New-ScheduledTaskTrigger -Once -At $sr -RepetitionInterval (New-TimeSpan -Minutes 15) `
                  -RepetitionDuration (New-TimeSpan -Hours 5 -Minutes 45)).Repetition
$t7.StartBoundary = LocalAt $sr
$t7b = New-ScheduledTaskTrigger -AtStartup
$t7b.Delay = 'PT1M'
Register-ScheduledTask -TaskName 'Minecraft Smart Reboot' -Action $a7 -Trigger @($t7, $t7b) `
  -Principal $p -Settings $s -Force | Out-Null

# Idle probe for the smart reboot. SYSTEM cannot see console input (WTS
# LastInputTime is 0 for the console session; quser is absent on Home), and this
# is also Wesley's gaming PC -- so smart-reboot.ps1 fires this on demand and it
# answers from INSIDE his session. Interactive = runs only while he is logged
# on. wscript + idle-probe.vbs = no window at all, so it never steals focus
# from a fullscreen game. Same principal as the offsite task (known to write H:).
Log "[5/8] Registering 'Minecraft Idle Probe' (on-demand, interactive user)"
$a8 = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "//B //Nologo `"$SRV\idle-probe.vbs`"" -WorkingDirectory $SRV
Register-ScheduledTask -TaskName 'Minecraft Idle Probe' -Action $a8 `
  -Principal $p3 -Settings $s -Force | Out-Null

# Power watch (added 2026-09-27, the night of the first real outage). EVENT
# trigger, not a schedule: Windows writes Kernel-Power 105 "Power source change"
# with AcOnline=false within a second of the UPS going to battery. This exact
# filter was proven against the System log that night -- it matched all 8 power
# losses since 08-09 and none of the 8 restorations. SYSTEM = runs logged on or
# not. The settings are the point:
#   * AllowStartIfOnBatteries + DontStopIfGoingOnBatteries: this task only EVER
#     runs on battery, and the defaults refuse to start it there (the Discord
#     bot's No-Start-On-Batteries landmine, 2026-08-31).
#   * IgnoreNew + the script's own mutex: one watcher per outage, however much
#     the power flickers (8-9 s blips happen here).
#   * 12 h limit, not $s's unlimited: a hung watcher cannot live forever.
Log "[5/8] Registering 'Minecraft Power Watch' (SYSTEM, on event Kernel-Power 105 AcOnline=false)"
$POWER_XPATH = @'
<QueryList><Query Id="0" Path="System"><Select Path="System">*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and (EventID=105)]] and *[EventData[Data[@Name='AcOnline']='false']]</Select></Query></QueryList>
'@
$a9 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\power-watch.ps1`"" -WorkingDirectory $SRV
$t9 = New-CimInstance -ClientOnly `
      -CimClass (Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace 'Root/Microsoft/Windows/TaskScheduler')
$t9.Enabled      = $true
$t9.Subscription = $POWER_XPATH
$s9 = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
       -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 12) `
       -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName 'Minecraft Power Watch' -Action $a9 -Trigger $t9 `
  -Principal $p -Settings $s9 -Force | Out-Null

# --- [6/8] Windows Update Active Hours -----------------------------------------
# Same keys the Settings app writes (Settings > Windows Update > Advanced options
# > Active hours shows the result). SmartActiveHoursState is left alone: it is 0
# and the manual 10->4 was honoured under it (restarts landed at 04:29).
Log "[6/8] Windows Update Active Hours -> ${ACTIVE_START}:00-${ACTIVE_END}:00 (Windows may restart ${ACTIVE_END}:00-${ACTIVE_START}:00)"
$ux = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
$before = Get-ItemProperty -Path $ux -ErrorAction SilentlyContinue
Log ("        was: ActiveHoursStart={0} ActiveHoursEnd={1}" -f $before.ActiveHoursStart, $before.ActiveHoursEnd)
# NOT New-Item -Force: on the registry provider that REPLACES an existing key, values and all.
if (-not (Test-Path $ux)) { New-Item -Path $ux | Out-Null }
Set-ItemProperty -Path $ux -Name 'ActiveHoursStart' -Value $ACTIVE_START -Type DWord
Set-ItemProperty -Path $ux -Name 'ActiveHoursEnd'   -Value $ACTIVE_END   -Type DWord

# --- [7/8] SELF-VERIFY WHILE STILL ELEVATED. This output is the truth. -------
Log "[7/8] VERIFY (elevated) --------------------------------------------------"
foreach ($n in 'Minecraft (TCP 25565)','Minecraft (UDP 25565)','Minecraft RCON BLOCK (TCP 25575)') {
  # Resolve BY NAME. Bulk enumeration is what returns partial lists.
  $r = Get-NetFirewallRule -DisplayName $n -ErrorAction SilentlyContinue
  if ($r) {
    $pf = $r | Get-NetFirewallPortFilter
    Log ("        FW  {0,-38} Enabled={1} Action={2} {3}/{4}" -f $n,$r.Enabled,$r.Action,$pf.Protocol,$pf.LocalPort)
  } else { Log "        FW  $n  *** MISSING ***" }
}
foreach ($n in 'Minecraft Dedicated Server','Minecraft Backup','Minecraft Backup Offsite','Minecraft Presence','Minecraft Watchdog','Minecraft Start','Minecraft Smart Reboot','Minecraft Idle Probe','Minecraft Power Watch') {
  $tk = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
  if ($tk) { Log ("        TASK {0,-30} State={1} User={2} Logon={3} RunLevel={4}" -f $n,$tk.State,$tk.Principal.UserId,$tk.Principal.LogonType,$tk.Principal.RunLevel) }
  else     { Log "        TASK $n  *** MISSING ***" }
}
foreach ($n in 'Minecraft Backup Offsite','Minecraft Smart Reboot') {
  $tk = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
  if ($tk) {
    $tr = $tk.Triggers[0]
    Log ("        TRIG {0,-30} Start={1} Repeat={2} For={3} (triggers: {4})" -f $n, $tr.StartBoundary, $tr.Repetition.Interval, $tr.Repetition.Duration, @($tk.Triggers).Count)
    if ($tr.StartBoundary -match '(Z|[+-]\d\d:\d\d)$') { Log "        *** VERIFY FAILED: '$n' trigger is UTC-anchored -- it will drift an hour at DST ***" }
  }
}
# The two Wesley tasks MUST be S4U + Highest or the whole bridge idea is dead
# (Interactive-only = never fires at boot / when logged off; non-Highest = cannot
# poke the SYSTEM task). Fail loudly rather than let it look registered.
foreach ($n in 'Minecraft Watchdog','Minecraft Start') {
  $tk = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
  if ($tk -and ($tk.Principal.LogonType -ne 'S4U' -or $tk.Principal.RunLevel -ne 'Highest')) {
    Log "        *** VERIFY FAILED: '$n' is $($tk.Principal.LogonType)/$($tk.Principal.RunLevel), need S4U/Highest ***"
  }
}
# The power watch only ever runs on battery, so a battery-blocking setting would
# make it look registered and never fire. Also re-prove the filter against this
# box's real history -- a wrong XPath registers fine and matches nothing.
$tk = Get-ScheduledTask -TaskName 'Minecraft Power Watch' -ErrorAction SilentlyContinue
if ($tk) {
  $tr = $tk.Triggers[0]
  $hits = @(Get-WinEvent -FilterXml ([xml]$tr.Subscription) -ErrorAction SilentlyContinue).Count
  Log ("        TRIG {0,-30} Type={1} OnBattery-ok={2} Instances={3} Limit={4} filter-matches-history={5}" -f 'Minecraft Power Watch',
       $tr.CimClass.CimClassName, (-not $tk.Settings.DisallowStartIfOnBatteries -and -not $tk.Settings.StopIfGoingOnBatteries),
       $tk.Settings.MultipleInstances, $tk.Settings.ExecutionTimeLimit, $hits)
  if ($tk.Settings.DisallowStartIfOnBatteries -or $tk.Settings.StopIfGoingOnBatteries) {
    Log "        *** VERIFY FAILED: 'Minecraft Power Watch' will not run on battery -- the only time it ever runs ***"
  }
  if ($tr.CimClass.CimClassName -ne 'MSFT_TaskEventTrigger' -or $hits -lt 1) {
    Log "        *** VERIFY FAILED: 'Minecraft Power Watch' trigger is not a working event filter (matches $hits past events) ***"
  }
}
$ah = Get-ItemProperty -Path $ux -ErrorAction SilentlyContinue
Log ("        WU  ActiveHoursStart={0} ActiveHoursEnd={1} SmartActiveHoursState={2}" -f $ah.ActiveHoursStart, $ah.ActiveHoursEnd, $ah.SmartActiveHoursState)
if ($ah.ActiveHoursStart -ne $ACTIVE_START -or $ah.ActiveHoursEnd -ne $ACTIVE_END) {
  Log "        *** VERIFY FAILED: Active Hours did not stick -- set them in Settings > Windows Update > Advanced options ***"
}
# Live-fire the bridge while elevated: with the server up it must log "already
# running" to Watchdog\watchdog.log within a few seconds. Proves the task runs.
Log "[7/8] Live-firing 'Minecraft Start' (expects 'already running' in Watchdog\watchdog.log)"
Start-ScheduledTask -TaskName 'Minecraft Start' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 12
$wl = Get-Content "$SRV\Watchdog\watchdog.log" -Tail 2 -ErrorAction SilentlyContinue
if ($wl) { $wl | ForEach-Object { Log "        WDLOG $_" } } else { Log "        *** no Watchdog\watchdog.log line yet -- check task history for 'Minecraft Start' ***" }
# Fire the idle probe the way smart-reboot.ps1 will: a fresh number in
# console-idle.txt proves the task runs in Wesley's session and can write H:.
Log "[7/8] Live-firing 'Minecraft Idle Probe' (expects a fresh console-idle.txt)"
$idf = 'H:\Game Server Backups\Minecraft\console-idle.txt'
Remove-Item -LiteralPath $idf -Force -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName 'Minecraft Idle Probe' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 10
if (Test-Path $idf) { Log "        IDLE  desktop idle = $((Get-Content $idf -Raw).Trim()) s  (probe works)" }
else { Log "        *** VERIFY FAILED: idle probe wrote nothing -- smart-reboot will treat the desktop as 'not logged on' ***" }
# Live-fire the power watch on AC power: as SYSTEM it must log a START line
# naming NT AUTHORITY\SYSTEM plus an AC poll. On AC it says nothing and touches
# nothing (it would just wait 15 min to exit), so stop it once proven.
Log "[7/8] Live-firing 'Minecraft Power Watch' (expects START as SYSTEM + an AC poll in power-watch.log)"
$pwl = 'H:\Game Server Backups\Minecraft\power-watch.log'
$fired = Get-Date
Start-ScheduledTask -TaskName 'Minecraft Power Watch' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 12
$fresh = @(Get-Content $pwl -Tail 6 -ErrorAction SilentlyContinue | Where-Object {
  $_ -match '^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)' -and [datetime]$Matches[1] -ge $fired.AddSeconds(-2) })
$fresh | ForEach-Object { Log "        PWLOG $_" }
if (-not ($fresh -match 'START as NT AUTHORITY\\SYSTEM') -or -not ($fresh -match '\[POLL\]')) {
  Log "        *** VERIFY FAILED: power watch did not start as SYSTEM and poll -- check task history for 'Minecraft Power Watch' ***"
}
Stop-ScheduledTask -TaskName 'Minecraft Power Watch' -ErrorAction SilentlyContinue
# Dry-run the smart reboot elevated (sees the SYSTEM server): touches nothing,
# proves the script runs and shows what it would decide right now.
Log "[7/8] Dry-running smart-reboot.ps1 (elevated, touches nothing)"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$SRV\smart-reboot.ps1" -DryRun |
  ForEach-Object { Log "        SR    $_" }

# --- [8/8] start the server if it is not already running ---------------------
# Match on THIS folder's libraries path, not 'neoforge' -- Wesley's client is
# NeoForge java on this box too (same discriminator watchdog.ps1 uses).
$running = Get-CimInstance Win32_Process -Filter "Name='java.exe'" -ErrorAction SilentlyContinue |
           Where-Object { $_.CommandLine -like '*Game Servers\Minecraft\libraries*' }
if ($running) {
  Log "[8/8] Server already running (PID $($running.ProcessId)) -- not starting again."
} else {
  Log "[8/8] Starting the server via the boot task..."
  Start-ScheduledTask -TaskName 'Minecraft Dedicated Server'
}
Log "=== setup-tasks.ps1 DONE. Log: $LOG ==="
