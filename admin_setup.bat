@echo off
REM ============================================================================
REM  admin_setup.bat  --  RUN ONCE AS ADMIN, BEFORE THE FIRST EVER SERVER BOOT
REM ----------------------------------------------------------------------------
REM  WHAT IT DOES
REM    Self-elevates and hands off to setup-tasks.ps1, which:
REM      1. Deletes any stray program-scoped "Query User" firewall rules for
REM         java.exe / javaw.exe.
REM      2. Adds ALLOW inbound TCP 25565 and UDP 25565 (the game port, only).
REM      3. Adds an explicit BLOCK inbound on TCP 25575 (RCON).
REM      4. Registers the SYSTEM boot task, the backup/presence tasks (offsite
REM         archive nightly 05:15), the Wesley/S4U 'Minecraft Watchdog' (3 min
REM         crash watchdog) + 'Minecraft Start' (non-elevated start bridge)
REM         tasks -> watchdog.ps1, and (since 2026-09-15) the SYSTEM
REM         'Minecraft Smart Reboot' task -> smart-reboot.ps1, which takes
REM         Windows Update's restart gracefully from 07:01, plus the on-demand
REM         'Minecraft Idle Probe' (your session, no window) it uses to check
REM         nobody is at the desktop before rebooting, and (since 2026-09-27)
REM         the SYSTEM 'Minecraft Power Watch' task -> power-watch.ps1, fired by
REM         the power-loss event (Kernel-Power 105, AcOnline=false): it stops
REM         the server cleanly at 20% UPS and restarts it once power is back.
REM      5. Sets Windows Update Active Hours to 13:00-07:00, so Windows only
REM         restarts by itself in the 07:00-13:00 quiet band (it had been
REM         restarting at 04:29, when someone is online 80% of days).
REM      6. SELF-VERIFIES while still elevated (incl. a smart-reboot dry run
REM         and a live-fire of the power watch on AC, which is harmless)
REM         and writes the result to a log.
REM      7. Starts the server via the boot task if it is not already running.
REM    Re-running is safe and is also the REVIVE path after a mothball.
REM
REM  WHY IT MUST RUN BEFORE THE FIRST BOOT  ***READ THIS***
REM    The first time java.exe binds a port, Windows pops the Firewall dialog.
REM    Clicking "Allow access" creates a PROGRAM-SCOPED rule with LocalPort=Any,
REM    which allows EVERY port that exe ever listens on -- including RCON 25575.
REM    That silently defeats "we only opened the game port". This exact thing
REM    happened on the Palworld server: four "Query User" rules scoped to the
REM    exe with LocalPort=Any left the admin API LAN-reachable for 19 days.
REM    Create the rules FIRST. If the dialog appears anyway, click CANCEL.
REM    And note: vanilla Minecraft has no rcon bind-address setting -- RCON
REM    listens on 0.0.0.0:25575. The BLOCK rule is the ONLY thing closing it.
REM    Block beats Allow in Windows Firewall, so a future stray "Allow" click
REM    cannot silently reopen it. Loopback is unaffected (127.0.0.1 never
REM    traverses the firewall), so backup.ps1 still reaches RCON.
REM
REM  AND: NEVER AUDIT THE FIREWALL OR SCHEDULED TASKS FROM A NORMAL SHELL.
REM    Get-NetFirewallPortFilter throws Access Denied partway through bulk
REM    enumeration and returns a PARTIAL LIST instead of failing -- it will
REM    silently drop rules and tell you they do not exist. Same trap as
REM    SYSTEM-owned scheduled tasks, which Get-ScheduledTask silently omits and
REM    schtasks /query reports as "Access is denied" (which is NOT "missing" --
REM    a genuinely absent task says "cannot find the file"). setup-tasks.ps1
REM    self-verifies while elevated; THAT output is the source of truth.
REM ============================================================================

net session >nul 2>&1
if errorlevel 1 (
  echo [admin_setup] Elevating...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Game Servers\Minecraft\setup-tasks.ps1"
pause
