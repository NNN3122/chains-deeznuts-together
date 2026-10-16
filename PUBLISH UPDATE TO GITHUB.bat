@echo off
rem Builds the game and publishes it as the next release on GitHub. Your friends' download link
rem (shown at the end) always serves the newest version, so you only ever send it once.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\publish_release.ps1"
pause
