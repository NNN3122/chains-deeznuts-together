@echo off
rem Two game windows side by side on this PC: left hosts, right joins. For testing co-op alone.
set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
start "" "%GODOT%" --path "%~dp0." --resolution 960x540 --position 0,60 -- --host --name=Player1
timeout /t 2 /nobreak >nul
start "" "%GODOT%" --path "%~dp0." --resolution 960x540 --position 970,60 -- --join=127.0.0.1 --name=Player2
