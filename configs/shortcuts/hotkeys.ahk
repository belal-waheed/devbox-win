; ==============================================================================
; devbox-win :: AutoHotkey v2 Keybindings
; Path: dotfiles/ahk/hotkeys.ahk
; Description: Clean, productive window management & developer launcher hotkeys.
; Standard: Zero emojis. AutoHotkey v2.0+ required.
; ==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

TraySetIcon "shell32.dll", 44
A_IconTip := "devbox-win Hotkeys (AHK v2)"

; ------------------------------------------------------------------------------
; Quick Launchers
; ------------------------------------------------------------------------------

; Win + Enter: Open Windows Terminal
#Enter::
{
    Run "wt.exe"
}

; Win + C: Open VS Code
#c::
{
    Run "code"
}

; Win + B: Open Default Browser
#b::
{
    Run "https://github.com"
}

; Win + Shift + E: Open Explorer at User Home
#+e::
{
    Run "explorer.exe " . EnvGet("USERPROFILE")
}

; ------------------------------------------------------------------------------
; Window Utilities
; ------------------------------------------------------------------------------

; Win + Q: Close active window
#q::
{
    activeHwnd := WinActive("A")
    if (activeHwnd) {
        WinClose "ahk_id " . activeHwnd
    }
}

; Win + Shift + C: Center active window
#+c::
{
    activeHwnd := WinActive("A")
    if (!activeHwnd) {
        return
    }

    WinGetPos &x, &y, &w, &h, "ahk_id " . activeHwnd
    screenWidth := A_ScreenWidth
    screenHeight := A_ScreenHeight
    newX := (screenWidth - w) / 2
    newY := (screenHeight - h) / 2
    WinMove newX, newY, w, h, "ahk_id " . activeHwnd
}

; Ctrl + Alt + R: Reload hotkey script
^!r::
{
    ToolTip "[INFO] Reloading devbox-win hotkeys..."
    SetTimer () => ToolTip(), -1500
    Reload
}
