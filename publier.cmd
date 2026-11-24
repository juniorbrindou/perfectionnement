@echo off
rem Publie une version sur GitHub : publier 0.6.1 (voir docs\RELEASES.md).
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\publier.ps1" %*
pause
