@echo off
rem Ouvre le projet dans l'editeur Godot.
start "" "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\godot.exe" -e --path "%~dp0."

