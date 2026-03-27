@echo off
:: ViMDav - Register Win+Insert global hotkey (Windows)
:: Requires AutoHotkey v1 or v2: https://www.autohotkey.com

set "EDITOR_DIR=%~dp0.."
set "AHK_SCRIPT=%APPDATA%\ViMDav-hotkey.ahk"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

:: Check for AutoHotkey
where autohotkey >nul 2>&1
if errorlevel 1 (
    echo AutoHotkey is required. Download from: https://www.autohotkey.com
    echo After installing AutoHotkey, run this script again.
    pause & exit /b 1
)

:: Write the AHK script
(
echo #Persistent
echo #NoEnv
echo #SingleInstance Force
echo ; Win+Insert = open ViMDav
echo #Insert::
echo   Run, cmd /c "start /min """" "%EDITOR_DIR%\run.bat"""
echo return
) > "%AHK_SCRIPT%"

:: Copy to startup so it runs at login
copy /Y "%AHK_SCRIPT%" "%STARTUP%\ViMDav-hotkey.ahk" >nul

:: Start now
start "" autohotkey "%AHK_SCRIPT%"

echo ViMDav hotkey registered: Win+Insert opens ViMDav.
echo The hotkey will automatically start at Windows login.
pause
