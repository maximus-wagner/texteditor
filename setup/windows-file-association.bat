@echo off
:: ViMDav - Register as default text editor for common file types (Windows)
set "RUN=%~dp0..\run.bat"

:: Register ViMDav as an application in registry
reg add "HKCU\Software\Classes\ViMDav" /ve /d "ViMDav Text Editor" /f >nul
reg add "HKCU\Software\Classes\ViMDav\shell\open\command" /ve /d "cmd /c \"%RUN%\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\ViMDav\DefaultIcon" /ve /d "notepad.exe,0" /f >nul

:: Associate file extensions
for %%E in (.txt .lisp .lsp .md .log .cfg .ini .sh .py .js .ts .json .xml .yaml .yml .toml .html .css .c .cpp .h .rs .go) do (
  reg add "HKCU\Software\Classes\%%E" /ve /d "ViMDav" /f >nul
)

:: Notify Windows of the change
ie4uinit.exe -show 2>nul || rundll32 user32.dll,UpdatePerUserSystemParameters

echo.
echo ViMDav registered as default editor for:
echo   .txt .lisp .md .log .cfg .ini .sh .py .js .ts .json .xml .yaml .yml
echo   .toml .html .css .c .cpp .h .rs .go
echo.
echo To undo: run this from PowerShell:
echo   Get-Item "HKCU:\Software\Classes\ViMDav" ^| Remove-Item -Recurse
echo.
pause
