@echo off
rem Builds the friend version of the game into "CHAINS DEEZNUTS TOGETHER - send to friends" on
rem your Desktop. Run it again after any change to the game and send friends the new .pck.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\make_friend_zip.ps1"
pause
