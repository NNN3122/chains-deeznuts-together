@echo off
rem The Loading Lot: the Level 3 horde test block. Opens the title screen with THE LOADING LOT selected.
set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
cd /d "%~dp0"
start "" "%GODOT%" --path . -- --arena
