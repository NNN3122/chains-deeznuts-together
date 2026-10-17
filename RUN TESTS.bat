@echo off
rem Headless smoke tests: solo, then a host and a client playing through both levels by script.
set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
cd /d "%~dp0"
echo === SOLO
"%GODOT%" --headless --path . --max-fps 60 -- --solo --smoke
echo === THE LOADING LOT (horde, Launcher, slide)
"%GODOT%" --headless --path . --max-fps 60 -- --arena --solo --smoke
echo === THE LOADING LOT, HOST + CLIENT (port 7792; the client joins without --arena and is handed the host's world)
start "" /b "%GODOT%" --headless --path . --max-fps 60 -- --join=127.0.0.1 --port=7792 --smoke-client
"%GODOT%" --headless --path . --max-fps 60 -- --arena --host --port=7792 --smoke --smoke-players=2
echo === HOST + CLIENT (port 7791)
start "" /b "%GODOT%" --headless --path . --max-fps 60 -- --join=127.0.0.1 --port=7791 --smoke-client
"%GODOT%" --headless --path . --max-fps 60 -- --host --port=7791 --smoke --smoke-players=2
pause
