@echo off
cd /d "%~dp0"
set PATH=C:\msys64\ucrt64\bin;C:\msys64\usr\bin;%PATH%
gcc.exe -shared -o libsdl-struct-accessors.so src/struct-accessors.c -IC:\Users\maxim\Documents\Projects\texteditor\SDL3-3.4.2\x86_64-w64-mingw32\include
if %ERRORLEVEL% EQU 0 (echo Build OK) else (echo Build FAILED)
