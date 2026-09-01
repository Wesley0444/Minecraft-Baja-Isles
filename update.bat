@echo off
REM ============================================================================
REM  update.bat  --  controlled maintenance bounce + packwiz sync
REM ----------------------------------------------------------------------------
REM  WHAT IT DOES
REM    1. Self-elevates (starting the SYSTEM boot task at the end requires it).
REM    2. Drops a maintenance lock so the backup script logs [SKIP], not [DOWN].
REM    3. RCON: announces a 60s warning, then graceful stop.
REM    4. Waits for THE SERVER's java process to fully exit (NOT taskkill -- a
REM       modded world killed mid-write is a chunk-corruption event).
REM    5. Takes a full archive backup of the now-quiesced world.
REM    6. Syncs mods/ from the packwiz manifest on GitHub Pages.
REM    7. Rebuilds pack-tools\MOD-INDEX.md so the Discord librarian's modlist
REM       knowledge matches the jars that are actually installed.
REM    8. PAUSES so the operator can review / edit configs, then restarts via
REM       the boot task and clears the lock.
REM
REM  WHY THE PACKWIZ SYNC IS NOT "AUTO-UPDATING"
REM    The manifest pins every mod to an exact file id + hash. The installer
REM    only ever applies changes someone deliberately committed and pushed to
REM    the repo. Nothing here chases "latest" -- a silent library bump is how
REM    the documented Architectury-class conflicts reappear on a months-old
REM    world. Change the pack via packwiz + git; this script only delivers it.
REM
REM  WHY THE WAIT LOOP MATCHES THE COMMAND LINE, NOT "java.exe"
REM    This box is also the owner's gaming rig. His Minecraft CLIENT is a
REM    java.exe too. Doc 02's draft waited on any java.exe and would hang
REM    forever if he was playing. We match the NeoForge argfile path instead.
REM
REM  ORDER MATTERS: announce -> stop -> backup -> sync -> start.
REM  Never back up before the flush; never touch mods/ before the process exits.
REM ============================================================================

REM  /unattended -- skip the operator pauses (no config-edit window, no final
REM  keypress) so the bounce can be driven by a script. Default behaviour is
REM  unchanged: with no argument every pause still blocks as before.
set "UNATTENDED="
if /I "%~1"=="/unattended" set "UNATTENDED=1"

net session >nul 2>&1
if errorlevel 1 (
  echo [update] Elevating...
  if defined UNATTENDED (
    powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0' -ArgumentList '/unattended'"
  ) else (
    powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  )
  exit /b
)

setlocal
set "SRV=C:\Game Servers\Minecraft"
set "JAVA=C:\Program Files\Microsoft\jdk-21.0.4.7-hotspot\bin\java.exe"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"
set "TASK=Minecraft Dedicated Server"
set "PACK_URL=https://wesley0444.github.io/Minecraft-Baja-Isles/pack/pack.toml"

cd /d "%SRV%"

echo [update] Setting maintenance lock...
echo %DATE% %TIME% > "%SRV%\maintenance.lock"

echo [update] Announcing 60s warning via RCON (skips if server is down)...
%PS% -File "%SRV%\backup.ps1" -Mode Announce -Message "Server restarting for maintenance in 60 seconds."
if not errorlevel 1 (
  timeout /t 60 /nobreak
  echo [update] Graceful stop...
  %PS% -File "%SRV%\backup.ps1" -Mode Stop
)

echo [update] Waiting for the SERVER java process to exit (client java is ignored)...
:waitloop
%PS% -Command "if (Get-CimInstance Win32_Process -Filter \"Name='java.exe'\" | Where-Object { $_.CommandLine -match 'neoforged.neoforge.21\.1\.' }) { exit 1 } else { exit 0 }"
if errorlevel 1 (
  timeout /t 5 /nobreak >nul
  goto waitloop
)
echo [update] Server process is down.

echo [update] Archiving the quiesced world...
%PS% -File "%SRV%\backup.ps1" -Mode Archive

echo [update] Syncing mods/ from the packwiz manifest...
"%JAVA%" -jar "%SRV%\packwiz-installer-bootstrap.jar" -g -s server "%PACK_URL%"
if errorlevel 1 (
  echo [update] *** PACKWIZ SYNC FAILED -- server NOT restarted. Fix and re-run. ***
  if not defined UNATTENDED pause
  exit /b 1
)

REM  Rebuild the mod index so the Discord librarian (/ask) can still answer
REM  "which mod owns this modid" and "does anything ban this version" after the
REM  modlist moved. It reads jars, so it MUST run after the sync. Non-fatal:
REM  a stale index is worse than a fresh one but far better than a failed bounce.
echo [update] Rebuilding the mod index for /ask...
%PS% -File "%SRV%\pack-tools\build-mod-index.ps1"
if errorlevel 1 echo [update] WARNING: mod index rebuild failed -- pack-tools\MOD-INDEX.md is now STALE.

echo.
echo ============================================================
echo  SERVER IS DOWN, BACKED UP, AND SYNCED TO THE MANIFEST.
echo  If you are here to edit configs, do it now.
echo  Press any key to restart the server.
echo ============================================================
if not defined UNATTENDED pause

echo [update] Starting the server via the boot task...
schtasks /Run /TN "%TASK%"

del "%SRV%\maintenance.lock" 2>nul
echo [update] Done. Watch logs\latest.log; a config or mod change may not survive boot.
endlocal
if not defined UNATTENDED pause
