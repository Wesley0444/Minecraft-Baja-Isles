' idle-probe.vbs -- launched by the on-demand task 'Minecraft Idle Probe' (Wesley,
' Interactive) when smart-reboot.ps1 needs to know whether he is at the PC.
' Runs idle-probe.ps1 with window style 0 = no window at all. A plain
' "powershell -WindowStyle Hidden" still flashes a console for a moment, which
' would steal focus from a fullscreen game -- the exact person this protects.
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""C:\Game Servers\Minecraft\idle-probe.ps1""", 0, False
