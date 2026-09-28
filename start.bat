@echo off
REM ============================================================================
REM  start.bat  --  start the Minecraft server UNDER THE SYSTEM BOOT TASK,
REM                 from any shell, elevated or not.
REM ----------------------------------------------------------------------------
REM  Fires the Wesley-owned 'Minecraft Start' task (schtasks /Run is allowed on
REM  your own tasks non-elevated). That task runs elevated and hands off to the
REM  SYSTEM boot task via watchdog.ps1 -Mode Start, so the server is owned by
REM  SYSTEM every time -- not "as Wesley until next reboot" (= ~6 weeks here).
REM  NEVER start launch.bat directly from a session; use this.
REM  Already running? The task logs "already running" and does nothing.
REM  Result: Watchdog\watchdog.log (tailed below).
REM ============================================================================
schtasks /Run /TN "Minecraft Start"
if errorlevel 1 (
  echo [start] schtasks /Run failed. Task not registered yet? Run admin_setup.bat as admin once.
  exit /b 1
)
echo [start] fired. Watchdog\watchdog.log in ~10 s:
timeout /t 10 /nobreak >nul
powershell -NoProfile -Command "Get-Content 'C:\Game Servers\Minecraft\Watchdog\watchdog.log' -Tail 4"
