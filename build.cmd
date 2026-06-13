@echo off
REM Double-click this to build build\NiceSwarm.exe (a distributable Windows release).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
echo.
pause
