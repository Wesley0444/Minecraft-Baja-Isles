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
REM      4. Registers the SYSTEM boot task and the backup/presence tasks.
REM      5. SELF-VERIFIES while still elevated and writes the result to a log.
REM      6. Starts the server via the boot task if it is not already running.
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
