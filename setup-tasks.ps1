# =============================================================================
#  setup-tasks.ps1  --  firewall + scheduled tasks, elevated, self-verifying
#  Called by admin_setup.bat. Do not run this non-elevated; it will lie to you.
# =============================================================================

$ErrorActionPreference = 'Stop'
$SRV  = 'C:\Game Servers\Minecraft'
$LOG  = 'H:\Game Server Backups\Minecraft\setup-tasks.log'
New-Item -ItemType Directory -Force -Path (Split-Path $LOG) | Out-Null
function Log($m) { $l = "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')  $m"; Write-Host $l; Add-Content -Path $LOG -Value $l -Encoding utf8 }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Not elevated. Run admin_setup.bat, not this script directly."
}
Log "=== setup-tasks.ps1 START (elevated) ==="

# --- [1/7] purge stray program-scoped popup rules for java -------------------
Log "[1/7] Removing any 'Query User' / program-scoped java firewall rules..."
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

# --- [2/7] allow the game port, and ONLY the game port ----------------------
Log "[2/7] Firewall ALLOW: TCP 25565, UDP 25565"
foreach ($p in @(@{n='Minecraft (TCP 25565)';x='TCP'}, @{n='Minecraft (UDP 25565)';x='UDP'})) {
  Remove-NetFirewallRule -DisplayName $p.n -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName $p.n -Direction Inbound -Action Allow `
    -Protocol $p.x -LocalPort 25565 -Profile Any -Enabled True | Out-Null
}

# --- [3/7] explicitly BLOCK RCON --------------------------------------------
Log "[3/7] Firewall BLOCK: TCP 25575 (RCON). Block beats Allow; loopback unaffected."
Remove-NetFirewallRule -DisplayName 'Minecraft RCON BLOCK (TCP 25575)' -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName 'Minecraft RCON BLOCK (TCP 25575)' -Direction Inbound `
  -Action Block -Protocol TCP -LocalPort 25575 -Profile Any -Enabled True | Out-Null

# --- [4/7] boot task (SYSTEM) ------------------------------------------------
Log "[4/7] Registering boot task 'Minecraft Dedicated Server' (SYSTEM, ONSTART)"
$a = New-ScheduledTaskAction -Execute "$SRV\launch.bat" -WorkingDirectory $SRV
$t = New-ScheduledTaskTrigger -AtStartup
$p = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
       -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'Minecraft Dedicated Server' -Action $a -Trigger $t `
  -Principal $p -Settings $s -Force | Out-Null

# --- [5/7] backup + presence tasks -------------------------------------------
Log "[5/7] Registering 'Minecraft Backup' (every 30 min, SYSTEM)"
$a2 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\backup.ps1`" -Mode Snapshot" -WorkingDirectory $SRV
# NOTE: no -RepetitionDuration. Omitted = repeat indefinitely. Passing
# [TimeSpan]::MaxValue serializes to out-of-range task XML (0x80041318) and the
# registration THROWS — found live 2026-08-30 (doc 02's draft had it; the proven
# Palworld setup-tasks.ps1 omits it).
$t2 = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
      -RepetitionInterval (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName 'Minecraft Backup' -Action $a2 -Trigger $t2 `
  -Principal $p -Settings $s -Force | Out-Null

# Offsite runs under the INTERACTIVE user: F:\Google Drive is a per-user mount
# and SYSTEM cannot see it. Same lesson as the Palworld offsite task.
Log "[5/7] Registering 'Minecraft Backup Offsite' (nightly 04:15, interactive user)"
$a3 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\backup.ps1`" -Mode Archive -Offsite" -WorkingDirectory $SRV
$t3 = New-ScheduledTaskTrigger -Daily -At '04:15'
$p3 = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'Minecraft Backup Offsite' -Action $a3 -Trigger $t3 `
  -Principal $p3 -Settings $s -Force | Out-Null

# Presence poller -- the Palworld post-mortem's #1 recommendation, on day one.
Log "[5/7] Registering 'Minecraft Presence' (every 5 min, SYSTEM)"
$a4 = New-ScheduledTaskAction -Execute 'powershell.exe' `
      -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$SRV\backup.ps1`" -Mode Presence" -WorkingDirectory $SRV
$t4 = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
      -RepetitionInterval (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'Minecraft Presence' -Action $a4 -Trigger $t4 `
  -Principal $p -Settings $s -Force | Out-Null

# --- [6/7] SELF-VERIFY WHILE STILL ELEVATED. This output is the truth. -------
Log "[6/7] VERIFY (elevated) --------------------------------------------------"
foreach ($n in 'Minecraft (TCP 25565)','Minecraft (UDP 25565)','Minecraft RCON BLOCK (TCP 25575)') {
  # Resolve BY NAME. Bulk enumeration is what returns partial lists.
  $r = Get-NetFirewallRule -DisplayName $n -ErrorAction SilentlyContinue
  if ($r) {
    $pf = $r | Get-NetFirewallPortFilter
    Log ("        FW  {0,-38} Enabled={1} Action={2} {3}/{4}" -f $n,$r.Enabled,$r.Action,$pf.Protocol,$pf.LocalPort)
  } else { Log "        FW  $n  *** MISSING ***" }
}
foreach ($n in 'Minecraft Dedicated Server','Minecraft Backup','Minecraft Backup Offsite','Minecraft Presence') {
  $tk = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
  if ($tk) { Log ("        TASK {0,-30} State={1} User={2}" -f $n,$tk.State,$tk.Principal.UserId) }
  else     { Log "        TASK $n  *** MISSING ***" }
}

# --- [7/7] start the server if it is not already running ---------------------
$running = Get-CimInstance Win32_Process -Filter "Name='java.exe'" -ErrorAction SilentlyContinue |
           Where-Object { $_.CommandLine -match 'neoforged.neoforge' }
if ($running) {
  Log "[7/7] Server already running (PID $($running.ProcessId)) -- not starting again."
} else {
  Log "[7/7] Starting the server via the boot task..."
  Start-ScheduledTask -TaskName 'Minecraft Dedicated Server'
}
Log "=== setup-tasks.ps1 DONE. Log: $LOG ==="
