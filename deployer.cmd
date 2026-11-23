@echo off
rem Exporte l'APK, l'installe sur le telephone et lance le jeu.
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\telephone.ps1" deploy %*
if "%~1"=="" pause

