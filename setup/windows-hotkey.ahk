; texteditor-hotkey.ahk  (AutoHotkey v2)
; Win+Insert opens the text editor from anywhere.
; Requires AutoHotkey: https://www.autohotkey.com/
;
; Usage:
;   1. Install AutoHotkey
;   2. Double-click this file to activate the hotkey
;   3. To make it permanent, copy this file to your Startup folder:
;      %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\

#Requires AutoHotkey v2.0
#SingleInstance Force

EditorDir := A_ScriptDir "\.."

; Win+Insert
#Insert:: {
    Run 'cmd.exe /c "' EditorDir '\run.bat"',, "Hide"
}
