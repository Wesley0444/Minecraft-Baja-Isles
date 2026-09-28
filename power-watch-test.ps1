<#
=============================================================================
 power-watch-test.ps1  --  simulated outages for power-watch.ps1
-----------------------------------------------------------------------------
 Runs power-watch.ps1 with -SimulateFile against a FAKE UPS (a JSON file) and
 a FAKE server (a "1"/"0" file). RCON, the real maintenance.lock, the real log
 and the real server are never touched; each scenario's log/lock/markers live
 in %TEMP%\power-watch-sim\<scenario>. ~3 min. Re-run after ANY edit to
 power-watch.ps1 -- it fires unattended as SYSTEM during an emergency, which is
 the worst possible time to find a bug.
   S1 2 s blip -> silence      S2 full drain -> stop -> hold -> release
   S3 AC back mid-countdown    S4 server started by hand while HELD
   S5 mutex + abort file       S6 runtime-estimate trigger
   S7 "power is back" message, said once
 40/40 PASS 2026-09-27.
=============================================================================
#>
$ErrorActionPreference = 'Stop'
$PW   = 'C:\Game Servers\Minecraft\power-watch.ps1'
$ROOT = Join-Path $env:TEMP 'power-watch-sim'
if (-not (Test-Path $ROOT)) { New-Item -ItemType Directory $ROOT | Out-Null }
$FAST = '-PollSec 1 -NoticeAfterSec 3 -CountdownSec 4 -AcStableMin 0.1 -ExitAfterAcMin 0.15'
$results = @()

function New-Scn([string]$name, [bool]$bat, [int]$charge, [int]$rt = 60) {
  $d = Join-Path $ROOT $name
  if (Test-Path $d) { Get-ChildItem $d | ForEach-Object { [IO.File]::Delete($_.FullName) } } else { New-Item -ItemType Directory $d | Out-Null }
  $sim = Join-Path $d 'power.json'
  Set-Pow $sim $bat $charge $rt
  [IO.File]::WriteAllText("$sim.server", '1')
  return $sim
}
function Set-Pow($sim, [bool]$bat, [int]$charge, [int]$rt = 60) {
  [IO.File]::WriteAllText($sim, (@{ onBattery = $bat; charge = $charge; runtime = $rt } | ConvertTo-Json -Compress))
}
function Start-PW($sim) {
  Start-Process powershell.exe -PassThru -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PW`" -SimulateFile `"$sim`" $FAST"
}
function LogOf($sim) { $l = Join-Path (Split-Path $sim) 'power-watch.log'; if (Test-Path $l) { [IO.File]::ReadAllText($l) } else { '' } }
function Wait-Log($sim, [string]$pat, [int]$sec = 30) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $sec) { if ((LogOf $sim) -match $pat) { return $true }; Start-Sleep -Milliseconds 300 }
  return $false
}
function Wait-Exit($proc, [int]$sec = 40) {
  if (-not $proc.WaitForExit($sec * 1000)) { $proc.Kill(); return $false }; return $true
}
function Check([string]$scn, [string]$what, [bool]$ok) {
  $script:results += [pscustomobject]@{ Scenario = $scn; Check = $what; Pass = $ok }
}
function LockOf($sim) { $l = Join-Path (Split-Path $sim) 'maintenance.lock'; if (Test-Path $l) { [IO.File]::ReadAllText($l) } else { $null } }
function SrvOf($sim) { [IO.File]::ReadAllText("$sim.server").Trim() }

# ---- S1: 2 s blip -> silence
$s = New-Scn 'S1-blip' $true 100
$p = Start-PW $s; Start-Sleep -Milliseconds 1500; Set-Pow $s $false 100
$ex = Wait-Exit $p
$L = LogOf $s
Check S1 'exited on its own' $ex
Check S1 'nothing said to players' (-not ($L -match 'said:'))
Check S1 'no trigger' (-not ($L -match 'TRIGGER'))
Check S1 'AC-stable exit logged' ($L -match 'AC stable .* exiting')

# ---- S2: full outage -> notice, warn, stop, hold, release
$s = New-Scn 'S2-full' $true 100
$p = Start-PW $s
Check S2 'notice after the delay' (Wait-Log $s 'said: Heads up' 10)
Set-Pow $s $true 30
Check S2 'warn at 30%' (Wait-Log $s 'said: UPS battery at 30%' 10)
Set-Pow $s $true 20
Check S2 'trigger at 20%' (Wait-Log $s 'TRIGGER: charge 20%' 10)
Check S2 'lock written with countdown' ((LockOf $s) -like 'power-watch:*')
Check S2 'stop sent + server stopped' (Wait-Log $s '\[OK\].*server stopped' 20)
Check S2 'DONE marker' (Test-Path (Join-Path (Split-Path $s) 'POWER-STOP-DONE.txt'))
Start-Sleep 2
Check S2 'held: still down, lock kept' (((SrvOf $s) -eq '0') -and ((LockOf $s) -like 'power-watch:*'))
Set-Pow $s $false 12
Check S2 'release after AC stable' (Wait-Log $s 'RELEASE: AC stable' 20)
Check S2 'lock removed on release' (Wait-Log $s 'removed our maintenance.lock' 5)
Check S2 'start via bridge requested' ((LogOf $s) -match 'would run: schtasks /Run /TN "Minecraft Start"')
Check S2 'server up after release' (Wait-Log $s '\[OK\].*server port up' 15)
$ex = Wait-Exit $p
Check S2 'exited on its own' $ex
Check S2 'no lock left' ($null -eq (LockOf $s))

# ---- S3: power back mid-countdown -> cancel
$s = New-Scn 'S3-cancel' $true 20
$p = Start-PW $s
Check S3 'trigger' (Wait-Log $s 'TRIGGER' 10)
Start-Sleep -Seconds 1; Set-Pow $s $false 20
Check S3 'cancelled' (Wait-Log $s 'CANCELLED' 15)
Check S3 'cancel told to players' ((LogOf $s) -match 'said: Power is back - shutdown cancelled')
Check S3 'no stop sent' (-not ((LogOf $s) -match 'would send: stop'))
Check S3 'lock removed' ($null -eq (LockOf $s))
Check S3 'server still up' ((SrvOf $s) -eq '1')
Check S3 'exited on its own' (Wait-Exit $p)

# ---- S4: someone starts the server while HELD -> back to WATCH
$s = New-Scn 'S4-manual' $true 20
$p = Start-PW $s
Check S4 'stopped' (Wait-Log $s '\[OK\].*server stopped' 25)
Set-Pow $s $false 12; [IO.File]::WriteAllText("$s.server", '1')
Check S4 'back to WATCH' (Wait-Log $s 'up again while HELD' 10)
Check S4 'lock removed' ($null -eq (LockOf $s))
Check S4 'exited on its own' (Wait-Exit $p)
Check S4 'no RELEASE / no second start' (-not ((LogOf $s) -match 'RELEASE'))

# ---- S5: second instance refused + abort file
$s = New-Scn 'S5-mutex' $true 100
$p = Start-PW $s; Start-Sleep 2
$p2 = Start-PW $s
Check S5 'second instance exits fast' (Wait-Exit $p2 10)
Check S5 'second instance logged the mutex' ((LogOf $s) -match 'another power-watch already holds')
[IO.File]::WriteAllText((Join-Path (Split-Path $s) 'POWER-WATCH-ABORT.txt'), 'x')
Check S5 'abort file stops the first' (Wait-Exit $p 10)
Check S5 'abort logged' ((LogOf $s) -match 'abort file present')

# ---- S6: runtime collapse triggers while % still looks fine
$s = New-Scn 'S6-runtime' $true 60 5
$p = Start-PW $s
Check S6 'runtime trigger' (Wait-Log $s 'TRIGGER: runtime 5 min' 10)
Set-Pow $s $false 60
Check S6 'cancelled' (Wait-Log $s 'CANCELLED' 15)
Check S6 'exited on its own' (Wait-Exit $p)

# ---- S7: noticed outage ends -> "power is back"
$s = New-Scn 'S7-back' $true 100
$p = Start-PW $s
Check S7 'notice' (Wait-Log $s 'said: Heads up' 10)
Set-Pow $s $false 95
Check S7 'power-back message' (Wait-Log $s 'said: Power is back at the host' 10)
Check S7 'exited on its own' (Wait-Exit $p)
Check S7 'said once, not every poll' (([regex]::Matches((LogOf $s), 'said: Power is back at the host')).Count -eq 1)

$results | Format-Table -AutoSize | Out-String -Width 200
"PASS {0} / {1}" -f @($results | Where-Object Pass).Count, $results.Count
