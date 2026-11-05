---
name: autohotkey-v2
description: Conventions and patterns for AutoHotkey v2 (AHK v2) development. Use when writing, debugging, or refactoring AHK v2 automation scripts, custom GUIs, window management, hotkeys, hotstrings, tray menus, or desktop productivity tools.
---

# AutoHotkey v2 (AHK v2) Development Guide

## When to use this skill
Trigger whenever developing, refactoring, or debugging AutoHotkey v2 (`.ahk`) automation scripts, custom desktop GUIs, hotkey macros, or system utilities on Windows.

---

## 1. Core Principles & Strict v2 Syntax

- **Strict v2 Syntax Only**: Never mix legacy v1 syntax (`%var%`, command syntax without parentheses, `IfEqual`, etc.). All functions require parentheses `Func(arg1, arg2)` and expressions.
- **Variable Declarations**: Always initialize variables explicitly. Functions have local scope by default; declare `global` only when strictly necessary.
- **String Handling & Interpolation**: Use double quotes for literal strings and string concatenation with spaces or format strings:
  ```ahk
  msg := Format("Active Window: {1} (PID: {2})", WinGetTitle("A"), WinGetPID("A"))
  ```
- **Error Handling**: Always wrap risky operations (file I/O, process management, COM calls) in `try / catch` blocks.

---

## 2. Robust Script Template (Headers & Safety)

Every standalone script must start with standard safety directives:

```ahk
#Requires AutoHotkey v2.0+
#SingleInstance Force
Persistent(true)
SetWorkingDir(A_ScriptDir)
SendMode("Input")

OnError(GlobalErrorHandler)

GlobalErrorHandler(thrown, mode) {
    logPath := A_AppData "\MyApp\error_log.txt"
    try DirCreate(A_AppData "\MyApp")
    try FileAppend(Format("[{1}] ERROR in {2} (Line {3}): {4}`n", 
        FormatTime(, "yyyy-MM-dd HH:mm:ss"), 
        thrown.File, 
        thrown.Line, 
        thrown.Message), logPath, "UTF-8")
    
    MsgBox("An unexpected error occurred:`n`n" . thrown.Message . "`n`nLogged to: " . logPath, "Application Error", "Iconx 16")
    return true
}
```

---

## 3. Standalone Binary Portability & Asset Embedding (`FileInstall`)

When distributing a compiled standalone `.exe`, asset files must be embedded inside the binary and extracted dynamically to `%APPDATA%`:

```ahk
class AppResources {
    static resourceDir := ""
    static imagePath   := ""
    static iconPath    := ""

    static Init() {
        appDataAssets := A_AppData "\MyApp\assets"
        try DirCreate(appDataAssets)

        this.imagePath := appDataAssets "\app_bg.png"
        this.iconPath  := appDataAssets "\app.ico"

        try {
            if !FileExist(this.imagePath)
                FileInstall("assets\app_bg.png", this.imagePath, 1)
        }
        try {
            if !FileExist(this.iconPath)
                FileInstall("assets\app.ico", this.iconPath, 1)
        }
    }
}
```

---

## 4. Modern GUI Construction & Flicker Prevention

```ahk
CreateAppWindow() {
    ; +0x02000000 = WS_CLIPCHILDREN (eliminates redraw flicker)
    mainGui := Gui("+Resize +MinSize400x300 +0x02000000", "Quick Launcher")
    mainGui.SetFont("s10", "Segoe UI")
    mainGui.BackColor := "0x1E1E1E"

    mainGui.SetFont("s14 bold cWhite", "Segoe UI")
    mainGui.AddText("w360", "Task Controller")

    mainGui.SetFont("s10 norm cBlack", "Segoe UI")
    searchInput := mainGui.AddEdit("w360 vSearchField", "")
    
    mainGui.SetFont("s10 bold cWhite", "Segoe UI")
    submitBtn := mainGui.AddButton("w120 Default", "Execute")
    submitBtn.OnEvent("Click", (*) => OnExecute(searchInput.Value))

    mainGui.OnEvent("Close", (*) => mainGui.Hide())
    mainGui.OnEvent("Escape", (*) => mainGui.Hide())

    mainGui.Show("w400 h320 Center")
    return mainGui
}
```

### Essential GUI Invariants
1. **Zero Text Redraw Flicker (`WS_CLIPCHILDREN`)**: Always include `+0x02000000` in the Gui constructor options.
2. **Prevent Control Coordinate Overlaps**: Never place two controls at the exact same Y position. Overlapping controls cause repaint churn.
3. **Visibility Ghosting Cleanup (`WinRedraw`)**: Call `WinRedraw("ahk_id " gui.Hwnd)` after toggling child control visibility.
4. **Defensive Input Parsing**: Always use safe integer parsing (`IsInteger(val) ? Integer(val) : defaultVal`).
5. **Handle Destruction Guarding**: Always check `if (this.childGui && IsObject(this.childGui))` before calling methods.

---

## 5. Headless Compilation via Ahk2Exe CLI

Automate compilation silently via PowerShell using the build script:
```powershell
pwsh -NoProfile -File scripts/build-ahk.ps1 -In "MyScript.ahk" -Out "MyScript.exe" -Icon "assets\app.ico"
```
See [scripts/build-ahk.ps1](scripts/build-ahk.ps1) for the production build automation script with base binary detection and size reporting.

---

## 6. Context-Sensitive Hotkeys & Window Management

Scope hotkeys strictly to target applications using `#HotIf`:

```ahk
#HotIf WinActive("ahk_exe Obsidian.exe")

; Ctrl + Shift + N -> Quick Task Note
^+n:: {
    vaultPath := "D:/dev/obsidian/hola"
    timestamp := FormatTime(, "yyyy-MM-dd_HH-mm")
    notePath := vaultPath . "\inbox\Task-" . timestamp . ".md"
    
    initialContent := "---\ntype: task-plan\ndate: " . FormatTime(, "yyyy-MM-dd") . "\ntags: [task]\nstage: #now\n---\n\n# Quick Task\n\n- [ ] "
    
    if !FileExist(notePath) {
        FileAppend(initialContent, notePath, "UTF-8")
        Run("obsidian://open?vault=hola&file=inbox/Task-" . timestamp)
    }
}

#HotIf ; Reset hotkey context
```

---

## 7. Automated Unit Testing Pattern for AHK v2

```ahk
class Assert {
    static passCount := 0
    static failCount := 0
    static logFile   := A_ScriptDir "\test_results.txt"

    static Equal(expected, actual, testName := "Test") {
        if (expected == actual) {
            this.passCount++
        } else {
            this.failCount++
            FileAppend(Format("[FAIL] {1}: Expected '{2}', got '{3}'`n", testName, expected, actual), this.logFile, "UTF-8")
        }
    }
}
```

---

## 8. Verification & Testing

Validate script execution and syntax:
1. Run syntax check without launching GUI:
   ```powershell
   pwsh -NoProfile -Command "Start-Process 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' -ArgumentList @('/validate', 'MyScript.ahk') -Wait"
   ```
2. Run build verification:
   ```powershell
   pwsh -NoProfile -File scripts/build-ahk.ps1 -In "MyScript.ahk"
   ```

---

## 9. Things to Avoid

- Never hardcode unescaped paths or relative asset paths without AppData fallback in compiled mode.
- Avoid polling loops with `Sleep` inside the main thread; use `SetTimer` for non-blocking asynchronous intervals.
- Never write to registry on every launch without checking whether values have changed.
- Never call methods on destroyed GUI handles without `IsObject()` checks.
- Never place overlapping child controls on the same coordinate plane.
