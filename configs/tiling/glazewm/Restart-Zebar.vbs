' Restart-Zebar.vbs - Robust Zebar Restarter
' Executes silently via wscript.exe, cleans up zombie instances, and dispatches via explorer.exe

Option Explicit
Dim objShell, objFSO, zebarPath

Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

Function ResolveZebar()
    Dim envPath, pathDirs, d, testPath, candidates, c

    ' 1. Check standard installation directories
    candidates = Array( _
        "C:\Program Files\glzr.io\Zebar\zebar.exe", _
        objShell.ExpandEnvironmentStrings("%LOCALAPPDATA%\Programs\glzr.io\Zebar\zebar.exe"), _
        "C:\Program Files (x86)\glzr.io\Zebar\zebar.exe" _
    )
    For Each c In candidates
        If objFSO.FileExists(c) Then
            ResolveZebar = c
            Exit Function
        End If
    Next

    ' 2. Check if zebar.exe is in PATH
    envPath = objShell.ExpandEnvironmentStrings("%PATH%")
    pathDirs = Split(envPath, ";")
    For Each d In pathDirs
        If Trim(d) <> "" Then
            testPath = Trim(d)
            If Right(testPath, 1) = "\" Then
                testPath = testPath & "zebar.exe"
            Else
                testPath = testPath & "\zebar.exe"
            End If
            If objFSO.FileExists(testPath) Then
                ResolveZebar = testPath
                Exit Function
            End If
        End If
    Next

    ' 3. Fallback
    ResolveZebar = "zebar"
End Function

zebarPath = ResolveZebar()

' 1. Terminate existing Zebar and any orphaned WebView2 instances holding locks
On Error Resume Next
objShell.Run "taskkill /IM zebar.exe /F", 0, True
objShell.Run "pwsh.exe -NoProfile -WindowStyle Hidden -Command ""Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'msedgewebview2.exe' -and $_.CommandLine -like '*com.glzr.zebar*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }""", 0, True
On Error GoTo 0

' 2. Wait for socket 6124 and EBWebView profile lock to clear
WScript.Sleep 800

' 3. Dispatch fresh Zebar instance via explorer.exe to guarantee interactive desktop integration and detach from script lifecycle
objShell.Run "explorer.exe """ & zebarPath & """", 1, False

' 4. Launch GPU telemetry daemon silently alongside Zebar
Dim gpuVbs
gpuVbs = objShell.ExpandEnvironmentStrings("%USERPROFILE%\.glzr\Launch-GPU.vbs")
If objFSO.FileExists(gpuVbs) Then
    objShell.Run "wscript.exe //B """ & gpuVbs & """", 0, False
End If
