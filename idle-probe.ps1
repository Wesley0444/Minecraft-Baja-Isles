# =============================================================================
#  idle-probe.ps1  --  how long has this desktop session had no keyboard/mouse
#  input? Writes whole seconds to H:\Game Server Backups\Minecraft\console-idle.txt
#
#  Asked for by smart-reboot.ps1, which runs as SYSTEM and CANNOT see console
#  input: WTS LastInputTime is 0 for the console session, and quser/qwinsta do
#  not exist on Windows 11 Home (both checked 2026-09-15). GetLastInputInfo only
#  answers for the CALLER'S session, so this has to run inside Wesley's.
#  Launched with no window by idle-probe.vbs via the on-demand task
#  'Minecraft Idle Probe' (Wesley, Interactive -- runs only while he is logged on).
# =============================================================================
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class ConsoleIdle {
  [StructLayout(LayoutKind.Sequential)] struct LII { public uint cbSize; public uint dwTime; }
  [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LII p);
  public static uint Seconds() {
    var l = new LII(); l.cbSize = (uint)Marshal.SizeOf(l);
    GetLastInputInfo(ref l);
    return unchecked((uint)Environment.TickCount - l.dwTime) / 1000;   // uint math survives the 49.7-day tick wrap
  }
}
"@
[IO.File]::WriteAllText('H:\Game Server Backups\Minecraft\console-idle.txt', [string][ConsoleIdle]::Seconds())
