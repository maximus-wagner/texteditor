@echo off
cd /d "%~dp0"

:: ---- Find SBCL ----
set "SBCL="
where sbcl >nul 2>&1
if not errorlevel 1 ( set "SBCL=sbcl" & goto :found_sbcl )

for %%D in (
    "C:\Program Files\Steel Bank Common Lisp"
    "C:\Program Files (x86)\Steel Bank Common Lisp"
    "C:\sbcl"
    "%USERPROFILE%\scoop\apps\sbcl\current"
    "%LOCALAPPDATA%\scoop\apps\sbcl\current"
    "%USERPROFILE%\AppData\Local\Programs\sbcl"
    "D:\sbcl"
    "C:\msys64\mingw64\bin"
    "C:\msys2\mingw64\bin"
) do (
    if exist "%%~D\sbcl.exe" (
        set "SBCL=%%~D\sbcl.exe"
        goto :found_sbcl
    )
)

echo SBCL not found.
echo Install from: https://www.sbcl.org/platform-table.html
pause
exit /b 1

:found_sbcl

:: ---- Copy libffi (required by CFFI) if not already present ----
if not exist "libffi-8.dll" (
    for %%D in (
        "C:\msys64\ucrt64\bin"
        "C:\msys64\mingw64\bin"
        "C:\msys2\ucrt64\bin"
        "C:\msys2\mingw64\bin"
        "%USERPROFILE%\msys64\ucrt64\bin"
        "%USERPROFILE%\msys2\ucrt64\bin"
    ) do (
        if exist "%%~D\libffi-8.dll" (
            echo Copying libffi-8.dll from %%~D ...
            copy /Y "%%~D\libffi-8.dll" . >nul
            goto :run
        )
    )
    echo.
    echo WARNING: libffi-8.dll not found.
    echo CFFI will likely fail to load. To fix this:
    echo   1. Install MSYS2 from https://www.msys2.org/
    echo   2. Run: pacman -S mingw-w64-ucrt-x86_64-libffi
    echo   3. Copy C:\msys64\ucrt64\bin\libffi-8.dll here
    echo.
    pause
)

:: ---- Ensure SDL2_ttf runtime present (copy from x64 package if available) ----
if not exist "SDL3_ttf.dll" (
    if exist "SDL3_ttf-3.2.2-win32-x64\SDL3_ttf.dll" (
        echo Copying SDL3_ttf.dll from SDL3_ttf-3.2.2-win32-x64...
        copy /Y "SDL3_ttf-3.2.2-win32-x64\SDL3_ttf.dll" . >nul
    ) else (
        echo Note: SDL3_ttf.dll not found in SDL3_ttf-3.2.2-win32-x64; ensure SDL3_ttf is on PATH
    )
)

:run
echo Starting text editor...
"%SBCL%" --dynamic-space-size 512 --non-interactive ^
    --load src/main.lisp ^
    --eval "(main:main)"
if errorlevel 1 (
    echo.
    echo Editor exited with an error.
    pause
)
