@echo off
rem Lance les tests des regles et du contenu.
"%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\godot_console.exe" --headless --path "%~dp0." --script res://tests/run_tests.gd

