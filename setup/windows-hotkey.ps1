# windows-hotkey.ps1
# Registers Win+Insert as a global hotkey to open the text editor.
# Run once; use -AddToStartup to persist across logins.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File setup\windows-hotkey.ps1
#   powershell -ExecutionPolicy Bypass -File setup\windows-hotkey.ps1 -AddToStartup

param([switch]$AddToStartup)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RunBat = Join-Path $ProjectRoot "run.bat"

if (-not (Test-Path $RunBat)) {
    Write-Error "run.bat not found at: $RunBat"
    exit 1
}

# Inline C# for a hidden WinForms window that registers the hotkey
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class HotkeyWatcher : Form {
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    const int    WM_HOTKEY  = 0x0312;
    const uint   MOD_WIN    = 0x0008;
    const uint   VK_INSERT  = 0x2D;

    string runBat;

    public HotkeyWatcher(string bat) {
        runBat = bat;
        ShowInTaskbar   = false;
        WindowState     = FormWindowState.Minimized;
        Opacity         = 0;
        Load += (s, e) => RegisterHotKey(Handle, 1, MOD_WIN, VK_INSERT);
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY && m.WParam.ToInt32() == 1)
            Process.Start("cmd.exe", "/c \"" + runBat + "\"");
        base.WndProc(ref m);
    }

    protected override void Dispose(bool disposing) {
        UnregisterHotKey(Handle, 1);
        base.Dispose(disposing);
    }
}
"@ -ReferencedAssemblies System.Windows.Forms

if ($AddToStartup) {
    $StartupDir = [Environment]::GetFolderPath("Startup")
    $VbsPath    = Join-Path $StartupDir "texteditor-hotkey.vbs"
    $PsPath     = $PSCommandPath
    @"
Set sh = CreateObject("WScript.Shell")
sh.Run "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & "$PsPath" & """", 0, False
"@ | Set-Content -Path $VbsPath -Encoding ASCII
    Write-Host "Startup entry created: $VbsPath"
    Write-Host "Win+Insert will be available after next login."
}

Write-Host "Hotkey watcher running (Win+Insert -> open editor). Ctrl+C to stop."
[System.Windows.Forms.Application]::Run((New-Object HotkeyWatcher($RunBat)))
