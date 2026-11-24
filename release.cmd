@echo off
rem Construit l'APK release dans build\perfectionnement-release.apk.
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\release.ps1" %*
pause
