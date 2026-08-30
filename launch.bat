@echo off
REM ============================================================================
REM  launch.bat  --  Minecraft 1.21.1 / NeoForge 21.1.249 dedicated server
REM ----------------------------------------------------------------------------
REM  WHAT IT DOES
REM    Starts the server in the foreground of whatever process calls it. The
REM    Task Scheduler boot task runs this as SYSTEM with no window, so the
REM    server runs headless from boot before anyone logs in.
REM
REM  WHY IT IS WRITTEN THIS WAY
REM    * ABSOLUTE PATH TO java.exe. The SYSTEM account does not inherit the
REM      interactive user's PATH. Bare "java" works when you double-click this
REM      and fails silently at boot. This is the #1 way a SYSTEM game-server
REM      task looks "registered but never runs". (Also: bare "java" on THIS box
REM      resolves to JDK 23, which NeoForge 1.21.1 must not run on.)
REM    * We do NOT use NeoForge's stock run.bat. That reads user_jvm_args.txt,
REM      giving flags a second place to hide. All JVM flags live here, once.
REM    * -XX:-OmitStackTraceInFastThrow keeps stack traces intact after the JIT
REM      warms up. Without it, repeated exceptions log with NO trace at all --
REM      exactly the "useless stack trace" problem we are trying to avoid while
REM      bisecting ~110 mods.
REM    * Heap dumps go to H: because a 10GB heap makes a 10GB dump file.
REM
REM  OPERATING
REM    Start now without rebooting : schtasks /Run /TN "Minecraft Dedicated Server"   (elevated!)
REM    Graceful stop with backup   : update.bat
REM    Quick graceful stop         : powershell -NoProfile -ExecutionPolicy Bypass
REM                                    -File backup.ps1 -Mode Stop
REM ============================================================================

setlocal
set "SRV=C:\Game Servers\Minecraft"
set "JAVA=C:\Program Files\Microsoft\jdk-21.0.4.7-hotspot\bin\java.exe"
set "NFARGS=%SRV%\libraries\net\neoforged\neoforge\21.1.249\win_args.txt"
set "DUMPS=H:\Game Server Backups\Minecraft\heapdumps"

if not exist "%JAVA%" (
  echo [launch] FATAL: java.exe not found at "%JAVA%"
  exit /b 1
)
if not exist "%NFARGS%" (
  echo [launch] FATAL: NeoForge argfile not found at "%NFARGS%"
  echo [launch] Re-run the NeoForge installer, or fix the version in this script.
  exit /b 1
)
if not exist "%DUMPS%" mkdir "%DUMPS%"

cd /d "%SRV%"

"%JAVA%" ^
  -Xms10G -Xmx10G ^
  -XX:+UseG1GC ^
  -XX:+ParallelRefProcEnabled ^
  -XX:MaxGCPauseMillis=200 ^
  -XX:+UnlockExperimentalVMOptions ^
  -XX:+DisableExplicitGC ^
  -XX:+AlwaysPreTouch ^
  -XX:G1NewSizePercent=30 ^
  -XX:G1MaxNewSizePercent=40 ^
  -XX:G1HeapRegionSize=8M ^
  -XX:G1ReservePercent=20 ^
  -XX:G1HeapWastePercent=5 ^
  -XX:G1MixedGCCountTarget=4 ^
  -XX:InitiatingHeapOccupancyPercent=15 ^
  -XX:G1MixedGCLiveThresholdPercent=90 ^
  -XX:G1RSetUpdatingPauseTimePercent=5 ^
  -XX:SurvivorRatio=32 ^
  -XX:+PerfDisableSharedMem ^
  -XX:MaxTenuringThreshold=1 ^
  -XX:-OmitStackTraceInFastThrow ^
  -XX:+HeapDumpOnOutOfMemoryError ^
  -XX:HeapDumpPath="%DUMPS%" ^
  -Dfile.encoding=UTF-8 ^
  -Dusing.aikars.flags=https://mcflags.emc.gs ^
  -Daikars.new.flags=true ^
  @"%NFARGS%" nogui

endlocal
