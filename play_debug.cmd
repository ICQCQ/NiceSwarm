@echo off
REM Double-click this to run the game in debug mode (verbose logging, debugger attached).
cd /d "%~dp0"
godot --path . --debug --verbose
echo.
pause
