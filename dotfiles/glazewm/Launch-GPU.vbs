' Launch-GPU.vbs - Silent runner for GPU telemetry daemon
Option Explicit
Dim objShell
Set objShell = CreateObject("WScript.Shell")

' Terminate any existing Update-GPU powershell daemon cleanly
On Error Resume Next
objShell.Run "pwsh.exe -NoProfile -WindowStyle Hidden -Command ""Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*Update-GPU.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }""", 0, True
On Error GoTo 0

WScript.Sleep 250

' Launch Update-GPU.ps1 completely hidden
objShell.Run "pwsh.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & objShell.ExpandEnvironmentStrings("%USERPROFILE%\.glzr\Update-GPU.ps1") & """", 0, False
